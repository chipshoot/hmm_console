# Tag Cloud Sync (C) — Design

**Date:** 2026-06-09
**Repo:** `hmm_console` (Flutter client)
**Status:** Approved design, ready for implementation planning

## Overview

This is deliverable **C** from the note subsystem design
(`2026-06-06-note-subsystem-foundation-design.md`). Tags have a local Drift
repository (`LocalTagRepository`) and tables (`Tags`, `NoteTagRefs`), but no
sync metadata, so they never reach the cloud. This spec makes tags sync in
**cloudStorage** (OneDrive) mode.

### Scope decisions (from brainstorming)

- **Data-layer only.** Tags currently have no UI (nothing creates, assigns, or
  displays them). This builds the sync foundation; tag UI lands later (with B or
  a dedicated tag feature). Verified by repo/sync tests, not on-screen.
- **cloudStorage only.** The `cloudApi` `ApiTagRepository`
  (`repository_providers.dart` throws `UnimplementedError`) is **deferred**: its
  sibling `cloudApi` repos — note, author, catalog — all still throw
  `UnimplementedError`, so a tag repo would have no API notes to attach to. It
  ships as a set when the API note repo is built. `local` mode = no sync.
- **Identity = tag name.** Tags are keyed across devices by normalized
  (lowercased, trimmed) name. This matches the backend, which has no tag UUID —
  `ApiTag` is `{Id (int), Name, Description}` with a unique-name rule and
  `GetTagByName`. Name is the lingua franca across tiers; a UUID would be
  invisible to the server and buys only rename-tracking within cloudStorage (a
  rename becomes delete-old + create-new, acceptable for simple tags).
- **Associations embed in note bodies** (not a standalone associations file).
  See "Why membership rides with notes" below.

## Why membership rides with notes

Tag *definitions* are a small bounded set; tag *membership* (note↔tag
associations) is O(notes × tags-per-note) and a single heavily-used tag (e.g.
"important" on thousands of notes) makes it large. Any standalone association
object — a `NoteTag.json` file or a manifest section — must be a **complete
index** of every association to detect deletions, and that whole index is
pulled+pushed on every sync. That is unbounded growth.

The only way to avoid a global association index is to let membership ride with
the thing already synced **incrementally** — the note. So each note's synced
body carries its own tag-name list, and only changed notes transfer. A star tag
on 10,000 notes is one short string in each of those note bodies; nothing bloats.

**This is only the OneDrive wire format — not a model change.** Three
representations exist; embedding touches only the middle one:

| Representation | Used for | Changed? |
|---|---|---|
| Local Drift `Tags` + `NoteTagRefs` join | All queries (search/filter, B) | No |
| OneDrive `tags.json` + note-body `tags:[…]` | Sync transport | this design |
| Backend `NoteTagAssociation` + API | `cloudApi` tier | No |

Tag-search remains a local relational query (`notes JOIN noteTagRefs WHERE
tagId = …`); the app never parses note bodies to find tags. On pull, a note
body's `tags` array is expanded back into `NoteTagRefs` rows.

## Schema changes (Drift v6)

Bump `schemaVersion` 5 → 6; add an `if (from < 6)` step using the same
`m.addColumn` pattern as the existing note migrations. Do **not** rebuild tables.

- **`Tags`**: add
  - `lastModified` — `DateTimeColumn`, `withDefault(currentDateAndTime)`.
  - `deletedAt` — `DateTimeColumn().nullable()` (sync tombstone; distinct from
    the existing `isActivated` user-facing flag).
  - `name` stays unique (the cross-device key); `description`, `isActivated`
    sync as last-writer-wins fields.
- **`NoteTagRefs`**: **unchanged.** No sync metadata — membership is
  reconstructed locally from note bodies on pull. Remains the relational join
  that all queries run against.

## Wire format

### `tags.json` (tag definitions only)

A sibling to `manifest.json` in the cloud namespace:

```json
{
  "version": 1,
  "device_id": "<uuid of writing device>",
  "generated_at": "2026-06-09T10:00:00Z",
  "tags": [
    {
      "name": "work",
      "description": "...",
      "is_activated": true,
      "last_modified": "2026-06-08T11:00:00Z",
      "deleted": false
    }
  ]
}
```

Tags key on normalized name. Bounded small set → per-record merge is cheap; the
full set is merged every sync (no cursor needed).

### Note body — `tags` field

The note body (already transported by note sync) gains:

```json
{ "...existing note fields...": "...", "tags": ["work", "important"] }
```

The complete current list of the note's tag names. Absence of a previously
present name = the tag was removed from that note.

## Components

Boundaries: the orchestrator coordinates; `TagSyncService` holds merge logic; the
provider does transport; the repository does local persistence. Each is testable
in isolation.

### `CloudSyncProvider` (`lib/core/data/sync/cloud_sync_provider.dart`)

Add two methods with default no-ops, mirroring `pullSettings`/`pushSettings`:

```dart
Future<Map<String, dynamic>?> pullTags() async => null;
Future<void> pushTags(Map<String, dynamic> doc) async {}
```

- **`OnedriveSyncProvider`**: implement both via a `tags.json` graph call. The
  graph client (`onedrive_graph_client.dart`) gets `getTags()`/`putTags(body)`,
  mirroring its existing `getSettings()`/`putSettings(body)`.
- **`ApiSyncProvider`**: leave the no-op default (cloudApi deferred).

### `TagSyncService` (new, `lib/core/data/sync/tag_sync_service.dart`)

The testable core for the **definition** leg (one clear responsibility):

