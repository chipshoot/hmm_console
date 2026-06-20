# Note Geo Location (Phase 2b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optionally capture a note's location (lat/lng + reverse-geocoded label) at create time, show it as a removable Journal-style card, gated by an opt-in Settings toggle — stored in three discrete columns on both the Flutter Drift store and the `Hmm.ServiceApi` EF layer, and synced through the cloudStorage engine.

**Architecture:** Three nullable columns (`latitude`/`longitude`/`locationLabel`) on `Notes`/`HmmNote`. A client `NoteLocation` value object carries all-or-none atomicity at the create/update boundary (null = don't touch, `NoteLocation.empty` = clear, populated = set). Capture is opt-in (default off), non-blocking (fetched in the background when a new note's editor opens), and best-effort (no fix ⇒ nothing). The backend maps the scalars by AutoMapper convention with null-preserve `.Condition`s on update; the sync engine serializes/applies all three.

**Tech Stack:** Backend — .NET 10, EF Core 10 (hand-written migrations), AutoMapper, xUnit (SQLite in-memory + `EnsureCreated`). Client — Flutter, Drift, Riverpod, `geolocator`/`geocoding` (via existing `currentPositionProvider`/`reverseGeocodeProvider`), `shared_preferences`.

**Two repos:**
- Backend: `/Users/fchy/projects/hmm`, branch off `main` (e.g. `feat/note-geo-location`)
- Client: `/Users/fchy/projects/hmm_console`, branch off `main` (e.g. `feat/note-geo-location-phase2b`)

---

## File Structure

### Backend (`/Users/fchy/projects/hmm`)
- Modify: `src/Hmm.Core.Map/DomainEntity/HmmNote.cs` — add `Latitude`/`Longitude`/`LocationLabel`
- Modify: `src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs` — three columns
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`, `ApiNoteForCreate.cs`, `ApiNoteForUpdate.cs`
- Modify: `src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs` — null-preserve conditions on update
- Create: `src/Hmm.Core.Dal.EF/Migrations/20260619000000_AddNoteLocationColumns.cs`
- Modify: `src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs`
- Test: `src/Hmm.ServiceApi.Core.Tests/ApiNoteLocationMappingTests.cs` (new)

### Client (`/Users/fchy/projects/hmm_console`)
- Create: `lib/core/data/note_location.dart` — `NoteLocation` value object
- Modify: `lib/core/data/local/database.dart` (+ regen `database.g.dart`) — three columns, schema v8
- Modify: `lib/features/notes/data/models/hmm_note.dart` — fields + `location` getter
- Modify: `lib/core/data/hmm_note_input.dart` — `location` on create/update
- Modify: `lib/features/notes/data/mappers/hmm_note_mapper.dart`
- Modify: `lib/core/data/local/local_hmm_note_repository.dart`
- Modify: `lib/features/notes/states/mutate_note_state.dart`
- Create: `lib/features/settings/providers/geo_capture_provider.dart` — `geoCaptureEnabledProvider`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart` — toggle row
- Create: `lib/features/notes/providers/note_location_capture.dart` — `noteLocationCaptureProvider` + `formatPlacemark`
- Create: `lib/features/notes/presentation/widgets/note_location_card.dart`
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart`
- Modify: `lib/core/data/sync/sync_orchestrator.dart`
- Tests: new test files per task below

---

# PART A — Backend (`/Users/fchy/projects/hmm`)

Run all backend commands from `/Users/fchy/projects/hmm`.

## Task A1: Add location to domain, DAO, and DTOs

**Files:**
- Modify: `src/Hmm.Core.Map/DomainEntity/HmmNote.cs`
- Modify: `src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs`
- Modify: `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`, `ApiNoteForCreate.cs`, `ApiNoteForUpdate.cs`

- [ ] **Step 1: Domain entity** — in `src/Hmm.Core.Map/DomainEntity/HmmNote.cs`, after the `NoteDate` property, add:

```csharp
        /// <summary>Optional note location (Phase 2b). All-null = no location.</summary>
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string? LocationLabel { get; set; }
```

- [ ] **Step 2: DAO** — in `src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs`, after the `NoteDate` property block (`[Column("notedate")] public DateTime NoteDate { get; set; }`), add:

```csharp
        [Column("latitude")]
        public double? Latitude { get; set; }

        [Column("longitude")]
        public double? Longitude { get; set; }

        [Column("locationlabel")]
        [MaxLength(500)]
        public string? LocationLabel { get; set; }
```

- [ ] **Step 3: Read DTO** — in `src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`, after the `NoteDate` property, add:

```csharp
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string? LocationLabel { get; set; }
```

- [ ] **Step 4: Create + Update DTOs** — in both `ApiNoteForCreate.cs` and `ApiNoteForUpdate.cs`, after the `NoteDate` property, add the same three properties:

```csharp
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string? LocationLabel { get; set; }
```

(Both files already import `System` from Task-2a work; confirm `using System;` is present — needed for nothing new here, the types are primitives, but keep consistent.)

- [ ] **Step 5: Build** — Run: `dotnet build src/Hmm.ServiceApi.DtoEntity/Hmm.ServiceApi.DtoEntity.csproj`
Expected: Build succeeded (transitively builds `Hmm.Core.Map`).

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Core.Map/DomainEntity/HmmNote.cs src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForCreate.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForUpdate.cs
git commit -m "feat(notes): add location columns to HmmNote domain/dao/dto"
```

