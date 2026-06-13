# Cross-Subsystem Note Surfacing (B) — Design

**Date:** 2026-06-13
**Repo:** `hmm_console` (Flutter client)
**Status:** Approved design, ready for implementation planning

## Overview

This is deliverable **B** from the note subsystem design
(`2026-06-06-note-subsystem-foundation-design.md`): free-form notes become
discoverable by domain subsystems. The original example — "a car-photo note
appears in the automobile manager's list" — generalized during brainstorming
into a **generic, multi-level note-attachment capability** that every current
and future subsystem (Automobile now; Health, Insurance, Housekeeping, Books…
later) gets for free.

A note can be attached at two levels, both surfaced while the note also stays in
the general notes list:

- **Entity-level:** attach a note to a *specific* entity (this car). Surfaced on
  that entity's screen.
- **Subsystem-level:** attach a note to a *subsystem* (e.g. Health), with no
  specific entity (your "medicine-label photo → Health" example). Surfaced on
  that subsystem's notes screen.

## Key decisions (from brainstorming)

- **One universal link: `parentNoteId`.** A General note attaches to a *parent
  note*, which is either a specific entity note (a car) or a **subsystem anchor
  note** (below). No tags, no catalog swap for association.
- **The note keeps the General catalog.** So it stays in the general notes list,
  while being a *child* of the parent makes it appear in that parent's notes
  list — it shows in **both lists**. Subsystem membership is therefore additive
  (via the parent link), not an exclusive reclassification.
- **Subsystems are represented by seeded "anchor notes."** Each subsystem = one
  note with catalog `Hmm.System.Subsystem` and `subject` = the subsystem display
  name. Attaching to a subsystem = `parentNoteId → its anchor note`. This unifies
  both attachment levels under `parentNoteId`.
- **Attachment is initiated from the entity's screen** (entity-level) and from
  the **note editor** (subsystem-level). No cross-subsystem *entity* picker (that
  would need a per-subsystem entity registry) — only the small, queryable set of
  subsystem anchors is listed in the editor.
- **`parentNoteId` becomes re-linkable** (a new repo method) so existing notes
  can be attached / moved / detached, not only set at create.
- **Scope:** Automobile is the reference wiring; other subsystems reuse the same
  generic unit by seeding an anchor (+ dropping the widget when their screen
  exists). `cloudApi` unaffected (deferred); this is cloudStorage + local.

## Architecture & data model

