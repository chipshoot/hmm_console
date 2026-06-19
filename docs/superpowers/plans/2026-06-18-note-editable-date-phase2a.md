# Note Editable Date (Phase 2a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each note a user-editable note date (OneNote-style, date+time) that syncs, while preserving an immutable created-at audit timestamp — by adding a new `NoteDate`/`noteDate` column to both the `hmm` serviceAPI EF layer and the `hmm_console` Flutter Drift store.

**Architecture:** `CreateDate`/`createDate` stay the immutable created-at audit on both sides (backend force-stamps it; client sets it once). A new parallel column `NoteDate` (backend) / `noteDate` (Flutter) carries the editable user-facing date. The editor edits `noteDate`; list/sort/detail display it via an `effectiveNoteDate` (`noteDate ?? createDate`) fallback; the audit `createDate` shows only in the raw-content view. The Flutter `cloudApi` note repository does not exist yet (`repository_providers.dart:31` throws), so the backend column is forward-looking; client work is local Drift + UI only.

**Tech Stack:** Backend — .NET 10, EF Core 10 (hand-written migrations), AutoMapper, xUnit (SQLite in-memory + `EnsureCreated`). Client — Flutter, Drift (SQLite), Riverpod, `intl` (`DateFormat`), Cupertino/Material adaptive pickers.

**Two repos:**
- Backend: `/Users/fchy/projects/hmm` (`Hmm.ServiceApi` solution)
- Client: `/Users/fchy/projects/hmm_console`

---

## File Structure

### Backend (`/Users/fchy/projects/hmm`)
- Modify: `src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs` — add `NoteDate` column property
- Modify: `src/Hmm.Core.Map/DomainEntity/HmmNote.cs` — add `NoteDate`
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs` — add `NoteDate` (read)
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForCreate.cs` — add `NoteDate?`
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForUpdate.cs` — add `NoteDate?`
- Modify: `src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs` — null-preserve condition on update map
- Modify: `src/Hmm.Core/DefaultManager/HmmNoteManager.cs` — default `NoteDate` to now on create
- Create: `src/Hmm.Core.Dal.EF/Migrations/20260618000000_AddNoteDateColumn.cs` — hand-written migration
- Modify: `src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs` — add `NoteDate` property
- Test: `src/Hmm.Core.Tests/HmmNoteManagerTests.cs` — create-default + update-preserve

### Client (`/Users/fchy/projects/hmm_console`)
- Modify: `lib/core/data/local/database.dart` — `noteDate` column, schemaVersion 6→7, migration
- Modify (generated): `lib/core/data/local/database.g.dart` — via build_runner
- Modify: `lib/features/notes/data/models/hmm_note.dart` — `noteDate` + `effectiveNoteDate`
- Modify: `lib/core/data/hmm_note_input.dart` — `noteDate` on create/update inputs
- Modify: `lib/features/notes/data/mappers/hmm_note_mapper.dart` — map `noteDate`
- Modify: `lib/core/data/local/local_hmm_note_repository.dart` — write `noteDate`
- Modify: `lib/features/notes/states/mutate_note_state.dart` — `noteDate` params
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart` — `_noteDate` + tappable picker
- Modify: `lib/features/notes/presentation/screens/raw_content_screen.dart` — show `createDate`
- Modify: `lib/features/notes/states/notes_list_state.dart` — sort by `effectiveNoteDate`
- Modify: `lib/features/notes/presentation/widgets/note_list_tile.dart` — display `effectiveNoteDate`
- Test: `test/features/notes/states/note_date_test.dart` (new), plus edits to existing note tests

---

# PART A — Backend (`/Users/fchy/projects/hmm`)

Run all backend commands from `/Users/fchy/projects/hmm`.

## Task A1: Add `NoteDate` to domain, DAO, and DTOs

**Files:**
- Modify: `src/Hmm.Core.Map/DomainEntity/HmmNote.cs`
- Modify: `src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs`
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForCreate.cs`
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForUpdate.cs`
- Test: `src/Hmm.Core.Map.Tests/` (mapping round-trip — optional, see Step 5)

- [ ] **Step 1: Add `NoteDate` to the domain entity**

In `src/Hmm.Core.Map/DomainEntity/HmmNote.cs`, after the `CreateDate` property (currently line 29), add:

```csharp
        /// <summary>
        /// User-editable note date (OneNote-style). Defaults to creation
        /// time but the user can change it; syncs across devices. Distinct
        /// from <see cref="CreateDate"/>, which is the immutable created-at
        /// audit stamp.
        /// </summary>
        public DateTime NoteDate { get; set; }
```

- [ ] **Step 2: Add `NoteDate` to the DAO**

In `src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs`, after the `CreateDate` property (currently lines 47-48), add:

```csharp
        [Column("notedate")]
        public DateTime NoteDate { get; set; }
```

- [ ] **Step 3: Add `NoteDate` to the read DTO**

In `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`, after `public DateTime CreateDate { get; set; }` (currently line 41), add:

```csharp
        /// <summary>
        /// User-editable note date. Distinct from <see cref="CreateDate"/>
        /// (immutable created-at audit).
        /// </summary>
        public DateTime NoteDate { get; set; }
```

- [ ] **Step 4: Add optional `NoteDate` to the write DTOs**

In `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForCreate.cs`, after the `Description` property, add:

```csharp
        /// <summary>
        /// Optional user-chosen note date. Null ⇒ server defaults to now.
        /// </summary>
        public DateTime? NoteDate { get; set; }
```

In `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForUpdate.cs`, after the `Description` property, add:

```csharp
        /// <summary>
        /// Replacement note date. Null ⇒ preserve the stored value
        /// (see the null-preserve condition in ApiMappingProfile).
        /// </summary>
        public DateTime? NoteDate { get; set; }
```

- [ ] **Step 5: Build to verify it compiles**

Run: `dotnet build src/Hmm.Core.Map/Hmm.Core.Map.csproj src/Hmm.ServiceApi.DtoEntity/Hmm.ServiceApi.DtoEntity.csproj`
Expected: Build succeeded. (`CreateDate`/`NoteDate` map by name convention; no profile edit needed for read/create.)

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Core.Map/DomainEntity/HmmNote.cs src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForCreate.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForUpdate.cs
git commit -m "feat(notes): add NoteDate column to HmmNote domain/dao/dto"
```

## Task A2: Manager defaults `NoteDate` on create; update preserves it

The update flow is load-then-merge (`HmmNoteController.Put`: `_mapper.Map(dto, existingNote)`), so a null `ApiNoteForUpdate.NoteDate` must NOT overwrite the stored value. The create flow defaults a missing date to now. Tests use SQLite-in-memory + `EnsureCreated`, so the DAO property from Task A1 is already in the test schema.

**Files:**
- Test: `src/Hmm.Core.Tests/HmmNoteManagerTests.cs`
- Modify: `src/Hmm.Core/DefaultManager/HmmNoteManager.cs`
- Modify: `src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs`

- [ ] **Step 1: Write the failing manager test (create defaults NoteDate)**

In `src/Hmm.Core.Tests/HmmNoteManagerTests.cs`, add this test (mirror the existing `CreateAsync` tests' arrange pattern — `CurrentTime` is the mocked `DateProvider.UtcNow`, and existing tests build `note` the same way; copy the note-construction lines from the test at line ~42):

```csharp
        [Fact]
        public async Task CreateAsync_defaults_NoteDate_to_now_when_unset()
        {
            // Arrange — build a note the same way the sibling CreateAsync
            // tests do (author, subject, content), leaving NoteDate unset.
            var note = new HmmNote
            {
                Author = DefaultAuthor,
                Subject = "subject",
                Content = "content",
                Catalog = DefaultCatalog,
            };

            // Act
            var created = await _noteManager.CreateAsync(note);

            // Assert — NoteDate defaulted to the provider's current time,
            // independent of (but here equal to) the CreateDate audit stamp.
            Assert.True(created.Success);
            Assert.Equal(CurrentTime, created.Value.NoteDate);
        }

        [Fact]
        public async Task CreateAsync_preserves_a_client_supplied_NoteDate()
        {
            var chosen = new DateTime(2020, 1, 2, 3, 4, 5, DateTimeKind.Utc);
            var note = new HmmNote
            {
                Author = DefaultAuthor,
                Subject = "subject",
                Content = "content",
                Catalog = DefaultCatalog,
                NoteDate = chosen,
            };

            var created = await _noteManager.CreateAsync(note);

            Assert.True(created.Success);
            Assert.Equal(chosen, created.Value.NoteDate);
            // CreateDate is still the server audit stamp, not the chosen date.
            Assert.Equal(CurrentTime, created.Value.CreateDate);
        }