## Task A2: Null-preserve mapping on update

The controller `Put` maps `ApiNoteForUpdate` onto the loaded note (`_mapper.Map(dto, curNote)`), so an omitted location field must not zero the stored value. Read/create map by convention (no edits).

**Files:**
- Test: `src/Hmm.ServiceApi.Core.Tests/ApiNoteLocationMappingTests.cs` (new)
- Modify: `src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs`

- [ ] **Step 1: Write the failing test** — create `src/Hmm.ServiceApi.Core.Tests/ApiNoteLocationMappingTests.cs`:

```csharp
using Hmm.Core.Map.DomainEntity;
using Hmm.ServiceApi.DtoEntity.HmmNote;
using Hmm.Utility.TestHelp;
using Xunit;

namespace Hmm.ServiceApi.Core.Tests;

/// <summary>
/// Phase 2b: location round-trips, and a PUT that omits location fields
/// must preserve the stored value (controller maps DTO onto loaded note).
/// </summary>
public class ApiNoteLocationMappingTests : CoreTestFixtureBase
{
    private static HmmNote Existing() => new()
    {
        Id = 1, Subject = "s", Content = "{}",
        Author = new Author { Id = 1 }, Catalog = new NoteCatalog { Id = 1 },
        Latitude = 47.6, Longitude = -122.3, LocationLabel = "Seattle, WA",
    };

    [Fact]
    public void Update_with_null_location_preserves_stored_value()
    {
        var note = Existing();
        var dto = new ApiNoteForUpdate { Subject = "s2" }; // location omitted

        ApiMapper.Map(dto, note);

        Assert.Equal(47.6, note.Latitude);
        Assert.Equal(-122.3, note.Longitude);
        Assert.Equal("Seattle, WA", note.LocationLabel);
    }

    [Fact]
    public void Update_with_location_overwrites()
    {
        var note = Existing();
        var dto = new ApiNoteForUpdate
        {
            Subject = "s2", Latitude = 1.0, Longitude = 2.0, LocationLabel = "X",
        };

        ApiMapper.Map(dto, note);

        Assert.Equal(1.0, note.Latitude);
        Assert.Equal(2.0, note.Longitude);
        Assert.Equal("X", note.LocationLabel);
    }

    [Fact]
    public void Create_maps_location_through()
    {
        var dto = new ApiNoteForCreate
        {
            Subject = "s", AuthorId = 1, CatalogId = 1,
            Latitude = 10.0, Longitude = 20.0, LocationLabel = "Y",
        };

        var note = ApiMapper.Map<ApiNoteForCreate, HmmNote>(dto);

        Assert.Equal(10.0, note.Latitude);
        Assert.Equal(20.0, note.Longitude);
        Assert.Equal("Y", note.LocationLabel);
    }
}
```

- [ ] **Step 2: Run to verify it fails** — Run: `dotnet test src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj --filter "FullyQualifiedName~ApiNoteLocationMapping"`
Expected: FAIL — `Update_with_null_location_preserves_stored_value` fails (default-by-convention maps null onto the destination, zeroing Latitude/Longitude to null).

- [ ] **Step 3: Add the null-preserve conditions** — in `src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs`, change the `ApiNoteForUpdate → HmmNote` map (it currently ends with the Phase-2a `.ForMember(d => d.NoteDate, ...)`) to also include:

```csharp
            CreateMap<ApiNoteForUpdate, Core.Map.DomainEntity.HmmNote>()
                .ForMember(d => d.NoteDate,
                    opt => opt.Condition(s => s.NoteDate.HasValue))
                // Phase 2b: omitted location fields preserve stored values.
                .ForMember(d => d.Latitude,
                    opt => opt.Condition(s => s.Latitude.HasValue))
                .ForMember(d => d.Longitude,
                    opt => opt.Condition(s => s.Longitude.HasValue))
                .ForMember(d => d.LocationLabel,
                    opt => opt.Condition(s => s.LocationLabel != null));
```

(Keep the existing `NoteDate` condition; just append the three location conditions to the same map.)

- [ ] **Step 4: Run to verify it passes** — Run: `dotnet test src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj --filter "FullyQualifiedName~ApiNoteLocationMapping"`
Expected: PASS (all three).