### `parentNoteId` is the single association
- `HmmNote.parentNoteId` already exists and the gas-log hierarchy already uses it
  (a gas-log note's `parentNoteId` = its automobile note). `getNotes()` already
  filters by `parentNoteId`, and the OneDrive sync already carries
  `parentNoteUuid` (resolved in pull pass 2).
- A General note's `parentNoteId` points at the parent it's attached to (an
  entity note **or** a subsystem anchor note). The note's own catalog stays
  `General`.

### Subsystem anchor notes
- A dedicated catalog `Hmm.System.Subsystem` marks anchor notes.
- Each subsystem has exactly one anchor note: `subject` = display name (e.g.
  "Automobile"), catalog = the anchor catalog.
- **Deterministic uuid.** The anchor note's `uuid` is derived deterministically
  from the subsystem key (a fixed-namespace v5-style derivation), so every
  device generates the *same* uuid for a given subsystem. This makes the anchor
  a single shared record across devices: sync (which keys notes by uuid)
  dedups it automatically, and child notes referencing the anchor's uuid resolve
  to one anchor everywhere. Seeding is idempotent by this uuid.
- The set of subsystems = the set of anchor notes (`getNotes(catalogId:
  anchorCatalogId)`).
- **Anchors are hidden from the general notes list** (the list excludes the
  `Hmm.System.Subsystem` catalog) — they are infrastructure, not user notes.

### Two attachment levels, one mechanism
| Level | `parentNoteId` points at | Surfaced on |
|-------|--------------------------|-------------|
| Entity-level | a specific entity note (a car) | that entity's Notes screen |
| Subsystem-level | a subsystem anchor note | that subsystem's Notes screen |

A note has **one** parent → one attachment context. Multi-subsystem membership
is out of scope (would be tags, deferred).

### Re-link
`parentNoteId` was previously set only at create (`HmmNoteUpdate` excludes it).
A new `setParentNote(id, parentNoteId)` mutates it (and clears it on detach),
bumping `lastModifiedDate` + `version`. Sync needs no wire change: the note body
already carries `parentNoteUuid`, the re-link bumps `lastModifiedDate` so the
note is collected for push, and pull pass 2 re-resolves the (possibly new or
null) parent.

## Components & files

### Data layer
- **`LocalHmmNoteRepository.setParentNote(int id, int? parentNoteId)`** (added to
  `IHmmNoteRepository`): mutate `parentNoteId`, bump `lastModifiedDate` +
  `version`. `null` = detach.
- **`LocalHmmNoteRepository.getUnattachedGeneralNotes()`**: General catalog
  **and** `parentNoteId IS NULL` (a small new query; `getNotes` filters parent
  only when non-null). Powers the "attach existing" picker.
- **`lib/features/notes/data/subsystem_anchor.dart`**:
  - `const String kSubsystemAnchorCatalogName = 'Hmm.System.Subsystem';`
  - `String subsystemAnchorUuid(String key)` — deterministic uuid from a fixed
    namespace + subsystem key.
  - `Future<HmmNote> ensureSubsystemAnchor(Ref ref, {required String key,
    required String displayName})` — ensure the anchor catalog exists, then
    upsert the anchor note by its deterministic uuid (idempotent). Seeds the
    **Automobile** anchor (`key: 'automobile'`, `displayName: 'Automobile'`).
  - `final subsystemAnchorsProvider = FutureProvider<List<HmmNote>>` — all anchor
    notes.

### Surfacing (generic, reusable)
- **`lib/features/notes/states/attached_notes_state.dart`**:
  `attachedNotesProvider = FutureProvider.family<List<HmmNote>, int>((ref,
  parentId) async => getNotes(parentNoteId: parentId, catalogId: <General>))`.
- **`lib/features/notes/presentation/widgets/attached_notes_section.dart`** —
  `AttachedNotesSection(int parentId, String title)` `ConsumerWidget`: a header +
  the list (each row taps to `/notes/:id`) + two actions:
  - **Add note** → open the editor with `parentId` preset → `createNote(...,
    parentNoteId: parentId)`.
  - **Attach existing** → a picker of `getUnattachedGeneralNotes()` →
    `setParentNote(noteId, parentId)`.
  Reused by both the entity and subsystem screens.

### UX surfaces
- **Per-vehicle Notes screen** `lib/features/automobile_records/presentation/
  screens/vehicle_notes_screen.dart` — hosts `AttachedNotesSection(vehicleNoteId,
  'Notes')`. Route `/automobiles/manage/:id/notes`, mirroring the existing
  per-vehicle insurance/services screens; reached from the same per-vehicle entry
  point.
- **Generic subsystem Notes screen** `lib/features/notes/presentation/screens/
  subsystem_notes_screen.dart` — `SubsystemNotesScreen(int anchorId, String
  anchorName)` hosts `AttachedNotesSection(anchorId, anchorName)`.
- **Subsystems list** `lib/features/notes/presentation/screens/
  subsystems_screen.dart` — lists `subsystemAnchorsProvider` → tap → the
  subsystem Notes screen. Reached from a lightweight entry on the Notes list app
  bar.
- **Editor "Attach to" picker** — in `NoteEditorScreen`, a control showing
  "None" + each subsystem anchor (by `subject`), reflecting the note's current
  parent. If the current parent is a specific entity (a non-anchor note), it is
  shown as the selected item (so editing the note doesn't clobber the entity
  link). On save: a new note → `createNote(parentNoteId: chosen)`; an existing
  note whose parent changed → `setParentNote(id, chosen)`.

### Modified
- **`notesListState`**: exclude the `Hmm.System.Subsystem` catalog from the
  general list (resolve the anchor catalog id once; drop those notes).
- **Routing**: add `/automobiles/manage/:id/notes`, a subsystems route, and a
  subsystem-notes route. Editor route accepts an optional preset parent.

## Data flow

- **Create attached (entity):** vehicle Notes → "Add note" → editor (parent =
  vehicle) → `createNote(parentNoteId: vehicleId)`.
- **Create attached (subsystem):** editor → "Attach to" = a subsystem → on save
  `createNote(parentNoteId: anchorId)`. Note is General (general list) and a
  child of the anchor (subsystem Notes screen) — both lists.
- **Attach existing:** entity/subsystem section → "Attach existing" → pick an
  unattached General note → `setParentNote(noteId, parentId)`.
- **Detach:** note detail ⋯ menu / section → `setParentNote(noteId, null)`.
- **Surfacing:** `AttachedNotesSection(parentId)` watches
  `attachedNotesProvider(parentId)`; attach/detach/create invalidate it and
  `notesListStateProvider`.
- **Sync:** re-link bumps `lastModifiedDate` → the note is pushed carrying its
  new `parentNoteUuid` → pull pass 2 re-resolves it. Anchor notes sync as normal
  notes; their deterministic uuid keeps them a single shared record across
  devices.

## Error handling
- Attach/detach/create failures surface as an inline snackbar; each operation is
  atomic (a failed re-link leaves the note where it was).
- `AttachedNotesSection` surfaces load failures via `AsyncValue` error state.
- Anchor seeding is idempotent (deterministic uuid); a re-link targeting a
  missing note is a guarded no-op.
- An unresolved `parentNoteUuid` on pull is already tolerated by the existing
  sync (the parent simply isn't linked until it arrives).

## Testing

In-memory Drift + the established fake/provider patterns.

- **Repo:** `setParentNote` sets + clears `parentNoteId` and bumps
  `lastModifiedDate`; `getUnattachedGeneralNotes` returns only General +
  null-parent notes.
- **Anchors:** `subsystemAnchorUuid(key)` is deterministic (same input → same
  uuid); `ensureSubsystemAnchor` is idempotent (repeated calls → one anchor,
  same uuid); `subsystemAnchorsProvider` lists anchors.
- **Surfacing:** a note created with `parentNoteId = anchor` appears in
  `attachedNotesProvider(anchor)` **and** the general list; `setParentNote(null)`
  removes it from `attachedNotesProvider`.
- **Notes list:** anchor-catalog notes are excluded from the general list.
- **Widgets:** `AttachedNotesSection` (lists attached notes; Add / Attach-existing
  / detach actions); editor "Attach to" picker (create-with-parent + re-link;
  shows an entity parent read-only); `SubsystemNotesScreen` renders an anchor's
  notes; `SubsystemsScreen` lists anchors.
- **Sync:** a re-link bumps `lastModifiedDate` so the note is collected for push
  (carrying the new `parentNoteUuid`).

## Boundaries / non-goals (explicit, deferred)

- **One parent per note** → one attachment context (a subsystem *or* an entity),
  not multiple subsystems. Multi-membership would use tags; deferred.
- **"Attach existing" lists only *unattached* notes** (`parentNoteId IS NULL`).
  To move an already-attached note to a different parent, detach it first (then
  attach). A direct "move" affordance is deferred.
- The **subsystem Notes screen shows notes attached to the anchor itself**, not
  an aggregate of every entity's notes within the subsystem. Aggregation is a
  later enhancement.
- Only the **Automobile** anchor is seeded now (reference); future subsystems
  seed their own anchor when built.
- **No editor-side cross-subsystem *entity* picker** (attaching to a specific car
  from the editor) — editor attach is subsystem-level; entity attach is from the
  entity screen.
- `cloudApi` is unaffected (its note sync is still deferred); this is
  cloudStorage + local only.

## Open items for the implementation plan

- Confirm the deterministic-uuid derivation utility available in the repo
  (`lib/core/data/util/uuid.dart` has `generateUuid`; the plan pins whether to
  add a `deterministicUuid(namespace, key)` helper or hash-derive a stable
  string).
- Confirm the exact per-vehicle entry point / navigation that lists the
  insurance/services screens, so the Notes screen attaches to the same hub and
  receives the vehicle's note id.
- Confirm the editor's current-parent display when the parent is an entity
  (resolve the parent note's catalog to label it, e.g. "Attached to: <subject>").
