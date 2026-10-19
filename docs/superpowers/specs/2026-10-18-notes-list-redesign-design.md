# Notes List Redesign — Design Spec

**Date:** 2026-10-18
**Status:** Approved in conversation (structure, row, flags, search, actions, drawer/chips, approach, four design sections) — awaiting grilling pass and written-spec review
**Branch:** `feat/notes-list-redesign`
**Supersedes:** the list section of `2026-06-06-note-subsystem-foundation-design.md` (search/sort/filter top bar, funnel filter sheet)
**Related, separate projects:** **1b Journal** (date-grouped life-record timeline; its own spec next), **2 BigCalendar** (date spine; `Hmm.BigCalendar` is today only an `Appointment` domain stub with no API), **3 Sharing** (multi-user; explicitly out of scope in `hmm` docs today), **4 life-record subsystems**.

## Goal

Turn the Notes list from a flat list with a title-only search into an Outlook / Apple-Mail-style tool for finding and managing many notes: full-text search with tokens and saved searches, pins and coloured flags, tags, swipe actions, multi-select, rendered-markdown previews, date-grouped sections, a mailbox-style drawer/sidebar and a Recently Deleted bin — built so Journal, BigCalendar and Sharing can plug in later.

## Decisions

| # | Decision |
|---|----------|
| D1 | Structure: **Outlook model** — land in the list; search box + automatic chip bar; ☰ drawer on phones; permanent sidebar on wide screens. |
| D2 | **Journal is a separate root** (Project 1b). Journal shows journal entries with an optional "Also show" toggle for other notes from the same days. Notes drops any Timeline switch and uses **date section headers** instead. |
| D3 | Rows: **Standard** (2-line rendered-markdown preview) default; **Compact** (no preview) and **Rich** (4 lines + photo thumbnail) in a View menu; per device. |
| D4 | **Pins + 7 coloured flags** (Apple Mail colours), user-nameable, default red. Flag due dates deferred to BigCalendar. |
| D5 | Search: **tokens + scope toggle + recent searches + saved searches** (smart filters). |
| D6 | Actions: **fixed** swipes (right = Pin; left = Flag, Delete), long-press menu, multi-select bulk actions, **Recently Deleted** (30 days), **system share sheet** now; in-app sharing = Project 3. |
| D7 | Chip bar **automatic** (usage-ordered) for now; editable later. |
| D8 | Architecture: **`NoteQuery` + `NoteQueryEngine` interface**, first implementation in memory over a cached per-note `NoteSearchIndex`; an FTS5/server engine can replace it later without UI changes. |

## Non-goals

- Journal UI, journal entry type (Project 1b); BigCalendar events/dates (2); in-app sharing, families, permissions (3).
- Configurable swipes or chips; flag due dates/reminders; folders; FTS5 search engine; server-side full-text search.

## Data model and sync

### New note fields (Drift schemaVersion 8 → 9)

| Field | Type | Default | Meaning |
|-------|------|---------|---------|
| `isPinned` | bool | `false` | listed in the Pinned section first |
| `flagColor` | int? | `null` | null = unflagged; 0 red, 1 orange, 2 yellow, 3 green, 4 blue, 5 purple, 6 grey |

- Additive migration with defaults; existing notes are untouched.
- Pin/flag changes are real edits: they bump `lastModifiedDate`. **They do not sync automatically** — neither the cloudStorage note blob nor the API note body carries arbitrary columns today. Slice 1 adds `isPinned`/`flagColor` keys to the OneDrive note blob (absent key on pull ⇒ keep the local value) and to the API note DTOs.
- **Preservation:** the note mapper preserves fields it does not know; an API update that omits `IsPinned`/`FlagColor` keeps the stored value. An unknown `flagColor` value (from a newer client) is kept and shown as a grey flag.
- **Server (`hmm`):** EF migration adds `IsPinned` (bool, default false) and `FlagColor` (int, nullable) to the note table; note DTOs carry them; list endpoint gains `?pinned=` and `?flag=` filters. **Deployed before the client release** that writes them.

### Recently Deleted

- Reuses existing soft delete (`deletedAt`).
- Delete → sets `deletedAt` (with Undo). Restore → clears it.
- The Recently Deleted source lists notes with `deletedAt` within the last 30 days.
- **Purge:** at most once a day, never while a sync runs, notes deleted > 30 days ago are permanently removed through the existing delete path (sync tombstones and attachment GC still apply). "Delete now" and "Empty…" purge immediately after a confirmation dialog.
- **Verified 2026-10-18:** in cloudStorage a restore (clearing `deletedAt` with a newer `lastModifiedDate`) propagates under last-writer-wins, except against a tombstone with an equal-or-later timestamp. In **cloudApi un-delete is not possible today** (PUT on a soft-deleted note returns 500; no endpoint flips `IsDeleted`) — slice 1 adds a server undelete endpoint. There is **no hard-delete path** anywhere today, and `VaultGc` counts soft-deleted notes' attachments as live — slice 1 adds a real purge (client row removal + server delete + vault release).