- [ ] **Step 5: Regression** — Run: `dotnet test src/Hmm.ServiceApi.Core.Tests/Hmm.ServiceApi.Core.Tests.csproj` and `dotnet test src/Hmm.Core.Tests/Hmm.Core.Tests.csproj`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs src/Hmm.ServiceApi.Core.Tests/ApiNoteLocationMappingTests.cs
git commit -m "feat(notes): preserve location on null update; map create/read by convention"
```

## Task A3: EF migration + model snapshot

**Files:**
- Create: `src/Hmm.Core.Dal.EF/Migrations/20260619000000_AddNoteLocationColumns.cs`
- Modify: `src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs`

- [ ] **Step 1: Migration file** — create `src/Hmm.Core.Dal.EF/Migrations/20260619000000_AddNoteLocationColumns.cs`:

```csharp
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Hmm.Core.Dal.EF.Migrations
{
    [DbContext(typeof(HmmDataContext))]
    [Migration("20260619000000_AddNoteLocationColumns")]
    /// <inheritdoc />
    public partial class AddNoteLocationColumns : Migration
    {
        // Hand-written for the same cross-provider drift reason as the
        // earlier migrations. Phase 2b: optional note location, three
        // nullable columns, no backfill (existing notes have no location).

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "latitude", table: "notes",
                type: "double precision", nullable: true);
            migrationBuilder.AddColumn<double>(
                name: "longitude", table: "notes",
                type: "double precision", nullable: true);
            migrationBuilder.AddColumn<string>(
                name: "locationlabel", table: "notes",
                type: "character varying(500)", maxLength: 500, nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "latitude", table: "notes");
            migrationBuilder.DropColumn(name: "longitude", table: "notes");
            migrationBuilder.DropColumn(name: "locationlabel", table: "notes");
        }
    }
}
```

- [ ] **Step 2: Snapshot** — in `src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs`, inside the `HmmNoteDao` entity block, add three properties in alphabetical position (Latitude after IsDeleted, LocationLabel after Latitude, Longitude after LocationLabel — i.e. group them where alphabetical order places them: `...IsDeleted`, `Latitude`, `LocationLabel`, `Longitude`, `NoteDate`...). Add:

```csharp
                    b.Property<double?>("Latitude")
                        .HasColumnType("double precision")
                        .HasColumnName("latitude");

                    b.Property<string>("LocationLabel")
                        .HasMaxLength(500)
                        .HasColumnType("character varying(500)")
                        .HasColumnName("locationlabel");

                    b.Property<double?>("Longitude")
                        .HasColumnType("double precision")
                        .HasColumnName("longitude");
```

(Exact ordering doesn't affect correctness — EF compares the model, not text order — but keep it readable.)

- [ ] **Step 3: Build** — Run: `dotnet build src/Hmm.Core.Dal.EF/Hmm.Core.Dal.EF.csproj`
Expected: Build succeeded.

- [ ] **Step 4: Backend test suite** (EnsureCreated builds the new columns from the model) — Run: `dotnet test src/Hmm.Core.Tests/Hmm.Core.Tests.csproj`
Expected: PASS. (Note: `dotnet ef migrations has-pending-model-changes` reports drift for this repo regardless — that's the documented pre-existing PG-vs-SqlServer type drift, the reason migrations are hand-written; the authoritative check is the EnsureCreated-based test suite.)

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm
git add src/Hmm.Core.Dal.EF/Migrations/20260619000000_AddNoteLocationColumns.cs src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs
git commit -m "feat(notes): EF migration adding notes location columns"
```

---

# PART B — Client (`/Users/fchy/projects/hmm_console`)

Run all client commands from `/Users/fchy/projects/hmm_console`.

## Task B1: `NoteLocation` value object

**Files:**
- Create: `lib/core/data/note_location.dart`
- Test: `test/core/data/note_location_test.dart`

- [ ] **Step 1: Write the failing test** — create `test/core/data/note_location_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/note_location.dart';

void main() {
  test('empty is empty; populated is not', () {
    expect(NoteLocation.empty.isEmpty, isTrue);
    expect(const NoteLocation(latitude: 1, longitude: 2).isEmpty, isFalse);
  });

  test('label is optional', () {
    const loc = NoteLocation(latitude: 1, longitude: 2);
    expect(loc.label, isNull);
    expect(loc.isEmpty, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — Run: `flutter test test/core/data/note_location_test.dart`
Expected: FAIL — `note_location.dart` doesn't exist.

- [ ] **Step 3: Implement** — create `lib/core/data/note_location.dart`:

```dart
/// Optional note location (Phase 2b). All-or-none at the boundary:
/// [empty] signals "clear", a populated instance signals "set", and a null
/// reference (in patch objects) signals "don't touch".
class NoteLocation {
  const NoteLocation({this.latitude, this.longitude, this.label});

  final double? latitude;
  final double? longitude;
  final String? label;

  bool get isEmpty => latitude == null && longitude == null;

  static const empty = NoteLocation();
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/core/data/note_location_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/note_location.dart test/core/data/note_location_test.dart
git commit -m "feat(notes): NoteLocation value object"
```

## Task B2: Drift columns + schema v8

**Files:**
- Modify: `lib/core/data/local/database.dart` (+ regen `database.g.dart`)

- [ ] **Step 1: Add columns** — in `lib/core/data/local/database.dart`, in `class Notes`, after the `noteDate` column, add:

```dart
  // v8: optional note location (Phase 2b). All-null = no location.
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get locationLabel => text().withLength(min: 0, max: 500).nullable()();
```

- [ ] **Step 2: Bump schemaVersion + migration** — change `int get schemaVersion => 7;` to `=> 8;`, and after the `if (from < 7) { ... }` block in `onUpgrade`, add:

```dart
      if (from < 8) {
        // v8: optional note location. No backfill — existing notes have none.
        await m.addColumn(notes, notes.latitude);
        await m.addColumn(notes, notes.longitude);
        await m.addColumn(notes, notes.locationLabel);
      }
```

- [ ] **Step 3: Regenerate** — Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: success; `database.g.dart` has `latitude`/`longitude`/`locationLabel`.

- [ ] **Step 4: Analyze** — Run: `flutter analyze lib/core/data/local/database.dart`
Expected: No issues.

- [ ] **Step 5: Update the schema-version assertion test** — in `test/core/data/local/tags_schema_v6_test.dart`, change `expect(db.schemaVersion, 7);` to `expect(db.schemaVersion, 8);` and update its comment to mention v8 added the location columns.

- [ ] **Step 6: Run that test** — Run: `flutter test test/core/data/local/tags_schema_v6_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/local/database.dart lib/core/data/local/database.g.dart test/core/data/local/tags_schema_v6_test.dart
git commit -m "feat(notes): add Drift notes location columns (schema v8)"
```

## Task B3: `HmmNote` model + inputs

**Files:**
- Modify: `lib/features/notes/data/models/hmm_note.dart`
- Modify: `lib/core/data/hmm_note_input.dart`

- [ ] **Step 1: Model** — in `lib/features/notes/data/models/hmm_note.dart`, add the import at the top:

```dart
import '../../../../core/data/note_location.dart';
```

Add `this.latitude,`, `this.longitude,`, `this.locationLabel,` to the constructor's optional params (near `this.noteDate,`). After the `noteDate` field, add:

```dart
  final double? latitude;
  final double? longitude;
  final String? locationLabel;