```

NOTE: If `DefaultAuthor` / `DefaultCatalog` are not the helper names in this file, copy the exact note-construction lines from the existing passing test near line 42 and only add `NoteDate = chosen` for the second test. Do not invent helpers.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `dotnet test src/Hmm.Core.Tests/Hmm.Core.Tests.csproj --filter "FullyQualifiedName~NoteDate"`
Expected: FAIL — `CreateAsync_defaults_NoteDate_to_now_when_unset` fails (NoteDate is `default(DateTime)`, not `CurrentTime`).

- [ ] **Step 3: Default `NoteDate` in the manager's CreateAsync**

In `src/Hmm.Core/DefaultManager/HmmNoteManager.cs`, in `CreateAsync`, immediately after the existing line `note.CreateDate = _dateProvider.UtcNow;` (line 146), add:

```csharp
                note.NoteDate = note.NoteDate == default ? _dateProvider.UtcNow : note.NoteDate;
```

Leave `UpdateAsync` unchanged — `NoteDate` flows through from the mapped `noteDao`; only the mapping condition (Step 4) protects it from a null DTO.

- [ ] **Step 4: Add the null-preserve mapping condition for updates**

In `src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs`, change the bare update map (currently line 81):

```csharp
            CreateMap<ApiNoteForUpdate, Core.Map.DomainEntity.HmmNote>();
```

to:

```csharp
            CreateMap<ApiNoteForUpdate, Core.Map.DomainEntity.HmmNote>()
                // Null NoteDate ⇒ keep the destination's existing value
                // (Put maps the DTO onto the loaded note).
                .ForMember(d => d.NoteDate,
                    opt => opt.Condition(s => s.NoteDate.HasValue));
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `dotnet test src/Hmm.Core.Tests/Hmm.Core.Tests.csproj --filter "FullyQualifiedName~NoteDate"`
Expected: PASS (both tests).

- [ ] **Step 6: Run the full note manager + mapping suites for regressions**

Run: `dotnet test src/Hmm.Core.Tests/Hmm.Core.Tests.csproj --filter "FullyQualifiedName~HmmNote"` and `dotnet test src/Hmm.Core.Map.Tests/Hmm.Core.Map.Tests.csproj`
Expected: PASS. (Watch the existing `Assert.Equal(CreateDate, LastModifiedDate)` test at line 49 — unaffected.)

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Core/DefaultManager/HmmNoteManager.cs src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs src/Hmm.Core.Tests/HmmNoteManagerTests.cs
git commit -m "feat(notes): default NoteDate on create, preserve on null update"
```

## Task A3: Hand-written EF migration + model snapshot

Migrations here are hand-written to dodge provider-type drift (see `20260518234500_AddNoteUuidColumn.cs`). The model snapshot must be kept in sync. The new column mirrors `createdate`'s type string (`timestamp with time zone`, per the existing snapshot).

**Files:**
- Create: `src/Hmm.Core.Dal.EF/Migrations/20260618000000_AddNoteDateColumn.cs`
- Modify: `src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs`

- [ ] **Step 1: Write the migration file**

Create `src/Hmm.Core.Dal.EF/Migrations/20260618000000_AddNoteDateColumn.cs`:

```csharp
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Hmm.Core.Dal.EF.Migrations
{
    [DbContext(typeof(HmmDataContext))]
    [Migration("20260618000000_AddNoteDateColumn")]
    /// <inheritdoc />
    public partial class AddNoteDateColumn : Migration
    {
        // Hand-written for the same cross-provider drift reason as the
        // earlier hand-written migrations (uuid / attachments).
        //
        // Phase 2a: NoteDate is the user-editable note date. CreateDate
        // stays the immutable created-at audit. Existing rows backfill
        // NoteDate from CreateDate so they keep their original date.

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<System.DateTime>(
                name: "notedate",
                table: "notes",
                type: "timestamp with time zone",
                nullable: false,
                defaultValueSql: "CURRENT_TIMESTAMP");

            migrationBuilder.Sql("UPDATE notes SET notedate = createdate;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "notedate",
                table: "notes");
        }
    }
}
```

- [ ] **Step 2: Update the model snapshot**

In `src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs`, inside the `HmmNoteDao` entity block, immediately after the `CreateDate` property block (currently lines 129-131), add:

```csharp
                    b.Property<DateTime>("NoteDate")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("notedate");