### Tags

- Tables `Tags` and `NoteTagRefs` exist locally; `/v1/tags` exists on the server. This project adds the UI.
- **Verified 2026-10-18:** cloudStorage already syncs tags (`tags.json`, per-name LWW with tombstones) and note tag membership (a `tags` name list in each note blob). **cloudApi does not** (pull/push tags are no-ops; note DTOs carry no tags) — this project wires the existing `/v1/tags` and `PUT /notes/{id}/applyTag` endpoints so tags work in all three modes.

### Settings

| Setting | Storage | Notes |
|---------|---------|-------|
| Flag colour names | `SyncableSettings` (synced) | absent ⇒ default colour names |
| Saved searches | `SyncableSettings` (synced), each a serialized `NoteQuery` with id, name, order | unknown fields preserved |
| Row density | shared_preferences, per device | `compact` / `standard` / `rich`; default `standard` |
| Chip usage counts | per device | extends today's `filter_usage` |
| Recent searches | per device | max 10 |

### Prepared for later (not built)

`NoteQuery.source` reserves `shared` (Project 3) and `calendar` / date-range sources (BigCalendar). Rows reserve a badge slot ("shared", "event").

## Query engine and search

### `NoteQuery` (plain data; JSON when saved)

- `source`: `all` | `pinned` | `flagged(color?)` | `today` | `domain(key, catalogId?)` | `tag(tagId)` | `smart(savedId)` | `recentlyDeleted`
- `text`: free text
- `tokens`: `tag(tagId)`, `flag(color)`, `domain(key)`, `catalog(catalogId)`, `parent(noteUuid)`, `hasPhoto`, `hasPlace`, `hasAttachment`, `date(from, to)` or relative `last7d` / `last30d` / `last90d`, `pinned`
- `scope`: `all` | `currentSource`
- `sort`: `dateNewest` (default) | `dateOldest` | `lastModified` | `subjectAZ` | `flagColor`
- Unknown tokens/sources from a newer client are preserved and ignored.

### `NoteSearchIndex` (per note; cached by note id + version)

- `title` — from the display-title registry (contacts, cheatsheets readable)
- `body` — note markdown → plain text; entity-backed notes contribute their registry preview text, **never raw JSON**
- `tags`, `parentTitle`, `flagColor`, `isPinned`, `hasPhoto`, `hasPlace`, `hasAttachment`, `effectiveDate`, `lastModified`, `deletedAt`
- Normalized: lowercased, accent-folded; pinyin full + initials for Han text (reuse the contacts `PinyinTranscriber` / sort normalization).

### `NoteQueryEngine`

`Stream<NoteResults> run(NoteQuery)`; first implementation `InMemoryNoteQueryEngine`.

- Results are **grouped**: Pinned first (when sort is by date), then Today / Yesterday / This week / This month / then by month ("Oct 2026"). Title or flag sorts use flat groups ("A", "B" … / by colour).
- **Match ranges** for title and preview highlighting.
- **Counts** for drawer/sidebar/chips: per domain, tag, flag colour, Pinned, Recently Deleted. Domain semantics preserved: an attached note counts and filters under its parent's domain; "General" = unattached General notes.
- Date grouping uses the device's local time zone and the note's effective date (`noteDate ?? createDate`).

### Search behaviour

- Debounce ~150 ms.
- **Suggestions** while typing: matching tags, domains, parents, flag names, Has photos / Has place / date ranges; tap converts to a removable token chip; backspace on an empty field removes the last chip.
- **Recent searches** (max 10, per device) when the field is focused and empty.
- **Save search…** stores the current `NoteQuery` as a smart filter; rename, reorder, delete from the drawer.
- Query, tokens and scope persist on the notifier and stay visible after leaving and returning (existing tested behaviour).

### Performance

- Target: ≤ 50 ms per keystroke for 5,000 notes on a recent iPhone; a benchmark test pins it.
- Indexes build in the background on first open; the list renders immediately by title.
- Missing the target is the trigger for an FTS5 engine (out of scope).

## Screens and interaction

### Phone