  /// Convenience: the note's location, or null when none is set.
  NoteLocation? get location => (latitude == null && longitude == null)
      ? null
      : NoteLocation(
          latitude: latitude, longitude: longitude, label: locationLabel);
```

- [ ] **Step 2: Inputs** — in `lib/core/data/hmm_note_input.dart`, add the import:

```dart
import 'note_location.dart';
```

In `HmmNoteCreate`: add `this.location,` to the constructor and the field:

```dart
  /// Optional initial location. Null or [NoteLocation.empty] ⇒ no location.
  final NoteLocation? location;
```

In `HmmNoteUpdate`: add `this.location,` to the constructor and the field, and include it in `isEmpty`:

```dart
  /// Patch semantics: null = don't touch; [NoteLocation.empty] = clear
  /// (write SQL NULL ×3); populated = set.
  final NoteLocation? location;
```

Update `isEmpty` to also check `location == null`.

- [ ] **Step 3: Analyze** — Run: `flutter analyze lib/features/notes/data/models/hmm_note.dart lib/core/data/hmm_note_input.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/data/models/hmm_note.dart lib/core/data/hmm_note_input.dart
git commit -m "feat(notes): add location to HmmNote model + create/update inputs"
```

## Task B4: Mapper reads location

**Files:**
- Modify: `lib/features/notes/data/mappers/hmm_note_mapper.dart`

- [ ] **Step 1: Map columns** — in `fromDriftRow`, after `noteDate: row.noteDate,`, add:

```dart
        latitude: row.latitude,
        longitude: row.longitude,
        locationLabel: row.locationLabel,
```

- [ ] **Step 2: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/features/notes/data/mappers/hmm_note_mapper.dart
git add lib/features/notes/data/mappers/hmm_note_mapper.dart
git commit -m "feat(notes): map location from Drift row"
```

Expected analyze: No issues.

## Task B5: Repository writes/clears location

**Files:**
- Test: `test/core/data/local/local_hmm_note_repository_location_test.dart` (new)
- Modify: `lib/core/data/local/local_hmm_note_repository.dart`

- [ ] **Step 1: Write the failing test** — create `test/core/data/local/local_hmm_note_repository_location_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';

void main() {
  late HmmDatabase db;
  late Author author;
  late int catalogId;
  late LocalHmmNoteRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'tester'),
        );
    author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    catalogId = await db.into(db.noteCatalogs).insert(
          NoteCatalogsCompanion.insert(name: 'C', schema: '{}'),
        );
    repo = LocalHmmNoteRepository(db, () async => author);
  });

  tearDown(() async => db.close());

  test('createNote with no location leaves all three null', () async {
    final n = await repo.createNote(
        HmmNoteCreate(subject: 's', catalogId: catalogId));
    expect(n.location, isNull);
    expect(n.latitude, isNull);
  });

  test('createNote writes the location trio', () async {
    final n = await repo.createNote(HmmNoteCreate(
      subject: 's', catalogId: catalogId,
      location: const NoteLocation(latitude: 47.6, longitude: -122.3, label: 'Seattle'),
    ));
    expect(n.latitude, 47.6);
    expect(n.longitude, -122.3);
    expect(n.locationLabel, 'Seattle');
  });

  test('updateNote with empty location clears the trio', () async {
    final created = await repo.createNote(HmmNoteCreate(
      subject: 's', catalogId: catalogId,
      location: const NoteLocation(latitude: 1, longitude: 2, label: 'X'),
    ));
    final updated = await repo.updateNote(
        created.id, const HmmNoteUpdate(location: NoteLocation.empty));
    expect(updated.location, isNull);
    expect(updated.latitude, isNull);
    expect(updated.locationLabel, isNull);
  });

  test('updateNote with null location leaves it untouched', () async {
    final created = await repo.createNote(HmmNoteCreate(
      subject: 's', catalogId: catalogId,
      location: const NoteLocation(latitude: 1, longitude: 2, label: 'X'),
    ));
    final updated =
        await repo.updateNote(created.id, const HmmNoteUpdate(subject: 's2'));
    expect(updated.latitude, 1);
    expect(updated.locationLabel, 'X');
  });
}
```

- [ ] **Step 2: Run to verify it fails** — Run: `flutter test test/core/data/local/local_hmm_note_repository_location_test.dart`
Expected: FAIL — the repo ignores `input.location`.

- [ ] **Step 3: createNote** — in `lib/core/data/local/local_hmm_note_repository.dart`, in `createNote`'s `NotesCompanion.insert`, after `noteDate: Value(input.noteDate ?? now),`, add:

```dart
          latitude: Value(input.location?.isEmpty == false
              ? input.location!.latitude
              : null),
          longitude: Value(input.location?.isEmpty == false
              ? input.location!.longitude
              : null),
          locationLabel: Value(input.location?.isEmpty == false
              ? input.location!.label
              : null),
```

- [ ] **Step 4: updateNote** — in `updateNote`'s `NotesCompanion(...)`, after the `noteDate:` member, add:

```dart
      latitude: patch.location == null
          ? const Value.absent()
          : Value(patch.location!.latitude),
      longitude: patch.location == null
          ? const Value.absent()
          : Value(patch.location!.longitude),
      locationLabel: patch.location == null
          ? const Value.absent()
          : Value(patch.location!.label),
```

(When `patch.location` is `NoteLocation.empty`, its `latitude`/`longitude`/`label` are all null, so this writes SQL NULL — i.e. clears. When populated, it sets. When null, absent — untouched.)

- [ ] **Step 5: Run to verify it passes** — Run: `flutter test test/core/data/local/local_hmm_note_repository_location_test.dart`
Expected: PASS (all four).

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/local/local_hmm_note_repository.dart test/core/data/local/local_hmm_note_repository_location_test.dart
git commit -m "feat(notes): repository writes/clears location"
```

## Task B6: `MutateNote` threads location

**Files:**
- Modify: `lib/features/notes/states/mutate_note_state.dart`

- [ ] **Step 1: Add the import** — at the top of `lib/features/notes/states/mutate_note_state.dart`:

```dart
import '../../../core/data/note_location.dart';
```

- [ ] **Step 2: createGeneral** — add `NoteLocation? location,` to the named params and pass `location: location,` into `HmmNoteCreate(...)`.

- [ ] **Step 3: updateGeneral** — add `NoteLocation? location,` to the named params and pass `location: location` into `HmmNoteUpdate(...)`.

- [ ] **Step 4: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/features/notes/states/mutate_note_state.dart
git add lib/features/notes/states/mutate_note_state.dart
git commit -m "feat(notes): thread location through MutateNote create/update"
```

Expected analyze: No issues.

## Task B7: `geoCaptureEnabledProvider` (opt-in toggle)

**Files:**
- Create: `lib/features/settings/providers/geo_capture_provider.dart`
- Test: `test/features/settings/geo_capture_provider_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/settings/geo_capture_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/providers/geo_capture_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to false and persists when set', () async {
    SharedPreferences.setMockInitialValues({});
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);

    expect(await c1.read(geoCaptureEnabledProvider.future), isFalse);
    await c1.read(geoCaptureEnabledProvider.notifier).setEnabled(true);
    expect(await c1.read(geoCaptureEnabledProvider.future), isTrue);

    // New container re-reads the persisted value.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    expect(await c2.read(geoCaptureEnabledProvider.future), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — Run: `flutter test test/features/settings/geo_capture_provider_test.dart`
Expected: FAIL — provider file doesn't exist.

- [ ] **Step 3: Implement** — create `lib/features/settings/providers/geo_capture_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in toggle: "Add location to new notes". Default false. Device-local
/// (not synced). AsyncNotifier so the editor can `await .future` and reliably
/// read the persisted value before deciding to capture.
class GeoCaptureNotifier extends AsyncNotifier<bool> {
  static const _key = 'geo_capture_enabled';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = AsyncData(value);
  }
}