```

- [ ] **Step 3: Build the EF project**

Run: `dotnet build src/Hmm.Core.Dal.EF/Hmm.Core.Dal.EF.csproj`
Expected: Build succeeded.

- [ ] **Step 4: Verify the model matches the snapshot (no pending changes)**

Run: `cd src/Hmm.Core.Dal.EF && dotnet ef migrations has-pending-model-changes; cd ../..`
Expected: "No changes have been made to the model since the last migration." (If it reports pending changes, the snapshot block in Step 2 doesn't match the DAO — fix the property/type/name to match exactly.)

- [ ] **Step 5: Run the full backend test suite**

Run: `dotnet test src/Hmm.Core.Tests/Hmm.Core.Tests.csproj`
Expected: PASS (EnsureCreated builds the new column from the model).

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Core.Dal.EF/Migrations/20260618000000_AddNoteDateColumn.cs src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs
git commit -m "feat(notes): EF migration adding notes.notedate (backfill from createdate)"
```

---

# PART B — Client (`/Users/fchy/projects/hmm_console`)

Run all client commands from `/Users/fchy/projects/hmm_console`.

## Task B1: Drift `noteDate` column + schema v7 migration

**Files:**
- Modify: `lib/core/data/local/database.dart`
- Regenerate: `lib/core/data/local/database.g.dart`

- [ ] **Step 1: Add the column to the Notes table**

In `lib/core/data/local/database.dart`, in `class Notes`, after the `createDate` line (line 58), add:

```dart
  // v7: user-editable note date (OneNote-style). Nullable so the v6→v7
  // ADD COLUMN works; reads fall back to createDate via effectiveNoteDate.
  // Distinct from createDate, which stays the immutable created-at audit.
  DateTimeColumn get noteDate => dateTime().nullable()();
```

- [ ] **Step 2: Bump schemaVersion and add the migration step**

In `lib/core/data/local/database.dart`, change `int get schemaVersion => 6;` (line 105) to:

```dart
  int get schemaVersion => 7;
```

Then, inside `onUpgrade`, after the `if (from < 6) { ... }` block (closing at line 229), add:

```dart
      if (from < 7) {
        // v7: editable note date. Backfill from create_date so existing
        // notes keep showing their original date.
        await m.addColumn(notes, notes.noteDate);
        await customStatement('UPDATE notes SET note_date = create_date');
      }
```

- [ ] **Step 3: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Builds successfully; `database.g.dart` now has a `noteDate` column on the `Note`/`NotesCompanion` types.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/core/data/local/database.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/local/database.dart lib/core/data/local/database.g.dart
git commit -m "feat(notes): add Drift notes.noteDate column (schema v7, backfill)"
```

## Task B2: `HmmNote` model + input objects

**Files:**
- Modify: `lib/features/notes/data/models/hmm_note.dart`
- Modify: `lib/core/data/hmm_note_input.dart`

- [ ] **Step 1: Add `noteDate` + `effectiveNoteDate` to the model**

In `lib/features/notes/data/models/hmm_note.dart`, add `this.noteDate,` to the constructor (after `required this.createDate,` line 21 — keep it optional/nullable, so place among the optionals):

Change the constructor optionals block to include:

```dart
    this.noteDate,
```

Then after the `final DateTime createDate;` / `final DateTime? lastModifiedDate;` lines (58-59), add:

```dart
  /// User-editable note date. Null on legacy rows pre-dating the v7
  /// migration; use [effectiveNoteDate] which falls back to [createDate].
  final DateTime? noteDate;

  /// The date to display/sort by: the editable note date, falling back to
  /// the immutable created-at when unset.
  DateTime get effectiveNoteDate => noteDate ?? createDate;