- **Top bar** — iOS: large title "Notes", ☰, View ▾ (density + sort), Edit, ✎ compose, Help. Android: Material 3 app bar with the same actions; **+ FAB** instead of ✎. All icon buttons are `HmmIconButton` with localized tooltips.
- **Search field** with token chips, then the **chip bar**: All · Pinned · 🚩 Flagged · top 3 most-used domains/tags · ＋ (opens drawer).
- **List** — lazily built, date-grouped with sticky headers; pull-to-refresh triggers sync.
- **Empty states** — no notes yet / nothing matches (with Clear search) / Recently Deleted empty.
- **New note** (✎ / FAB) — created in the current context: inside a domain pre-selects it (and the car in Automobile), inside a tag pre-fills the tag.

### Wide screens

- ≥ 1000 pt: **sidebar (240) | list (360) | detail**.
- 720–1000: list | detail, sidebar as a slide-over.
- < 720: phone layout.
- Selection keeps `selectedNoteIdProvider`; contact and cheatsheet notes still open their own screens via the display registry.

### Row (`NoteRow`)

- Domain colour **bar** (replaces the dot).
- Title (📌 when pinned) + trailing time (localized) + flag in its colour.
- Preview:
  - Standard: 2 lines; Rich: 4 lines; Compact: none.
  - Rendered markdown: bold, italic, inline code, links (styled), checklist boxes, list bullets.
  - Headings render as bold text; images and tables are omitted in previews.
  - Previews are not interactive; tapping the row opens the note.
- Meta line: domain · parent · 🏷 up to 2 tags + "+n" · 📎 count · 📍 place.
- Rich: first photo thumbnail on the right; sensitive photos show a 🔒 placeholder and never trigger an unlock prompt from rendering.
- Semantics: "title, date, flagged <colour name>, pinned, preview".

### Actions