final geoCaptureEnabledProvider =
    AsyncNotifierProvider<GeoCaptureNotifier, bool>(GeoCaptureNotifier.new);
```

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/features/settings/geo_capture_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/settings/providers/geo_capture_provider.dart test/features/settings/geo_capture_provider_test.dart
git commit -m "feat(settings): opt-in geoCaptureEnabled toggle (default off, persisted)"
```

## Task B8: `noteLocationCaptureProvider` + `formatPlacemark`

Wraps GPS + reverse-geocode into a single `NoteLocation?` so the editor has one injectable seam (testable without constructing `Position`/`Placemark`).

**Files:**
- Create: `lib/features/notes/providers/note_location_capture.dart`
- Test: `test/features/notes/providers/format_placemark_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/notes/providers/format_placemark_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hmm_console/features/notes/providers/note_location_capture.dart';

void main() {
  test('joins locality + admin area, skipping blanks', () {
    final p = Placemark(locality: 'Seattle', administrativeArea: 'WA');
    expect(formatPlacemark(p), 'Seattle, WA');
  });

  test('returns null for a null placemark or all-blank fields', () {
    expect(formatPlacemark(null), isNull);
    expect(formatPlacemark(Placemark(locality: '', administrativeArea: '')),
        isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — Run: `flutter test test/features/notes/providers/format_placemark_test.dart`
Expected: FAIL — file/function doesn't exist.

- [ ] **Step 3: Implement** — create `lib/features/notes/providers/note_location_capture.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../../../core/data/note_location.dart';
import '../../gas_log/providers/location_provider.dart';

/// Builds a human label from a placemark, e.g. "Seattle, WA". Null when the
/// placemark is null or yields no usable parts.
String? formatPlacemark(Placemark? p) {
  if (p == null) return null;
  final parts = [p.locality, p.administrativeArea]
      .where((s) => s != null && s.isNotEmpty)
      .cast<String>()
      .toList();
  return parts.isEmpty ? null : parts.join(', ');
}

