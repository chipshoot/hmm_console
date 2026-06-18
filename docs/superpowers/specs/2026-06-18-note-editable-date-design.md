# Note Editable Date (Phase 2a) — Design

**Date:** 2026-06-18
**Status:** Approved (brainstorm) — pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-06-18-note-media-and-metadata-design.md` (this details **Phase 2 / N2 — Dates**). Geo (N1) is Phase 2b, separate.

## Goal

Give each note a **user-editable note date** (OneNote-style: shows the current date/time by default, becomes editable when tapped) plus a **hidden, immutable created-at** audit timestamp. The edited date must sync across devices.

## Decisions (locked during brainstorm)

1. **Storage strategy — reuse `createDate`.** The existing `createDate` column (already synced, already drives list display + sort) becomes the **user-editable note date**. A **new `createdAt` column** holds the immutable created-at (set once, never changed). This way the edited date syncs with no backend change. (`lastModifiedDate` is unchanged — last edit.)
2. **Date + time** picker (not date-only).
3. **Created-at is hidden** in normal UI — surfaced **only in "View raw content"**.
4. **OneNote-style** date line: displays the note date (defaulting to "now" for a new note); tapping it opens the picker to edit.

## Data model

### Drift migration (`lib/core/data/local/database.dart` + `database.g.dart`)

- Add `DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();` to the `Notes` table.
- Bump the Drift `schemaVersion`; add a migration step:
  - `addColumn(notes, notes.createdAt)`.
  - Backfill existing rows: `UPDATE notes SET created_at = create_date` (so old notes get a sensible immutable audit value equal to their original create date).
- `createDate` keeps its column and default; it is no longer treated as immutable (the editor may update it).

### Model + mapper

- `HmmNote` (`features/notes/data/models/hmm_note.dart`): add `final DateTime? createdAt;` (nullable for safety; populated from the row).
- `HmmNoteMapper`: map `createdAt` from the Drift row.
- `HmmNoteCreate` (`core/data/hmm_note_input.dart`): accept an optional `createDate` (the chosen note date; defaults to now if absent). `createdAt` is **not** a create input — the repository stamps it.
- `HmmNoteUpdate`: add an optional `createDate` field so the editor can change the note date. There is **no** `createdAt` update field.

### Repository (`core/data/local/local_hmm_note_repository.dart`)

- `createNote`: write `createDate` from the input (or now) and `createdAt = now` (immutable). 
- `updateNote`: when `patch.createDate != null`, write `createDate`; **never** write `createdAt`. (Mirrors the existing "subject/content only" pattern, now adding createDate.)
- Confirm `createdAt` is never in any `NotesCompanion` written by `updateNote`/`setParentNote`/`deleteNote`.

## Editor UI (`features/notes/presentation/screens/note_editor_screen.dart`)

- Rename the editor's `_createdAt` state to `_noteDate` — the **editable** date. New note: defaults to `DateTime.now()`. Existing note: `note.createDate`.
- The date line under the title (currently a `Text`) becomes a tappable target (wrap in `GestureDetector`/`InkWell`) that opens a **date + time picker**:
  - iOS/macOS: a `CupertinoDatePicker` (`CupertinoDatePickerMode.dateAndTime`) in a modal bottom sheet.
  - Android: `showDatePicker` then `showTimePicker`.
  - On pick → `setState(_noteDate = chosen)`.
- `_save`: pass the chosen date through — `createGeneral(..., createDate: _noteDate)` on create; on update, persist `createDate: _noteDate` via `updateGeneral`/`updateNote`. (`MutateNote.createGeneral`/`updateGeneral` gain a `createDate` parameter that flows to the repo input/patch.)

## Raw-content view (`features/notes/presentation/screens/raw_content_screen.dart`)

- Show the immutable `createdAt` (e.g. a line "Created: <ISO timestamp>") alongside the raw note content. This is the only place created-at appears.

## List / sort / review

- **No changes** — `note_list_tile`, the `NoteSort` options, and `note_detail_screen` already read `createDate`, which is now the editable note date. Edits flow through automatically.

## Testing

- **Migration:** an existing note row (with `createDate`, no `createdAt`) gets `createdAt == createDate` after migration; `createdAt` is unchanged by a subsequent `updateNote`.
- **Repo:** `createNote` stamps `createdAt`; `updateNote` with a new `createDate` updates the note date but leaves `createdAt` untouched.
- **Editor:** tapping the date line opens the picker; choosing a date and saving persists it (create + update paths). Created-at is not shown in the editor.
- **Raw view:** renders the `createdAt` line.

## Out of scope (Phase 2a)

- Geo location (Phase 2b).
- Backend/API model changes (createDate already syncs; createdAt is local-only audit and is not sent over the wire).
- Voice/PDF media (Phase 3).