- **Swipe right:** Pin / Unpin.
- **Swipe left:** Flag (last-used colour) and Delete (moves to Recently Deleted; `showUndoableAction`).
- **Long-press:** Pin · Flag ▸ (7 colours with names) · Tags… · Attach to… · Share… · Delete. iOS context menu with preview; Android bottom sheet.
- **Multi-select:** iOS Edit button; Android long-press then tap. Bulk Pin, Flag ▸, Tags…, Delete, Select all (applies to the current query results). One Undo restores a bulk delete.
- **Share sheet:** ordinary notes share their markdown as text (`share_plus`). PDF export is deferred. Entity notes (contacts, cheatsheets, gas logs, cars, records) do not share from Notes — they show "Share from Contacts / Cheatsheets / …".
- **Delete from note detail** now moves to Recently Deleted with Undo (replaces today's immediate, no-undo delete).

### Recently Deleted

- Rows show "Deletes in N days".
- Swipe actions: Restore; Delete now (confirmation).
- Top bar: **Empty…** (confirmation).

### Drawer / sidebar

All · Pinned · Flagged (with a sub-row per colour in use, showing its name) · Today · **Domains** (counts) · **Tags** (counts; Manage tags…) · **Smart filters** (saved + built-in With photos / With place / Last 7 days; reorder and rename by long-press) · Recently Deleted.

### Tags

- Note editor gains a tag field with autocomplete; new tags are created inline.
- **Manage tags:** rename; **merge** (all notes move to the kept tag); delete (removed from its notes; confirmation).

### Replaced from today

- Domain ActionChip + catalog sub-filter popup → chip bar + drawer domain rows; the per-catalog filter survives as a `catalog` token.
- Sort sheet options → View ▾ menu.
- The 4 raw `IconButton`s → `HmmIconButton` (icon-button guard allow-list shrinks).
- Hardcoded English list strings → ARB (en + zh).

## Errors and edge cases

- **List load failure:** localized message + Retry; search keeps working on what is loaded.
- **Index build failure for one note:** that note is listed by title only; the error type is logged once (never content).
- **Pin/flag/tag write failure:** the row reverts; snackbar "Couldn't flag the note".
- **Partial bulk failure:** "Flagged 8 of 10 notes"; failed notes stay selected.
- **Saved search referencing a deleted tag or note:** that token renders struck-out "(removed)" and is ignored; the search still runs.
- **Open note deleted on another device:** detail shows "This note was moved to Recently Deleted" with Restore.
- **Cloud API server without the new fields:** pins and flags are hidden with "Pins and flags need the latest server" (safety net; the server ships first).
- Purge runs at most daily and never during sync.

## Platform rules

- **iOS:** large-title bar, Edit for multi-select, context menu with preview, no FAB, edge swipe-back preserved.
- **Android:** Material 3 app bar, FAB, long-press multi-select, bottom sheets.
- `flutter_slidable` for swipes (**new dependency** — CLAUDE.md's "Key Packages" line is wrong, it is not in pubspec today); `share_plus` for the share sheet (new dependency); `HmmIconButton` with localized tooltips everywhere; safe areas respected.
- Every new string in en and zh ARB (flag colour names, date headers, token labels); dates and times localized.

## Help

- `HelpId.notesList`: search tokens, saved searches, chip bar, swipes, long-press menu, flags and colour names, pins, multi-select, density, Recently Deleted.
- `HelpId.notesRecentlyDeleted`, `HelpId.manageTags`.
- Each entry's icon is its control's own `Icons.*` constant; en + zh ARB keys `help<Screen>…`.

## Testing

- **Query engine:** every token and source; scope; saved-search round-trip; unknown tokens preserved; counts (attached-note domain rule, General = unattached); date-group bucketing (midnight, time zones, month boundaries); pinned first; body/tag/parent/pinyin search; match ranges.
- **Search index:** markdown → text; entity notes searched by preview, never JSON; cache invalidates on version change; performance benchmark (5,000 notes, ≤ 50 ms).
- **Data:** migration 8 → 9 defaults; pin/flag round-trip through codec, mapper and API; older-client preservation; Recently Deleted delete / restore / 30-day purge / Delete now / Empty; restore-after-sync across modes; tag sync (or the gap closed).
- **Server:** migration; DTO fields; PUT without pin/flag keeps stored values; `?pinned` / `?flag` filters.
- **Widgets:** rows at each density with rendered markdown and no raw `**` / `- [ ]`; swipes; long-press menu; multi-select bulk with Undo; chip bar follows usage; drawer counts; wide layouts (3 and 2 columns); help buttons; iOS and Android variants; sensitive thumbnail shows a lock with no unlock prompt.
- **Regression:** display titles for contacts and cards; routing to their own screens; attached-note parent label; `notesSearchClear`; search stays visible after leaving.

## Decisions from grilling (2026-10-18)

These override anything above that conflicts.

- **G1 Today / date headers** use the note's effective date (`noteDate ?? createDate`); "recently edited" is the Last-modified sort, not a filter.
- **G2 Headers follow the sort:** effective date for date sorts, last-modified date for the Last-modified sort, A–Z groups for title, colour groups for flag sort.
- **G3 Pinned section** appears at the top of **every** view, containing the pinned notes that match that view.
- **G4 Delivery in six slices**, each merged and deployed independently:
  1. data + flags + server (pin/flag fields and their OneDrive/API sync, server undelete endpoint, real purge, tag API wiring);
  2. query engine, rows, date headers;
  3. search tokens + saved searches;
  4. drawer, chips, wide-screen sidebar;
  5. swipes, multi-select, Recently Deleted;
  6. tags UI and Manage tags.
  The server change ships with slice 1, before the client release.
- **G5 Saved searches** live in the synced settings bundle (whole-bundle last-writer-wins); concurrent edits on two devices may lose one — accepted.
- **G6 Recently Deleted** retention fixed at 30 days.
- **G7 Entity notes cannot be deleted from Notes.** Notes deletes only ordinary notes; contacts, cheatsheets, gas logs, cars, service records, licence and similar show "Manage in Contacts / Cheatsheets / Automobile …" instead of Delete (row action, long-press, multi-select and note detail). Pin, flag and tags work on every note. Multi-select bulk Delete skips entity notes and says how many were skipped.
- **G8 Packages:** add `flutter_slidable` and `share_plus`; no PDF library (PDF export deferred).
- **G9 Server undelete + real purge** are built in slice 1 (one deploy with the pin/flag change). Purge removes the client row, deletes on the server, and releases vault files.
- **G10 Tags work in all three modes,** wiring the existing server endpoints for cloudApi.
- **G11 Recently Deleted lists only ordinary notes** deleted from Notes. Features' own deletes never appear there. The 30-day purge applies to **all** soft-deleted notes (so deleted gas logs' and cards' photos finally leave the vault).
- **G12 Deleting a parent note** leaves its attached notes in place; their parent label reads "(deleted note)" until the parent is restored, and they become unattached after the parent is purged.
- **G13 Share** only ordinary notes (markdown text); entity notes say "Share from Contacts / Cheatsheets / …".

## Risks

- **Scope** — this is large; the plan should deliver it in independently shippable slices (data + server; query engine; row + list; drawer + chips + search UI; actions + Recently Deleted; tags; wide layout).
- **Server deploy ordering** — `IsPinned`/`FlagColor` must be live before the client release that writes them.
- **Sync semantics** for restore-after-delete and tags must be verified before UI depends on them.
- **Markdown preview cost** — mitigated by per-version caching; measured by the benchmark.