/// Best-effort current-location capture: GPS fix + reverse-geocoded label.
/// Returns null when no fix is available (denied/off/timeout). The label may
/// be null even when coordinates are present (geocode failed).
final noteLocationCaptureProvider = FutureProvider<NoteLocation?>((ref) async {
  final pos = await ref.watch(currentPositionProvider.future);
  if (pos == null) return null;
  final place = await ref.watch(reverseGeocodeProvider(
    (latitude: pos.latitude, longitude: pos.longitude),
  ).future);
  return NoteLocation(
    latitude: pos.latitude,
    longitude: pos.longitude,
    label: formatPlacemark(place),
  );
});
```

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/features/notes/providers/format_placemark_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/providers/note_location_capture.dart test/features/notes/providers/format_placemark_test.dart
git commit -m "feat(notes): noteLocationCaptureProvider + formatPlacemark"
```

## Task B9: `NoteLocationCard` widget

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_location_card.dart`
- Test: `test/features/notes/presentation/widgets/note_location_card_test.dart` (new)

- [ ] **Step 1: Write the failing test** — create `test/features/notes/presentation/widgets/note_location_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_location_card.dart';

void main() {
  testWidgets('shows label and a remove button when not read-only',
      (t) async {
    var removed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteLocationCard(
          location: const NoteLocation(latitude: 47.6, longitude: -122.3, label: 'Seattle, WA'),
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.text('Seattle, WA'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });

  testWidgets('falls back to coordinates and hides remove when read-only',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteLocationCard(
          location: const NoteLocation(latitude: 47.6, longitude: -122.3),
          readOnly: true,
        ),
      ),
    ));
    expect(find.textContaining('47.6'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — Run: `flutter test test/features/notes/presentation/widgets/note_location_card_test.dart`
Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement** — create `lib/features/notes/presentation/widgets/note_location_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/data/note_location.dart';

/// Journal-style location chip: a pin + label (or "lat, lng" when no label),
/// with an optional remove (✕). Used in the editor (editable) and the note
/// detail view (read-only).
class NoteLocationCard extends StatelessWidget {
  const NoteLocationCard({
    super.key,
    required this.location,
    this.onRemove,
    this.readOnly = false,
  });

  final NoteLocation location;
  final VoidCallback? onRemove;
  final bool readOnly;

  String get _text =>
      location.label ??
      '${location.latitude?.toStringAsFixed(4)}, '
          '${location.longitude?.toStringAsFixed(4)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (!readOnly && onRemove != null)
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/features/notes/presentation/widgets/note_location_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/widgets/note_location_card.dart test/features/notes/presentation/widgets/note_location_card_test.dart
git commit -m "feat(notes): NoteLocationCard widget"
```

## Task B10: Settings screen toggle row

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

- [ ] **Step 1: Import** — add to the import block:

```dart
import '../../providers/geo_capture_provider.dart';
```

- [ ] **Step 2: Add the toggle row** — in `build`, inside the `Column`'s `children:` list (place it near the other preference rows; insert after one of the existing `GapWidgets.h*` separators so spacing matches), add:

```dart
            Consumer(builder: (context, ref, _) {
              final async = ref.watch(geoCaptureEnabledProvider);
              return SwitchListTile.adaptive(
                title: const Text('Add location to new notes'),
                subtitle: const Text(
                    'Capture your location when you create a note'),
                value: async.asData?.value ?? false,
                onChanged: async.isLoading
                    ? null
                    : (v) => ref
                        .read(geoCaptureEnabledProvider.notifier)
                        .setEnabled(v),
              );
            }),
            GapWidgets.h16,
```

- [ ] **Step 3: Analyze** — Run: `flutter analyze lib/features/settings/presentation/screens/settings_screen.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat(settings): add 'Add location to new notes' toggle row"
```

## Task B11: Editor — capture, card, save

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Test: `test/features/notes/presentation/note_editor_location_test.dart` (new)

- [ ] **Step 1: Write the failing widget test** — create `test/features/notes/presentation/note_editor_location_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_location_card.dart';
import 'package:hmm_console/features/notes/providers/note_location_capture.dart';
import 'package:hmm_console/features/settings/providers/geo_capture_provider.dart';

void main() {
  testWidgets('new note shows a location card when capture is enabled',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
                path: 'editor', builder: (c, s) => const NoteEditorScreen()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        geoCaptureEnabledProvider.overrideWith(() => _EnabledGeo()),
        noteLocationCaptureProvider.overrideWith((ref) async =>
            const NoteLocation(
                latitude: 47.6, longitude: -122.3, label: 'Seattle, WA')),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NoteLocationCard), findsOneWidget);
    expect(find.text('Seattle, WA'), findsOneWidget);
  });
}

class _EnabledGeo extends GeoCaptureNotifier {
  @override
  Future<bool> build() async => true;
}
```

- [ ] **Step 2: Run to verify it fails** — Run: `flutter test test/features/notes/presentation/note_editor_location_test.dart`
Expected: FAIL — the editor doesn't render a location card yet.

- [ ] **Step 3: Add state + capture** — in `lib/features/notes/presentation/screens/note_editor_screen.dart`:

Add imports:

```dart
import '../../../../core/data/note_location.dart';
import '../../providers/note_location_capture.dart';
import '../../../settings/providers/geo_capture_provider.dart';
import '../widgets/note_location_card.dart';
```

Add state near `_pendingPicks`:

```dart
  /// Captured/loaded note location (Phase 2b). Null = none. Shown as a card.
  NoteLocation? _pendingLocation;
  /// True once we've persisted a location that the user then removed, so an
  /// update writes the clear.
  bool _locationCleared = false;
```

In `initState`, after the existing assignments, add a fire-and-forget capture for **new** notes:

```dart
    if (widget.noteId == null) {
      _maybeCaptureLocation();
    }
```

Add the method (near `_addMedia`):

```dart
  Future<void> _maybeCaptureLocation() async {
    final enabled = await ref.read(geoCaptureEnabledProvider.future);
    if (!enabled || !mounted) return;
    final loc = await ref.read(noteLocationCaptureProvider.future);
    if (loc == null || !mounted) return;
    setState(() => _pendingLocation = loc);
  }
```

In `_loadExisting`, after seeding other fields, seed from the saved note:

```dart
      _pendingLocation = note.location;
```

- [ ] **Step 4: Render the card** — in `build`, after the date line / before the media card list (place it where it reads well, e.g. just below the `GestureDetector` date row), add:

```dart
                    if (_pendingLocation != null &&
                        !_pendingLocation!.isEmpty)
                      NoteLocationCard(
                        location: _pendingLocation!,
                        onRemove: () => setState(() {
                          _pendingLocation = null;
                          _locationCleared = true;
                        }),
                      ),
```

- [ ] **Step 5: Persist on save** — in `_save`, pass location through. For **create**:

```dart
        final note = await mutate.createGeneral(
            subject: subject, markdownBody: _bodyCtrl.text,
            parentNoteId: _parentId, noteDate: _noteDate.toUtc(),
            location: _pendingLocation);
```

For **update**, compute the patch and pass it:

```dart
        await mutate.updateGeneral(_noteId!,
            subject: subject, markdownBody: _bodyCtrl.text,
            noteDate: _noteDate.toUtc(),
            location: _locationCleared ? NoteLocation.empty : null);
```

(For 2b there is no edit-to-a-new-place path, so on update we only ever **clear** a removed location (`NoteLocation.empty`); otherwise we pass `null` = don't touch.)

- [ ] **Step 6: Run to verify it passes** — Run: `flutter test test/features/notes/presentation/note_editor_location_test.dart`
Expected: PASS.

- [ ] **Step 7: Analyze + full editor tests** — Run: `flutter analyze lib/features/notes/presentation/screens/note_editor_screen.dart` and `flutter test test/features/notes/presentation/`
Expected: No issues; all pass. (The existing `_FakeMutate`s gained `noteDate` in 2a; this task adds a `location` named param to `createGeneral`/`updateGeneral`, so update those fakes the same way — add `NoteLocation? location` to each fake override signature. Files: `note_editor_media_test.dart`, `note_editor_attach_test.dart`, `note_editor_parent_test.dart`, `note_editor_screen_test.dart`.)

- [ ] **Step 8: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/
git commit -m "feat(notes): editor captures + shows + persists note location"
```

## Task B12: Detail view shows the location card

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart`

- [ ] **Step 1: Import** — add:

```dart
import '../widgets/note_location_card.dart';
```

- [ ] **Step 2: Render** — where the detail builds its body (near the existing `NoteMediaCardList` usage), add, guarded by the note having a location:

```dart
            if (note.location != null)
              NoteLocationCard(location: note.location!, readOnly: true),
```

(Use the variable name the screen already binds for the note — match the existing media-card line's source.)

- [ ] **Step 3: Analyze + commit**

```bash
cd /Users/fchy/projects/hmm_console
flutter analyze lib/features/notes/presentation/screens/note_detail_screen.dart
git add lib/features/notes/presentation/screens/note_detail_screen.dart
git commit -m "feat(notes): show location card in note detail view"
```

Expected analyze: No issues.

## Task B13: Sync the location through cloudStorage

**Files:**
- Modify: `lib/core/data/sync/sync_orchestrator.dart`
- Test: `test/core/data/sync/sync_orchestrator_location_test.dart` (new)

- [ ] **Step 1: Write the failing round-trip test** — create `test/core/data/sync/sync_orchestrator_location_test.dart` (model it on `sync_orchestrator_note_date_test.dart`'s harness + `_FakeCloudSyncProvider` with a `remoteBodies` map):

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late HmmDatabase db;
  late _FakeProvider provider;
  late SyncOrchestrator orchestrator;
  late SyncMetaRepository meta;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    provider = _FakeProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(provider: provider, db: db, meta: meta);
  });

  tearDown(() async => db.close());

  test('outbound: pushed body carries the location trio', () async {
    final id = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'p', authorId: 1,
          latitude: const Value(47.6),
          longitude: const Value(-122.3),
          locationLabel: const Value('Seattle, WA'),
        ));
    final note =
        await (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: DateTime.utc(2026, 1, 1),
      deviceId: 't', notes: const [], attachments: const []);

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    final body = provider.pushed[note.uuid]!;
    expect(body['latitude'], 47.6);
    expect(body['longitude'], -122.3);
    expect(body['locationLabel'], 'Seattle, WA');
  });

  test('inbound insert applies the location trio', () async {
    const uuid = 'r1';
    final t = DateTime.utc(2026, 2, 2);
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: t, deviceId: 'o',
      notes: [ManifestEntry(id: uuid, updatedAt: t, deleted: false)],
      attachments: const []);
    provider.remoteBodies[uuid] = {
      'uuid': uuid, 'subject': 'x',
      'createDate': t.toIso8601String(),
      'lastModifiedDate': t.toIso8601String(),
      'latitude': 1.5, 'longitude': 2.5, 'locationLabel': 'Z',
      'tags': const <String>[],
    };

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    final n = await (db.select(db.notes)..where((x) => x.uuid.equals(uuid)))
        .getSingleOrNull();
    expect(n!.latitude, 1.5);
    expect(n.longitude, 2.5);
    expect(n.locationLabel, 'Z');
  });

  test('inbound update omitting location preserves stored value', () async {
    final local = DateTime.utc(2026, 1, 1);
    final id = await db.into(db.notes).insert(NotesCompanion.insert(
          subject: 'm', authorId: 1, uuid: const Value('n1'),
          createDate: Value(local), lastModifiedDate: Value(local),
          latitude: const Value(9.0), longitude: const Value(8.0),
          locationLabel: const Value('Keep'),
        ));
    final remote = local.add(const Duration(days: 1));
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: remote, deviceId: 'o',
      notes: [ManifestEntry(id: 'n1', updatedAt: remote, deleted: false)],
      attachments: const []);
    provider.remoteBodies['n1'] = {
      'uuid': 'n1', 'subject': 'm2',
      'createDate': local.toIso8601String(),
      'lastModifiedDate': remote.toIso8601String(),
      'tags': const <String>[],
    };

    final r = await orchestrator.syncNow();
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    final n =
        await (db.select(db.notes)..where((x) => x.id.equals(id))).getSingle();
    expect(n.subject, 'm2');
    expect(n.latitude, 9.0, reason: 'omitted location must not be zeroed');
    expect(n.locationLabel, 'Keep');
  });
}