```

- [ ] **Step 2: Add `noteDate` to the input objects**

In `lib/core/data/hmm_note_input.dart`:

In `HmmNoteCreate`, add `this.noteDate,` to the constructor and the field:

```dart
  /// Optional initial note date. Null ⇒ repository stamps now.
  final DateTime? noteDate;
```

In `HmmNoteUpdate`, add `this.noteDate,` to the constructor, the field, and include it in `isEmpty`:

```dart
  /// Replacement note date. Null ⇒ don't touch the column.
  final DateTime? noteDate;
```

Update `isEmpty` to:

```dart
  bool get isEmpty =>
      subject == null &&
      content == null &&
      description == null &&
      attachments == null &&
      noteDate == null;
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/notes/data/models/hmm_note.dart lib/core/data/hmm_note_input.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/data/models/hmm_note.dart lib/core/data/hmm_note_input.dart
git commit -m "feat(notes): add noteDate to HmmNote model + create/update inputs"
```

## Task B3: Mapper reads `noteDate` from the Drift row

**Files:**
- Modify: `lib/features/notes/data/mappers/hmm_note_mapper.dart`

- [ ] **Step 1: Map `noteDate`**

In `lib/features/notes/data/mappers/hmm_note_mapper.dart`, in `fromDriftRow`, after `createDate: row.createDate,` (line 28), add:

```dart
        noteDate: row.noteDate,
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/notes/data/mappers/hmm_note_mapper.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/data/mappers/hmm_note_mapper.dart
git commit -m "feat(notes): map noteDate from Drift row"
```

## Task B4: Repository writes `noteDate` (create + update)

**Files:**
- Test: `test/features/notes/data/local_hmm_note_repository_note_date_test.dart` (new)
- Modify: `lib/core/data/local/local_hmm_note_repository.dart`

- [ ] **Step 1: Write the failing repository test**

Create `test/features/notes/data/local_hmm_note_repository_note_date_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository repo;
  late Author author;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    author = await db.into(db.authors).insertReturning(
        AuthorsCompanion.insert(accountName: 'a', role: 'owner'));
    repo = LocalHmmNoteRepository(db, () async => author);
  });

  tearDown(() async => db.close());

  test('createNote stamps noteDate when none supplied', () async {
    final note = await repo.createNote(
        const HmmNoteCreate(subject: 's', catalogId: 1));
    expect(note.noteDate, isNotNull);
    expect(note.createDate, isNotNull);
  });

  test('createNote honors an explicit noteDate', () async {
    final chosen = DateTime.utc(2020, 5, 6, 7, 8);
    final note = await repo.createNote(
        HmmNoteCreate(subject: 's', catalogId: 1, noteDate: chosen));
    expect(note.noteDate, chosen);
  });

  test('updateNote changes noteDate but never createDate', () async {
    final created = await repo.createNote(
        const HmmNoteCreate(subject: 's', catalogId: 1));
    final newDate = DateTime.utc(2019, 1, 1);
    final updated =
        await repo.updateNote(created.id, HmmNoteUpdate(noteDate: newDate));
    expect(updated.noteDate, newDate);
    expect(updated.createDate, created.createDate); // audit untouched
  });
}
```

NOTE: If `AuthorsCompanion.insert` requires different fields, copy the author-seeding line from an existing repository test under `test/` (e.g. another `local_*_repository` test) — do not invent column names.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/notes/data/local_hmm_note_repository_note_date_test.dart`
Expected: FAIL — the input objects carry `noteDate` (added in B2), but the repository doesn't write it yet, so `note.noteDate` is null / not the chosen value.

- [ ] **Step 3: Write `noteDate` in createNote**

In `lib/core/data/local/local_hmm_note_repository.dart`, in `createNote`'s `NotesCompanion.insert`, after `createDate: Value(now),` (line 140), add:

```dart
          noteDate: Value(input.noteDate ?? now),
```

- [ ] **Step 4: Write `noteDate` in updateNote**

In `updateNote`'s `NotesCompanion(...)` write (after the `attachments:` member, before `lastModifiedDate:` line 174), add:

```dart
      noteDate: patch.noteDate != null
          ? Value(patch.noteDate)
          : const Value.absent(),
```

