# Note Editable Date (Phase 2a) — Design

**Date:** 2026-06-18
**Status:** Approved (brainstorm) — pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-06-18-note-media-and-metadata-design.md` (this details **Phase 2 / N2 — Dates**). Geo (N1) is Phase 2b, separate.
**Repos touched:** `hmm_console` (Flutter client) **and** `hmm` (`Hmm.ServiceApi` backend).

## Goal

Give each note a **user-editable note date** (OneNote-style: shows the current date/time by default, becomes editable when tapped) plus a **hidden, immutable created-at** audit timestamp. The edited date must sync across devices, **including `cloudApi` mode**.

## Why this reverses the earlier "reuse createDate" idea

An earlier draft (Strategy B) planned to make the existing `createDate` the editable date and add a new local `createdAt` audit column, on the assumption that `createDate` "already syncs, no backend change." Inspecting the backend (`hmm`) showed that's only half true:

- The backend note has **one** date, `CreateDate`, and it **is** the immutable audit (`IAuditable.CreateDate`). `HmmNoteManager.CreateAsync` **force-stamps** `CreateDate = UtcNow` on create (line 146), discarding any client value; `UpdateAsync` never writes it.
- The write DTOs (`ApiNoteForCreate`, `ApiNoteForUpdate`) **do not carry `CreateDate`** — only the read DTO (`ApiNote`) exposes it.

So an edited `createDate` would **not** survive a `cloudApi` round-trip, and the backend's `CreateDate` already plays exactly the role of the desired *immutable audit*. The correct reconciliation (chosen by the user) is:

| Concept | Flutter (`hmm_console`) | Backend (`hmm`) |
|---|---|---|
| Immutable created-at audit | existing `createDate` (now surfaced only in raw view) | existing `CreateDate` (force-stamped, unchanged) |
| **Editable** user-facing note date | **new `noteDate`** | **new `NoteDate`** |

Net: **one new column on each side (`noteDate` / `NoteDate`)**. `createDate` / `CreateDate` keep their meaning everywhere (immutable audit) — the `IAuditable` contract is untouched.

## Decisions (locked during brainstorm)

1. **New editable column, both sides.** Add `noteDate` (Flutter) / `NoteDate` (backend). `createDate` / `CreateDate` stay the immutable created-at audit. The editable date syncs in all three data modes (`local`, `cloudStorage`, `cloudApi`).
2. **Date + time** picker (not date-only).
3. **Created-at (the audit) is hidden** in normal UI — surfaced **only in "View raw content"**.
4. **OneNote-style** date line: displays the note date (defaulting to "now" for a new note); tapping it opens the picker to edit.

---

## Part A — Backend (`hmm` / `Hmm.ServiceApi`)

`CreateDate` semantics are **unchanged** (immutable audit). We add a parallel `NoteDate`.

### Data model (DAO + domain)

- `Hmm.Core.Map/DbEntity/HmmNoteDao.cs`: add
  `[Column("notedate")] public DateTime NoteDate { get; set; }`.
- `Hmm.Core.Map/DomainEntity/HmmNote.cs`: add `public DateTime NoteDate { get; set; }`.

### DTOs (`Hmm.ServiceApi.DtoEntity/HmmNote/`)

- `ApiNote.cs` (read): add `public DateTime NoteDate { get; set; }`.
- `ApiNoteForCreate.cs`: add `public DateTime? NoteDate { get; set; }` (optional — null ⇒ server defaults to now).
- `ApiNoteForUpdate.cs`: add `public DateTime? NoteDate { get; set; }` (optional — null ⇒ preserve stored value).

### AutoMapper

- **No profile edits needed.** `CreateDate`/`LastModifiedDate` are already mapped **by name convention** in `HmmMappingProfile` (Dao↔Domain) and `ApiMappingProfile` (Domain↔Dto) with no explicit `.ForMember`. A matching-named `NoteDate` on Dao, domain, and DTOs maps automatically. (Confirm the create/update DTO→domain maps carry it; add a `.ForMember` only if a name mismatch or a null-coalescing default is required — see manager below.)

### Manager (`Hmm.Core/DefaultManager/HmmNoteManager.cs`)

- `CreateAsync`: **leave `CreateDate = UtcNow`** (audit, line 146). Add: `note.NoteDate = note.NoteDate == default ? _dateProvider.UtcNow : note.NoteDate;` so a client-chosen date is honored, else defaults to now.
- `UpdateAsync`: `NoteDate` flows through from the mapped `noteDao` automatically; **do not** override it (only `LastModifiedDate`/`LastModifiedBy` are stamped). If `ApiNoteForUpdate.NoteDate` is null it must resolve to the **existing stored** value, not `default(DateTime)` — verify the update path loads/preserves the current note's `NoteDate` when the DTO omits it (mirror how `Subject`/`Content` are handled; add explicit handling if the current flow would zero it).

### EF migration (`Hmm.Core.Dal.EF/Migrations/`)

- Migrations here are **hand-written** (see `20260518234500_AddNoteUuidColumn.cs`), not scaffolded — author a new `..._AddNoteDateColumn.cs` by hand following that pattern.
  - `Up`: `AddColumn<DateTime>(name: "notedate", table: "notes", nullable: false, defaultValueSql: <provider current-timestamp>)` — or add nullable then backfill then (optionally) tighten. Backfill existing rows: `UPDATE notes SET notedate = createdate` so old notes show their original date as the (now editable) note date.
  - `Down`: `DropColumn("notedate", "notes")`.
  - Account for the three providers (SQL Server / PostgreSQL / SQLite) as the existing hand-written migrations do.
- Update `HmmDataContextModelSnapshot.cs` to include the new `notedate` property (hand-written migrations require the snapshot be kept in sync).

### Backend tests

- Manager: `CreateAsync` honors a client `NoteDate` and defaults to now when unset; `CreateDate` is still server-stamped and independent. `UpdateAsync` changes `NoteDate` when supplied and preserves it (and `CreateDate`) when omitted.
- Mapping: `NoteDate` round-trips Dao↔Domain↔Dto (Create/Update/Read).

---

## Part B — Flutter client (`hmm_console`)

### Drift migration (`lib/core/data/local/database.dart` + `database.g.dart`)

- Add `DateTimeColumn get noteDate => dateTime().nullable()();` to the `Notes` table. (`createDate` stays as-is — the immutable audit; `lastModifiedDate` unchanged.)
- Bump the Drift `schemaVersion`; add a migration step:
  - `addColumn(notes, notes.noteDate)`.
  - Backfill existing rows: `UPDATE notes SET note_date = create_date`.

### Model + mapper

- `HmmNote` (`features/notes/data/models/hmm_note.dart`): add `final DateTime? noteDate;`. `createDate` already exists — it is now treated as the immutable audit (read-only in the UI). Convenience: an `effectiveNoteDate => noteDate ?? createDate` getter for display/sort fallback.
- `HmmNoteMapper`: map `noteDate` from/to the Drift row **and** the API model (backend `NoteDate`).
- `HmmNoteCreate` (`core/data/hmm_note_input.dart`): accept an optional `noteDate` (defaults to now if absent).
- `HmmNoteUpdate`: add an optional `noteDate` field so the editor can change the note date. There is **no** editable `createDate` field.

### Repository (`core/data/local/local_hmm_note_repository.dart`)

- `createNote`: write `noteDate` from the input (or now), and `createDate = now` (immutable audit — unchanged).
- `updateNote`: when `patch.noteDate != null`, write `noteDate`; **never** write `createDate`.
- API repo (`cloudApi`): send `noteDate` on create/update; read it back from `ApiNote`.

### Editor UI (`features/notes/presentation/screens/note_editor_screen.dart`)

- The editor's date state becomes `_noteDate` — the **editable** date. New note: defaults to `DateTime.now()`. Existing note: `note.effectiveNoteDate`.
- The date line under the title becomes a tappable target (wrap in `GestureDetector`/`InkWell`) opening a **date + time picker**:
  - iOS/macOS: `CupertinoDatePicker` (`CupertinoDatePickerMode.dateAndTime`) in a modal bottom sheet.
  - Android: `showDatePicker` then `showTimePicker`.
  - On pick → `setState(_noteDate = chosen)`.
- `_save`: pass the chosen date through — `createGeneral(..., noteDate: _noteDate)` on create; on update, persist `noteDate: _noteDate`. (`MutateNote.createGeneral`/`updateGeneral` gain a `noteDate` parameter that flows to the repo input/patch.)

### Raw-content view (`features/notes/presentation/screens/raw_content_screen.dart`)

- Show the immutable **`createDate`** (e.g. a line "Created: <ISO timestamp>"). This is the only place the audit timestamp appears.

### List / sort / review

- `note_list_tile`, the `NoteSort` options, and `note_detail_screen` should display/sort by the **note date** now — switch their `createDate` reads to `effectiveNoteDate` (`noteDate ?? createDate`). Backfill guarantees old rows are unaffected.

### Flutter tests

- **Migration:** an existing note row gets `noteDate == createDate` after migration; `noteDate` is independently editable and `createDate` is never touched by `updateNote`.
- **Repo:** `createNote` stamps `createDate` (audit) and writes `noteDate`; `updateNote` with a new `noteDate` updates only the note date.
- **Editor:** tapping the date line opens the picker; choosing a date and saving persists it (create + update paths). The audit date is not shown in the editor.
- **Raw view:** renders the `createDate` (audit) line.
- **List/sort:** ordering/display uses `effectiveNoteDate`.

## Sequencing

Backend first (so `cloudApi` clients have a field to write to), then the Flutter client — but `local`/`cloudStorage` modes don't depend on the backend, so the Flutter work can land and ship independently; `cloudApi` sync of the edited date simply lights up once the backend column exists.

## Out of scope (Phase 2a)

- Geo location (Phase 2b).
- Voice/PDF media (Phase 3).
- Changing `CreateDate` / `IAuditable` semantics (explicitly preserved).