class _FakeProvider implements CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> pushed = {};
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => remoteManifest;
  @override
  Future<void> pushManifest(SyncManifest m) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async =>
      remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async =>
      pushed[id] = body;
  @override
  Future<Map<String, dynamic>?> pullSettings() async => null;
  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {}
  @override
  Future<Map<String, dynamic>?> pullTags() async => null;
  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {}
}
```

- [ ] **Step 2: Run to verify it fails** — Run: `flutter test test/core/data/sync/sync_orchestrator_location_test.dart`
Expected: FAIL — the orchestrator neither serializes nor applies location.

- [ ] **Step 3: Outbound** — in `lib/core/data/sync/sync_orchestrator.dart`, in `_noteRowToBlob`'s `body` map, after the `'noteDate'` key, add:

```dart
        'latitude': n.latitude,
        'longitude': n.longitude,
        'locationLabel': n.locationLabel,
```

- [ ] **Step 4: Inbound parse** — after the `noteDate` parse block (`final noteDate = ...`), add:

```dart
    final hasLocation = body.containsKey('latitude');
    final lat = (body['latitude'] as num?)?.toDouble();
    final lng = (body['longitude'] as num?)?.toDouble();
    final locLabel = body['locationLabel'] as String?;
```

- [ ] **Step 5: Inbound update branch** — in the `existing != null` update `NotesCompanion(...)`, after the `noteDate:` member, add (present ⇒ set, absent ⇒ preserve):

```dart
        latitude: hasLocation ? Value(lat) : const Value.absent(),
        longitude: hasLocation ? Value(lng) : const Value.absent(),
        locationLabel: hasLocation ? Value(locLabel) : const Value.absent(),