Do NOT add `createDate` anywhere in `updateNote` — it stays the immutable audit.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/notes/data/local_hmm_note_repository_note_date_test.dart`
Expected: PASS (all three).

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/local/local_hmm_note_repository.dart test/features/notes/data/local_hmm_note_repository_note_date_test.dart
git commit -m "feat(notes): repository writes noteDate on create/update"
```

## Task B5: `MutateNote` threads `noteDate` through create/update

**Files:**
- Modify: `lib/features/notes/states/mutate_note_state.dart`

- [ ] **Step 1: Add `noteDate` to `createGeneral`**

In `lib/features/notes/states/mutate_note_state.dart`, change `createGeneral`'s signature and body. Add the param:

```dart
  Future<HmmNote> createGeneral({
    required String subject,
    String? markdownBody,
    int? parentNoteId,
    DateTime? noteDate,
  }) async {
```

and pass it into `HmmNoteCreate(...)`:

```dart
            noteDate: noteDate,
```

- [ ] **Step 2: Add `noteDate` to `updateGeneral`**

Change `updateGeneral`'s signature and `HmmNoteUpdate(...)`:

```dart
  Future<HmmNote> updateGeneral(
    int id, {
    String? subject,
    String? markdownBody,
    DateTime? noteDate,
  }) async {
    final note = await ref.read(hmmNoteRepositoryProvider).updateNote(
          id,
          HmmNoteUpdate(
              subject: subject?.trim(),
              content: markdownBody,
              noteDate: noteDate),
        );
    return note;
  }
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/notes/states/mutate_note_state.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/states/mutate_note_state.dart
git commit -m "feat(notes): thread noteDate through MutateNote create/update"
```

## Task B6: Editor — tappable OneNote-style date+time picker

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`

- [ ] **Step 1: Rename `_createdAt` → `_noteDate`**

In `lib/features/notes/presentation/screens/note_editor_screen.dart`:
- Rename the field (line 47) and its doc comment:

```dart
  /// Editable note date shown under the title. New note: defaults to now.
  /// Existing note: the note's effectiveNoteDate.
  late DateTime _noteDate;
```

- In `initState` (line 54): `_noteDate = DateTime.now();`
- In `_loadExisting` (line 72): `_noteDate = note.effectiveNoteDate.toLocal();`
- In `_stampText` (lines 136-137): replace both `_createdAt` references with `_noteDate`.

- [ ] **Step 2: Pass the date through `_save`**

In `_save`, update the create call (lines 98-100) to:

```dart
        final note = await mutate.createGeneral(
            subject: subject, markdownBody: _bodyCtrl.text,
            parentNoteId: _parentId, noteDate: _noteDate.toUtc());
```

and the update call (lines 103-104) to:

```dart
        await mutate.updateGeneral(_noteId!,
            subject: subject, markdownBody: _bodyCtrl.text,
            noteDate: _noteDate.toUtc());
```

- [ ] **Step 3: Add the picker method**

Add this method to the State class (near `_addMedia`). It is adaptive: Cupertino modal on Apple, Material date+time on Android.

```dart
  Future<void> _pickNoteDate() async {
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (isApple) {
      DateTime temp = _noteDate;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => Container(
          height: 280,
          color: CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () {
                        setState(() => _noteDate = temp);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _noteDate,
                  use24hFormat: false,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: _noteDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_noteDate),
      );
      if (!mounted) return;
      setState(() {
        _noteDate = DateTime(date.year, date.month, date.day,
            time?.hour ?? _noteDate.hour, time?.minute ?? _noteDate.minute);
      });
    }
  }
```

- [ ] **Step 4: Make the date line tappable**

Replace the date `Text(_stampText, ...)` (lines 216-218) with a tappable version that hints it's editable:

```dart
                    GestureDetector(
                      onTap: _busy ? null : _pickNoteDate,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_stampText,
                              style: DesignTokens.caption
                                  .copyWith(color: c.tertiaryLabel)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_calendar_outlined,
                              size: 14, color: c.tertiaryLabel),
                        ],
                      ),
                    ),
```

- [ ] **Step 5: Ensure imports**

Confirm the file imports `package:flutter/cupertino.dart` (for `showCupertinoModalPopup` / `CupertinoDatePicker` / `CupertinoColors`). If not present, add it to the import block. `package:intl/intl.dart` is already imported (used by `_stampText`).

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/notes/presentation/screens/note_editor_screen.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/screens/note_editor_screen.dart
git commit -m "feat(notes): tappable editable note date with date+time picker"
```