- **`mergeDefinitions(localTags, remoteDoc)`** → applies remote-newer
  definitions to the local store (via `LocalTagRepository`), returns the merged
  document to push, plus a list of any records skipped/logged.

Note membership is *not* handled here — it rides with the note sync and is
applied through `LocalTagRepository` directly (see the orchestrator hooks and
`tagNamesForNote` / `setTagsForNote` below), keeping set-replace ownership in the
repository layer.

### `SyncOrchestrator` (`lib/core/data/sync/sync_orchestrator.dart`)

- A `_syncTags(provider, errors)` step called from `syncNow()` after
  `_syncSettings`, syncing tag **definitions** (pull `tags.json` → merge → push
  merged doc). Non-fatal: a failure logs a `SyncError` and lets notes sync.
- Two hooks in the existing note paths, calling `LocalTagRepository` directly:
  - When building a note blob (`_collectChangedNotes`): embed `tags` =
    `repo.tagNamesForNote(note.id)`.
  - When applying a pulled note (`_maybePullNote`): after the note row is
    written, call `repo.setTagsForNote(note.id, body['tags'])` (set-replace).
- Ordering per pass: `_syncTags` (definitions) runs **before** the note pull, so
  most names are defined before note bodies arrive; auto-create covers stragglers.

### `LocalTagRepository` (`lib/core/data/local/local_tag_repository.dart`)

Add sync-oriented methods (existing CRUD unchanged):

- `getTagsWithMeta()` — all tags including `lastModified`/`deletedAt`.
- `upsertTagByName(name, {description, isActivated, lastModified})` — create or
  update by normalized name.
- `tombstoneTagByName(name, deletedAt)` — set the tombstone.
- `tagNamesForNote(noteId)` — names of the note's active tags.
- `setTagsForNote(noteId, names)` — set-replace the note's refs to `names`,
  creating missing tags by name.

## Merge & ordering rules

- **Tag definition** (union of local + remote by normalized name): the record
  with the newer `last_modified` wins for all fields (`description`,
  `is_activated`, `deleted`).
  - Remote newer → upsert locally; if `deleted`, set the tombstone.
  - Local newer or local-only → include in the pushed document.
  - The merged document (every record at its winning version) is pushed as a
    full overwrite, consistent with `pushManifest`.
- **Note membership**: a pulled note's `tags` array is the complete truth for
  that note → set-replace its refs. A dropped tag is simply absent (no
  tombstone). A referenced name with no local definition yet → auto-create a
  minimal tag (name only); its full definition reconciles via `tags.json`.

## Data flow (one sync pass)

`syncNow()`:
1. `_syncSettings` (unchanged).
2. **`_syncTags`**: `remote = provider.pullTags()` (null → cloud empty) →
   `TagSyncService.mergeDefinitions(local, remote)` applies remote-wins
   definitions and returns the merged doc → `provider.pushTags(merged)`.
3. Note pull loop (unchanged) — each applied note now also calls
   `applyNoteTags(note.id, body['tags'])`.
4. Note push (unchanged) — each pushed note blob now also carries its `tags`.
5. Any throw in the tag leg → non-fatal `SyncError(recordType:'tags', …)`;
   notes still sync.

Full-set definition merge every pass — tags are small, so it is cheap and avoids
cursor-edge bugs.

## Error handling

- Malformed remote `tags.json` → logged as a non-fatal `SyncError` and the tag
  leg is skipped (mirrors the defensive decode in `_syncSettings`).
- A note body with a missing or malformed `tags` value → ignored for that note;
  the note still applies (membership simply isn't updated that pass).
- A transport failure (pull/push tags) → degrades to "tags didn't sync this
  pass"; the note legs are unaffected.

## Testing

Follows the repo's in-memory-Drift + fake-provider patterns.

- **`TagSyncService` unit tests** (definition leg):
  - Definition merge: remote-newer wins; local-newer pushed; tombstone
    propagation (delete on one device removes on the other).
  - Same-name dedup across two devices (two devices create "work" → one tag).
  - Malformed remote document ignored (no throw).
- **Drift v5 → v6 migration test**: upgrade an at-v5 database; assert the new
  `Tags` columns exist and pre-existing rows are intact.
- **`LocalTagRepository` tests** for the new methods (`getTagsWithMeta`,
  `upsertTagByName`, `tombstoneTagByName`, `tagNamesForNote`, `setTagsForNote`),
  including `setTagsForNote` set-replace (adds new refs, removes absent ones) and
  auto-create of a referenced tag name with no local definition.
- **Note round-trip test**: pushing a note embeds its `tags`; applying that body
  rebuilds the note's `NoteTagRefs`.
- **Orchestrator test**: a tag-leg failure is non-fatal (notes still sync).
- **`OnedriveSyncProvider` / graph test**: `tags.json` round-trip against the
  existing fake graph client.

## Non-goals (deferred)

- Tag UI (create/assign/display/filter-by-tag) — a later feature (with B).
- `cloudApi` `ApiTagRepository` — ships with the API note/author/catalog repos.
- Rename-tracking across devices — a rename is delete-old + create-new by name.
- Tag UUIDs — name is the cross-device key.

## Open items for the implementation plan

- Confirm the exact `onedrive_graph_client` method shape for a sibling JSON file
  (mirror `getSettings`/`putSettings` precisely, including the namespace path).
- Confirm the note-blob assembly point in `_collectChangedNotes` and the apply
  point in `_maybePullNote` for the two `tags` hooks (names verified to exist;
  the plan pins exact insertion lines).