```

- [ ] **Step 6: Inbound insert branch** — in the `else` insert `NotesCompanion.insert(...)`, after the `noteDate:` member, add:

```dart
              latitude: Value(lat),
              longitude: Value(lng),
              locationLabel: Value(locLabel),
```

- [ ] **Step 7: Run to verify it passes** — Run: `flutter test test/core/data/sync/sync_orchestrator_location_test.dart`
Expected: PASS (all three).

- [ ] **Step 8: Analyze + sync regression** — Run: `flutter analyze lib/core/data/sync/sync_orchestrator.dart` and `flutter test test/core/data/sync/`
Expected: No issues; all pass.

- [ ] **Step 9: Commit**

```bash
cd /Users/fchy/projects/hmm_console
git add lib/core/data/sync/sync_orchestrator.dart test/core/data/sync/sync_orchestrator_location_test.dart
git commit -m "feat(notes): sync note location through cloudStorage engine"
```

## Task B14: Full client verification

- [ ] **Step 1: Analyze** — Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Full test suite** — Run: `flutter test`
Expected: All pass.

- [ ] **Step 3: Manual smoke (optional, iOS)** — In Settings, turn on "Add location to new notes" (grant the OS prompt). Create a new note → a location card appears with your city/coords → Save → the card shows in the detail view. Tap ✕ in the editor on an existing note with a location → save → location cleared. Toggle off → new notes get no card and no location prompt.

---

## Notes on scope / sequencing

- **Backend ↔ client wiring:** the Flutter `cloudApi` note repo still doesn't exist, so there's no client API mapper to touch; the backend columns are forward-looking, and clearing a location over the API is deferred (the null-preserve `.Condition` can't express "clear"). `local` + `cloudStorage` are fully wired here.
- **`local`/`cloudStorage` independence:** Part B ships without Part A. Part A keeps the serviceAPI schema aligned and is independently deployable.
- **Out of scope:** map view / location picker / editing to a different place; proximity queries; Phase 3 voice/PDF media.