## Task B7: Raw-content view shows the immutable `createDate`

**Files:**
- Modify: `lib/features/notes/presentation/screens/raw_content_screen.dart`

- [ ] **Step 1: Add the Created line**

In `lib/features/notes/presentation/screens/raw_content_screen.dart`, in the metadata column after `Text('uuid: ${d.note.uuid}'),` (line 58), add:

```dart
                Text('created (immutable): '
                    '${d.note.createDate.toLocal().toIso8601String()}'),
                Text('noteDate (editable): '
                    '${(d.note.noteDate ?? d.note.createDate).toLocal().toIso8601String()}'),
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/notes/presentation/screens/raw_content_screen.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/screens/raw_content_screen.dart
git commit -m "feat(notes): surface immutable createDate in raw-content view"
```

## Task B8: List + sort + tile display the note date

**Files:**
- Test: `test/features/notes/states/notes_list_sort_note_date_test.dart` (new) — only if a notes_list_state test harness already exists; otherwise skip the test and do Steps 3-5.
- Modify: `lib/features/notes/states/notes_list_state.dart`
- Modify: `lib/features/notes/presentation/widgets/note_list_tile.dart`

- [ ] **Step 1: Switch sort comparisons to `effectiveNoteDate`**

In `lib/features/notes/states/notes_list_state.dart`, in the `switch (sort)` block (lines 87-94), change the date cases:

```dart
      case NoteSort.dateNewest:
        list.sort((a, b) => b.effectiveNoteDate.compareTo(a.effectiveNoteDate));
      case NoteSort.dateOldest:
        list.sort((a, b) => a.effectiveNoteDate.compareTo(b.effectiveNoteDate));
      case NoteSort.lastModified:
        list.sort((a, b) => (b.lastModifiedDate ?? b.effectiveNoteDate)
            .compareTo(a.lastModifiedDate ?? a.effectiveNoteDate));
```

Leave `subjectAZ` unchanged.

- [ ] **Step 2: Display `effectiveNoteDate` in the tile**

In `lib/features/notes/presentation/widgets/note_list_tile.dart` (line 22), change:

```dart
    final date = note.createDate.toLocal().toString().split(' ').first;
```

to:

```dart
    final date = note.effectiveNoteDate.toLocal().toString().split(' ').first;
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/notes/states/notes_list_state.dart lib/features/notes/presentation/widgets/note_list_tile.dart`
Expected: No issues.

- [ ] **Step 4: Run the full notes test suite for regressions**

Run: `flutter test test/features/notes/`
Expected: PASS. (Existing tests that build `HmmNote` without `noteDate` still compile — it's an optional param — and `effectiveNoteDate` falls back to `createDate`, preserving prior ordering/display.)

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/states/notes_list_state.dart lib/features/notes/presentation/widgets/note_list_tile.dart
git commit -m "feat(notes): list sort + tile use effectiveNoteDate"
```

## Task B9: Full client verification

- [ ] **Step 1: Analyze the whole project**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All pass.

- [ ] **Step 3: Manual smoke (optional, on iOS sim/device)**

Create a new note → tap the date line under the title → pick a past date+time → save. Reopen: the list shows the chosen date; the editor shows the chosen date; "View raw content" shows `created (immutable)` = original creation time and `noteDate (editable)` = chosen. Edit an existing note's date → save → list reflects the change; created stays fixed.

---

## Notes on scope / sequencing

- **Backend ↔ client wiring:** The Flutter `cloudApi` note repository is not implemented (`repository_providers.dart:31` throws), so there is no Flutter API mapper to update. The backend `NoteDate` column is ready for when that repo is built; today the client persists `noteDate` only to the local Drift store (covers `local` and `cloudStorage` modes). When the API note repo lands, its mapper must send/read `NoteDate` — out of scope here.
- **`local`/`cloudStorage` independence:** Part B works and ships without Part A. Part A is the user's explicit request to keep the serviceAPI schema aligned and is independently deployable.
- **Out of scope:** geo location (Phase 2b), voice/PDF media (Phase 3), changing `CreateDate`/`IAuditable` semantics.
