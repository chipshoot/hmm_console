# Notes Redesign — Slice 1: Data, Flags & Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every note a pin and a coloured flag that survive all three data modes, make delete recoverable (server undelete + client restore with Undo) and finite (real 30-day purge with vault release), make tags sync in cloudApi mode, and stop Notes from deleting entity notes — without any new list UI (that is slice 2+).

**Architecture:** Server first (`hmm`, branch `feat/notes-pin-flag-undelete`): two additive columns on `notes`, DTO fields with "absent keeps" semantics, `?pinned=`/`?flag=` filters, `POST /v1/notes/{id}/restore`, `DELETE /v1/notes/{id}/purge`, and a set-replace `GET|PUT /v1/notes/{id}/tags` backed by a new `INoteTagMembershipRepository` (the existing `applyTag` path cannot persist on EF — see Task 4). Client (`hmm_console`, branch `feat/notes-list-redesign`): Drift v8→v9, `HmmNote`/mapper/inputs, repository `setPinned`/`setFlagColor`/`restoreNote`, OneDrive blob keys, `ApiSyncProvider` wiring (pin/flag, restore, tags, purge), a `NotePurgeService` + `NotePurgeScheduler` that run outside sync through a new `SyncController.runExclusive`, the G7 delete guard, and the note-detail menu (Pin, Flag…, undoable Delete, "Manage in …", Help).

**Tech Stack:** Flutter 3 / Dart 3, Riverpod, Drift (SQLite), Dio + http_mock_adapter, flutter_test; .NET 10, ASP.NET Core, EF Core (PostgreSQL in prod, SQLite in-memory in `Hmm.Core.Dal.EF.Tests`), AutoMapper, Newtonsoft.Json, xUnit v2 + Moq.

**Spec:** docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md

## Global Constraints

- Drift `schemaVersion` 8 → 9, additive only (`m.addColumn`), no backfill, no other table touched.
- `isPinned`: `bool`, default `false` (Drift `is_pinned`, server `ispinned`).
- `flagColor`: `int?`, `null` = unflagged; 0 red, 1 orange, 2 yellow, 3 green, 4 blue, 5 purple, 6 grey; any other int is stored verbatim and shown as grey (`NoteFlagColor.fromStored`).
- Absent key ⇒ keep the stored value: OneDrive blob pull, `ApiSyncProvider` pull, server `PUT` (`IsPinned` null/absent keeps; `FlagColor` absent keeps, explicit `null` clears), and pulled `tags`.
- Entity notes are never deleted from Notes (G7): only `General` (or a legacy row with no catalog) passes `canDeleteFromNotes`.
- Recently Deleted = ordinary notes only (G11) — the list itself is slice 5; slice 1 only makes delete reversible.
- Purge after 30 days applies to ALL soft-deleted notes (G11), runs at most once a day, never while a sync runs (`SyncController.runExclusive`).
- Logs carry ids and error types only (`${e.runtimeType}`), never note content, names or vault paths.
- Icon buttons: `HmmIconButton` only (no raw `IconButton`; `test/core/help/icon_button_guard_test.dart` must stay green).
- Hide/move actions use `showUndoableAction`; permanent deletes keep a confirmation dialog (none in slice 1 UI).
- Every new string in `lib/l10n/app_en.arb` AND `lib/l10n/app_zh.arb` (parity), then `flutter gen-l10n`.
- Platform branching via `Theme.of(context).platform` (iOS/macOS → Cupertino, else Material).
- `flutter analyze` stays at exactly the 2 pre-existing infos (`lib/features/onboarding/presentation/screens/onboarding_screen.dart` prefer_const_constructors_in_immutables, `lib/main.dart` use_null_aware_elements).
- `flutter test` baseline recorded 2026-10-18 on `feat/notes-list-redesign` @126f53a: **2314 passed, 0 failed**. The count may only grow.
- Backend baselines recorded 2026-10-18 on `hmm` main @0734684: `Hmm.Core.Tests` **233 passed**, `Hmm.ServiceApi.Core.Tests` **440 passed**, `Hmm.Core.Dal.EF.Tests` **68 passed**, 0 failed. Counts may only grow.
- Backend work only in `/Users/fchy/Projects/hmm` on branch `feat/notes-pin-flag-undelete` (created from `main` in Task 1); never commit on `main`; never stage `/Users/fchy/Projects/hmm/CLAUDE.md` (unrelated uncommitted change) — always `git add <explicit paths>`.
- The server (Tasks 1–4) is deployed to the VPS before any client release that writes the new fields.
- Every commit message ends with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No `git push`, no merge, no deploy anywhere in this plan.

## Review Focus

1. **Pin on device A, then an edit on an older app on device B must not unpin.** The older app's blob has no `isPinned`/`flagColor` keys; the pull must keep A's values. Owning test: Task 6 `inbound update without pin/flag keys keeps the local pin and flag (older client edit)`.
2. **Restore on a OneDrive device against a tombstone with an equal timestamp.** Drift stores `DateTime` at 1-second resolution, so a restore in the same second as its delete would tie and last-writer-wins would keep the tombstone on peers. `restoreNote` stamps at least the next whole second. Owning tests: Task 5 `restoreStamp` cases and Task 6 `a restore made in the same second as its delete still wins on peers` + `equal timestamps keep the local tombstone (documented tie)`.
3. **Purge never deletes a note that was restored seconds earlier.** Every purge write is guarded by `deletedAt = <value read>`; the server purge refuses a live note (409 → `NoteLiveOnServerException`); OneDrive blob deletion is deferred into the next sync and skipped when the pull revived the note. Owning tests: Task 8 `a restore that lands during the purge wins`, `keeps the row when the server says the note is live`, `a note restored on another device is revived, never purged remotely`.
4. **An entity note reached via the detail screen cannot be deleted generically.** `MutateNote.delete` refuses (throws `EntityNoteDeleteRefused`) and the menu shows "Manage in …" instead of Delete. Owning tests: Task 10 `delete refuses an entity note and leaves it live`, Task 11 `an entity note shows Manage in Automobile instead of Delete`.
5. **A server still running the old build (no `IsPinned`) must not make the client drop pins.** The old `ApiNote` has no `isPinned`/`flagColor`/`tagNames` keys; the provider must omit them from the pulled body so the orchestrator keeps local values. Owning tests: Task 7 `an old server (no pin/flag/tag keys) yields a body without those keys` + Task 6 absent-key tests.

---

### Task 1: Server — `IsPinned` / `FlagColor` columns, DTOs and "absent keeps" mapping

**Files:**
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/DomainEntity/HmmNote.cs` (after `LocationLabel`, ~line 41)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs` (after `LocationLabel`, ~line 62)
- Create: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Migrations/20261018000000_AddNotePinAndFlagColumns.cs`
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs` (HmmNoteDao entity, ~lines 177–186)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`, `ApiNoteForCreate.cs`, `ApiNoteForUpdate.cs`
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs` (`ApiNoteForUpdate → HmmNote` map, ~lines 81–91)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Utility.TestHelp/SampleDataGenerator.cs` (`Clone`, ~lines 467–516)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/ApiNotePinFlagMappingTests.cs` (create)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.Core.Tests/HmmNoteManagerPinFlagTests.cs` (create)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF.Tests/NoteRepositoryPinFlagTests.cs` (create)

**Interfaces:**
- Consumes: `CoreTestFixtureBase.ApiMapper`/`Mapper`/`NoteRepository`/`GetTestAuthor()`/`GetTestCatalog()`, `DbTestFixtureBase`.
- Produces (C#):
  - `HmmNote.IsPinned : bool`, `HmmNote.FlagColor : int?`; `HmmNoteDao.IsPinned : bool` (`ispinned`), `HmmNoteDao.FlagColor : int?` (`flagcolor`)
  - `ApiNote.IsPinned : bool`, `ApiNote.FlagColor : int?`; `ApiNoteForCreate.IsPinned : bool`, `ApiNoteForCreate.FlagColor : int?`
  - `ApiNoteForUpdate.IsPinned : bool?` (null ⇒ keep), `ApiNoteForUpdate.FlagColor : int?` + `ApiNoteForUpdate.FlagColorSpecified : bool` (absent ⇒ keep, explicit null ⇒ clear)
  - Wire JSON (camelCase): `"isPinned"`, `"flagColor"`.

- [ ] **Step 1: Create the server branch and confirm baselines**

```bash
cd /Users/fchy/Projects/hmm
git status --short            # expect exactly: " M CLAUDE.md"
git switch main
git switch -c feat/notes-pin-flag-undelete
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1               # Passed: 233
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1    # Passed: 440
dotnet test src/Hmm.Core.Dal.EF.Tests 2>&1 | tail -1        # Passed: 68
```

- [ ] **Step 2: Write the failing mapping tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/ApiNotePinFlagMappingTests.cs`:

```csharp
using Hmm.Core.Map.DomainEntity;
using Hmm.ServiceApi.DtoEntity.HmmNote;
using Hmm.Utility.TestHelp;
using Newtonsoft.Json;
using Xunit;

namespace Hmm.ServiceApi.Core.Tests;

/// <summary>
/// Notes redesign slice 1: pin + flag ride the note DTOs. PUT maps the DTO
/// onto the loaded note, so presence matters: a client that predates pins
/// sends no key and must not unpin/unflag (absent keeps), while
/// "flagColor": null is a deliberate clear. JSON is the camelCase wire shape.
/// </summary>
public class ApiNotePinFlagMappingTests : CoreTestFixtureBase
{
    private static HmmNote Stored() => new()
    {
        Id = 1, Subject = "s", Content = "{}",
        Author = new Author { Id = 1 }, Catalog = new NoteCatalog { Id = 1 },
        IsPinned = true, FlagColor = 3,
    };

    private static ApiNoteForUpdate Wire(string json) =>
        JsonConvert.DeserializeObject<ApiNoteForUpdate>(json)!;

    [Fact]
    public void Put_omitting_pin_and_flag_keeps_the_stored_values()
    {
        var note = Stored();
        var dto = Wire("{\"subject\":\"s2\"}");

        Assert.Null(dto.IsPinned);
        Assert.False(dto.FlagColorSpecified);
        ApiMapper.Map(dto, note);

        Assert.Equal("s2", note.Subject);
        Assert.True(note.IsPinned);
        Assert.Equal(3, note.FlagColor);
    }

    [Fact]
    public void Put_with_an_explicit_null_flag_clears_it_and_keeps_the_pin()
    {
        var note = Stored();
        var dto = Wire("{\"subject\":\"s2\",\"flagColor\":null}");

        Assert.True(dto.FlagColorSpecified);
        ApiMapper.Map(dto, note);

        Assert.Null(note.FlagColor);
        Assert.True(note.IsPinned);
    }

    [Fact]
    public void Put_with_values_overwrites_both()
    {
        var note = Stored();
        var dto = Wire("{\"subject\":\"s2\",\"isPinned\":false,\"flagColor\":5}");

        ApiMapper.Map(dto, note);

        Assert.False(note.IsPinned);
        Assert.Equal(5, note.FlagColor);
    }

    [Fact]
    public void Put_keeps_an_unknown_flag_value_verbatim()
    {
        // A newer client may use colours this server has never heard of.
        var note = Stored();
        ApiMapper.Map(Wire("{\"subject\":\"s2\",\"flagColor\":42}"), note);

        Assert.Equal(42, note.FlagColor);
    }

    [Fact]
    public void Create_maps_pin_and_flag()
    {
        var dto = new ApiNoteForCreate
        {
            Subject = "s", AuthorId = 1, CatalogId = 1, IsPinned = true, FlagColor = 0,
        };

        var note = ApiMapper.Map<ApiNoteForCreate, HmmNote>(dto);

        Assert.True(note.IsPinned);
        Assert.Equal(0, note.FlagColor);
    }

    [Fact]
    public void ApiNote_exposes_pin_and_flag()
    {
        var api = ApiMapper.Map<ApiNote>(Stored());

        Assert.True(api.IsPinned);
        Assert.Equal(3, api.FlagColor);
    }

    [Fact]
    public void Patch_round_trip_keeps_the_flag()
    {
        // PATCH maps the stored note to ApiNoteForUpdate, applies the patch,
        // then maps back: the flag must survive the round trip untouched.
        var dto = ApiMapper.Map<ApiNoteForUpdate>(Stored());
        Assert.True(dto.FlagColorSpecified);

        var target = Stored();
        target.FlagColor = null;
        target.IsPinned = false;
        ApiMapper.Map(dto, target);

        Assert.Equal(3, target.FlagColor);
        Assert.True(target.IsPinned);
    }
}
```

- [ ] **Step 3: Write the failing manager and EF tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Tests/HmmNoteManagerPinFlagTests.cs`:

```csharp
using Hmm.Core.DefaultManager;
using Hmm.Core.Map.DomainEntity;
using Hmm.Utility.Misc;
using Hmm.Utility.TestHelp;
using Hmm.Utility.Validation;
using Moq;
using System.Threading.Tasks;
using Xunit;

namespace Hmm.Core.Tests
{
    public class HmmNoteManagerPinFlagTests : CoreTestFixtureBase, IAsyncLifetime
    {
        private readonly HmmNoteManager _noteManager;
        private Author _author;
        private NoteCatalog _catalog;

        public HmmNoteManagerPinFlagTests()
        {
            var mockValidator = new Mock<IHmmValidator<HmmNote>>();
            mockValidator.Setup(v => v.ValidateEntityAsync(It.IsAny<HmmNote>()))
                .ReturnsAsync((HmmNote note) => ProcessingResult<HmmNote>.Ok(note));
            _noteManager = new HmmNoteManager(NoteRepository, UnitOfWork, Mapper, LookupRepository, DateProvider, mockValidator.Object);
        }

        [Fact]
        public async Task New_notes_default_to_unpinned_and_unflagged()
        {
            var created = await _noteManager.CreateAsync(new HmmNote
            {
                Author = _author, Catalog = _catalog, Subject = "plain", Content = "c",
            });

            var loaded = await _noteManager.GetNoteByIdAsync(created.Value.Id);
            Assert.False(loaded.Value.IsPinned);
            Assert.Null(loaded.Value.FlagColor);
        }

        [Fact]
        public async Task Create_and_update_persist_pin_and_flag()
        {
            var created = await _noteManager.CreateAsync(new HmmNote
            {
                Author = _author, Catalog = _catalog, Subject = "pin me", Content = "c",
                IsPinned = true, FlagColor = 4,
            });
            Assert.True(created.Success);

            var loaded = await _noteManager.GetNoteByIdAsync(created.Value.Id);
            Assert.True(loaded.Value.IsPinned);
            Assert.Equal(4, loaded.Value.FlagColor);

            loaded.Value.IsPinned = false;
            loaded.Value.FlagColor = null;
            var updated = await _noteManager.UpdateAsync(loaded.Value);
            Assert.True(updated.Success);

            var reloaded = await _noteManager.GetNoteByIdAsync(created.Value.Id);
            Assert.False(reloaded.Value.IsPinned);
            Assert.Null(reloaded.Value.FlagColor);
        }

        public async Task InitializeAsync()
        {
            _author = await GetTestAuthor();
            _catalog = await GetTestCatalog();
        }

        public Task DisposeAsync() => Task.CompletedTask;
    }
}
```

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF.Tests/NoteRepositoryPinFlagTests.cs`:

```csharp
using Hmm.Core.Map.DbEntity;
using Hmm.Utility.TestHelp;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using Xunit;

namespace Hmm.Core.Dal.EF.Tests
{
    public class NoteRepositoryPinFlagTests : DbTestFixtureBase, IAsyncLifetime
    {
        private AuthorDao _author;
        private NoteCatalogDao _catalog;

        [Fact]
        public async Task New_note_defaults_to_unpinned_and_unflagged()
        {
            var note = new HmmNoteDao { Author = _author, Catalog = _catalog, Subject = "plain", Content = "c" };
            await NoteRepository.AddAsync(note);
            await DbContext.CommitAsync();
            ((DbContext)DbContext).ChangeTracker.Clear();

            var loaded = (await NoteRepository.GetEntityAsync(note.Id)).Value;
            Assert.False(loaded.IsPinned);
            Assert.Null(loaded.FlagColor);
        }

        [Fact]
        public async Task Pin_and_flag_round_trip_through_the_database()
        {
            var note = new HmmNoteDao
            {
                Author = _author, Catalog = _catalog, Subject = "flagged", Content = "c",
                IsPinned = true, FlagColor = 6,
            };
            await NoteRepository.AddAsync(note);
            await DbContext.CommitAsync();
            ((DbContext)DbContext).ChangeTracker.Clear();

            var loaded = (await NoteRepository.GetEntityAsync(note.Id)).Value;
            Assert.True(loaded.IsPinned);
            Assert.Equal(6, loaded.FlagColor);
        }

        public async Task InitializeAsync()
        {
            Transaction = await ((DbContext)DbContext).Database.BeginTransactionAsync();
            var catalog = new NoteCatalogDao
            {
                Name = "pinflag-dal-test-catalog", Schema = "", FormatType = NoteContentFormatType.PlainText,
                IsDefault = true, Description = "pin/flag test catalog",
            };
            _catalog = (await CatalogRepository.AddAsync(catalog)).Value;
            var contact = (await ContactRepository.AddAsync(new ContactDao
            {
                Contact = "{ \"FirstName\": \"Pin\", \"LastName\": \"Flag\" }", Description = "pin/flag contact", IsActivated = true,
            })).Value;
            _author = (await AuthorRepository.AddAsync(new AuthorDao
            {
                AccountName = "pinflag-dal-test", ContactInfo = contact, Description = "pin/flag author", IsActivated = true,
            })).Value;
            await DbContext.CommitAsync();
        }

        public async Task DisposeAsync()
        {
            await Transaction.RollbackAsync();
            await Transaction.DisposeAsync();
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they fail**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~ApiNotePinFlagMappingTests" 2>&1 | tail -5
```
Expected: build FAILS with `error CS0117: 'HmmNote' does not contain a definition for 'IsPinned'` (and the same for `FlagColor`, `FlagColorSpecified`).

- [ ] **Step 5: Add the domain and DAO fields**

In `HmmNote.cs`, after `public string? LocationLabel { get; set; }` add:

```csharp

        /// <summary>
        /// Pinned notes list first (Notes redesign slice 1). Default false.
        /// </summary>
        public bool IsPinned { get; set; }

        /// <summary>
        /// Coloured flag: null = unflagged; 0 red, 1 orange, 2 yellow,
        /// 3 green, 4 blue, 5 purple, 6 grey. Any other value (written by a
        /// newer client) is stored verbatim; clients show it as grey.
        /// </summary>
        public int? FlagColor { get; set; }
```

In `HmmNoteDao.cs`, after the `LocationLabel` property add:

```csharp

        [Column("ispinned")]
        public bool IsPinned { get; set; }

        [Column("flagcolor")]
        public int? FlagColor { get; set; }
```

- [ ] **Step 6: Add the hand-written migration and update the snapshot**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Migrations/20261018000000_AddNotePinAndFlagColumns.cs`:

```csharp
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Hmm.Core.Dal.EF.Migrations
{
    [DbContext(typeof(HmmDataContext))]
    [Migration("20261018000000_AddNotePinAndFlagColumns")]
    /// <inheritdoc />
    public partial class AddNotePinAndFlagColumns : Migration
    {
        // Hand-written for the same cross-provider drift reason as the
        // earlier migrations. Notes redesign slice 1: pin (default false,
        // so every existing note stays unpinned) and a nullable flag colour
        // (null = unflagged). No backfill.

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "ispinned", table: "notes",
                type: "boolean", nullable: false, defaultValue: false);
            migrationBuilder.AddColumn<int>(
                name: "flagcolor", table: "notes",
                type: "integer", nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "ispinned", table: "notes");
            migrationBuilder.DropColumn(name: "flagcolor", table: "notes");
        }
    }
}
```

In `HmmDataContextModelSnapshot.cs`, inside `modelBuilder.Entity("Hmm.Core.Map.DbEntity.HmmNoteDao", b => {` (the first one, ~line 151), insert after the `Description` property block:

```csharp

                    b.Property<int?>("FlagColor")
                        .HasColumnType("integer")
                        .HasColumnName("flagcolor");
```

and after the `IsDeleted` property block:

```csharp

                    b.Property<bool>("IsPinned")
                        .HasColumnType("boolean")
                        .HasColumnName("ispinned");
```

(Startup logs `PendingModelChangesWarning` rather than failing — `Startup.cs` ~line 183 — but keep the snapshot exact anyway.)

- [ ] **Step 7: Add the DTO fields**

In `ApiNote.cs`, after `public string? LocationLabel { get; set; }` add:

```csharp

        /// <summary>Pinned notes list first.</summary>
        public bool IsPinned { get; set; }

        /// <summary>
        /// null = unflagged; 0 red … 6 grey. Unknown values are returned
        /// verbatim (a newer client wrote them).
        /// </summary>
        public int? FlagColor { get; set; }
```

In `ApiNoteForCreate.cs`, after `public string? LocationLabel { get; set; }` add:

```csharp

        public bool IsPinned { get; set; }

        public int? FlagColor { get; set; }
```

In `ApiNoteForUpdate.cs`, add `using Newtonsoft.Json;` to the usings and, after `public string? LocationLabel { get; set; }`, add:

```csharp

        /// <summary>
        /// Replacement pin. Null (or an absent key) ⇒ keep the stored value,
        /// so a client that predates pins never unpins a note.
        /// </summary>
        public bool? IsPinned { get; set; }

        private int? _flagColor;

        /// <summary>
        /// Replacement flag. This DTO is mapped ONTO the stored note, so
        /// presence matters: an absent key keeps the stored flag
        /// (<see cref="FlagColorSpecified"/> stays false) while
        /// "flagColor": null clears it. Newtonsoft calls this setter only for
        /// a key that is present — null included. Same pattern as
        /// <c>ApiCheatsheetForUpdate.Style</c>.
        /// </summary>
        public int? FlagColor
        {
            get => _flagColor;
            set
            {
                _flagColor = value;
                FlagColorSpecified = true;
            }
        }

        /// <summary>True when the request body carried a "flagColor" key at all.</summary>
        [JsonIgnore]
        public bool FlagColorSpecified { get; private set; }
```

- [ ] **Step 8: Map "absent keeps" in the API profile**

In `ApiMappingProfile.cs`, replace the `CreateMap<ApiNoteForUpdate, Core.Map.DomainEntity.HmmNote>()` chain's last line

```csharp
                .ForMember(d => d.LocationLabel,
                    opt => opt.Condition(s => s.LocationLabel != null));
```

with

```csharp
                .ForMember(d => d.LocationLabel,
                    opt => opt.Condition(s => s.LocationLabel != null))
                // Notes redesign slice 1: an omitted pin keeps the stored
                // value; an omitted flag keeps it, an explicit null clears it.
                .ForMember(d => d.IsPinned, opt =>
                {
                    opt.Condition(s => s.IsPinned.HasValue);
                    opt.MapFrom(s => s.IsPinned.GetValueOrDefault());
                })
                .ForMember(d => d.FlagColor,
                    opt => opt.Condition(s => s.FlagColorSpecified));
```

- [ ] **Step 9: Teach the test fixture's clone the new columns**

In `SampleDataGenerator.cs` `Clone`, in the `targetNote == null` branch add after `IsDeleted = source.IsDeleted,`:

```csharp
                IsPinned = source.IsPinned,
                FlagColor = source.FlagColor,
```

and in the `else` branch add after `targetNote.IsDeleted = source.IsDeleted;`:

```csharp
            targetNote.IsPinned = source.IsPinned;
            targetNote.FlagColor = source.FlagColor;
```

- [ ] **Step 10: Run the new tests and the full suites**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~ApiNotePinFlagMappingTests" 2>&1 | tail -1   # Passed: 7
dotnet test src/Hmm.Core.Tests --filter "FullyQualifiedName~HmmNoteManagerPinFlagTests" 2>&1 | tail -1           # Passed: 2
dotnet test src/Hmm.Core.Dal.EF.Tests --filter "FullyQualifiedName~NoteRepositoryPinFlagTests" 2>&1 | tail -1     # Passed: 2
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1             # Passed: 235
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1  # Passed: 447
dotnet test src/Hmm.Core.Dal.EF.Tests 2>&1 | tail -1      # Passed: 70
```

- [ ] **Step 11: Commit**

```bash
cd /Users/fchy/Projects/hmm
git add src/Hmm.Core.Map/DomainEntity/HmmNote.cs src/Hmm.Core.Map/DbEntity/HmmNoteDao.cs \
  src/Hmm.Core.Dal.EF/Migrations/20261018000000_AddNotePinAndFlagColumns.cs \
  src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs \
  src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForCreate.cs \
  src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteForUpdate.cs src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs \
  src/Hmm.Utility.TestHelp/SampleDataGenerator.cs \
  src/Hmm.ServiceApi.Core.Tests/ApiNotePinFlagMappingTests.cs src/Hmm.Core.Tests/HmmNoteManagerPinFlagTests.cs \
  src/Hmm.Core.Dal.EF.Tests/NoteRepositoryPinFlagTests.cs
git status --short   # CLAUDE.md must still show " M" (unstaged)
git commit -m "$(cat <<'MSG'
feat(notes): IsPinned + FlagColor columns with absent-keeps PUT semantics

Additive migration (ispinned default false, flagcolor nullable). PUT that
omits isPinned/flagColor keeps the stored value; explicit flagColor null
clears it (FlagColorSpecified, same pattern as cheatsheet Style).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 2: Server — `?pinned=` and `?flag=` list filters

**Files:**
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs` (`Get` collection action, lines 54–79; usings lines 1–17)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerPinFlagFilterTests.cs` (create)

**Interfaces:**
- Consumes: `IHmmNoteManager.GetNotesAsync(Expression<Func<HmmNote,bool>> query, bool includeDeleted, ResourceCollectionParameters)`, `PredicateBuilder.And` (`Hmm.Utility.Misc`).
- Produces: `public async Task<IActionResult> Get([FromQuery] ResourceCollectionParameters resourceCollectionParameters, [FromQuery] bool includeDeleted = false, [FromQuery] bool? pinned = null, [FromQuery] int? flag = null)` — `GET /v1/notes?pinned=true|false&flag=<int>` (exact colour); both optional, combinable, AND-ed with the existing soft-delete filter.

- [ ] **Step 1: Write the failing tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerPinFlagFilterTests.cs`:

```csharp
using Hmm.Core.DefaultManager;
using Hmm.Core.Map.DomainEntity;
using Hmm.ServiceApi.Areas.HmmNoteService.Controllers;
using Hmm.Utility.Dal.Query;
using Hmm.Utility.Misc;
using Hmm.Utility.TestHelp;
using Hmm.Utility.Validation;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;

namespace Hmm.ServiceApi.Core.Tests
{
    public class NoteControllerPinFlagFilterTests : CoreTestFixtureBase
    {
        private readonly HmmNoteManager _noteManager;
        private readonly HmmNoteController _controller;

        public NoteControllerPinFlagFilterTests()
        {
            var validator = new Mock<IHmmValidator<HmmNote>>();
            validator.Setup(v => v.ValidateEntityAsync(It.IsAny<HmmNote>()))
                .ReturnsAsync((HmmNote n) => ProcessingResult<HmmNote>.Ok(n));
            var tagValidator = new Mock<IHmmValidator<Tag>>();
            tagValidator.Setup(v => v.ValidateEntityAsync(It.IsAny<Tag>()))
                .ReturnsAsync((Tag t) => ProcessingResult<Tag>.Ok(t));
            _noteManager = new HmmNoteManager(NoteRepository, UnitOfWork, Mapper, LookupRepository, DateProvider, validator.Object);
            var tagManager = new TagManager(TagRepository, UnitOfWork, Mapper, LookupRepository, tagValidator.Object);
            _controller = new HmmNoteController(_noteManager, new NoteTagAssociationManager(_noteManager, tagManager),
                ApiMapper, new Mock<ILogger<HmmNoteController>>().Object)
            {
                ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
            };
            ConfigureControllerForValidation(_controller);
        }

        private async Task CreateNoteAsync(string subject, bool isPinned, int? flag)
        {
            var result = await _noteManager.CreateAsync(new HmmNote
            {
                Author = await GetTestAuthor(), Catalog = await GetTestCatalog(),
                Subject = subject, Content = "c", IsPinned = isPinned, FlagColor = flag,
            });
            Assert.True(result.Success);
        }

        private static List<HmmNote> Notes(IActionResult result)
        {
            var ok = Assert.IsType<OkObjectResult>(result);
            return Assert.IsType<PageList<HmmNote>>(ok.Value).ToList();
        }

        [Fact]
        public async Task Get_with_pinned_true_returns_only_pinned_notes()
        {
            await CreateNoteAsync("pinned one", isPinned: true, flag: null);
            await CreateNoteAsync("flagged red", isPinned: false, flag: 0);

            var notes = Notes(await _controller.Get(new ResourceCollectionParameters(), pinned: true));

            Assert.Equal(new[] { "pinned one" }, notes.Select(n => n.Subject));
        }

        [Fact]
        public async Task Get_with_pinned_false_excludes_pinned_notes()
        {
            await CreateNoteAsync("pinned one", isPinned: true, flag: null);
            await CreateNoteAsync("flagged red", isPinned: false, flag: 0);

            var notes = Notes(await _controller.Get(new ResourceCollectionParameters(), pinned: false));

            Assert.DoesNotContain(notes, n => n.IsPinned);
            Assert.Contains(notes, n => n.Subject == "flagged red");
            Assert.Equal(6, notes.Count); // 5 seeded + "flagged red"
        }

        [Fact]
        public async Task Get_with_flag_returns_that_colour_only()
        {
            await CreateNoteAsync("red", isPinned: false, flag: 0);
            await CreateNoteAsync("blue", isPinned: false, flag: 4);

            var notes = Notes(await _controller.Get(new ResourceCollectionParameters(), flag: 4));

            Assert.Equal(new[] { "blue" }, notes.Select(n => n.Subject));
        }

        [Fact]
        public async Task Get_combines_pinned_and_flag()
        {
            await CreateNoteAsync("pinned blue", isPinned: true, flag: 4);
            await CreateNoteAsync("blue", isPinned: false, flag: 4);
            await CreateNoteAsync("pinned", isPinned: true, flag: null);

            var notes = Notes(await _controller.Get(new ResourceCollectionParameters(), pinned: true, flag: 4));

            Assert.Equal(new[] { "pinned blue" }, notes.Select(n => n.Subject));
        }

        [Fact]
        public async Task Get_without_filters_is_unchanged()
        {
            await CreateNoteAsync("pinned", isPinned: true, flag: 2);

            var notes = Notes(await _controller.Get(new ResourceCollectionParameters()));

            Assert.Equal(6, notes.Count);
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~NoteControllerPinFlagFilterTests" 2>&1 | tail -5
```
Expected: build FAILS with `error CS1739: The best overload for 'Get' does not have a parameter named 'pinned'`.

- [ ] **Step 3: Implement the filters**

In `HmmNoteController.cs` add `using System.Linq.Expressions;` to the usings, then replace the collection `Get` action (lines 60–79) with:

```csharp
        public async Task<IActionResult> Get(
            [FromQuery] ResourceCollectionParameters resourceCollectionParameters,
            [FromQuery] bool includeDeleted = false,
            [FromQuery] bool? pinned = null,
            [FromQuery] int? flag = null)
        {
            // includeDeleted lets the cloudApi sync provider see
            // tombstones so they can be propagated to other devices.
            // Normal callers leave the default — soft-deleted notes
            // stay hidden.
            //
            // pinned / flag (Notes redesign slice 1): optional, AND-ed.
            // flag is an exact colour (0 red … 6 grey, or any stored int).
            Expression<Func<HmmNote, bool>> query = null;
            if (pinned.HasValue)
            {
                var wantPinned = pinned.Value;
                query = n => n.IsPinned == wantPinned;
            }
            if (flag.HasValue)
            {
                var wantFlag = flag.Value;
                Expression<Func<HmmNote, bool>> byFlag = n => n.FlagColor == wantFlag;
                query = query == null ? byFlag : query.And(byFlag);
            }

            var noteListResult = await _noteManager.GetNotesAsync(query, includeDeleted, resourceCollectionParameters);
            if (!noteListResult.Success)
            {
                _logger.LogError("Failed to retrieve notes. Error: {ErrorMessage}, TraceId: {TraceId}",
                    noteListResult.ErrorMessage, HttpContext.TraceIdentifier);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ProblemDetailsHelper.InternalServerError("An error occurred while retrieving notes.", HttpContext));
            }

            // Return 200 OK with empty array when no results (REST best practice)
            return Ok(noteListResult.Value ?? new PageList<HmmNote>());
        }
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~NoteControllerPinFlagFilterTests" 2>&1 | tail -1   # Passed: 5
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1   # Passed: 452
```

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/Projects/hmm
git add src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs \
  src/Hmm.ServiceApi.Core.Tests/NoteControllerPinFlagFilterTests.cs
git commit -m "$(cat <<'MSG'
feat(notes): ?pinned= and ?flag= filters on GET /v1/notes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 3: Server — undelete (`POST /v1/notes/{id}/restore`) and purge (`DELETE /v1/notes/{id}/purge`)

Why `/purge` and not `?permanent=true`: an old server ignores an unknown query parameter and would silently *soft*-delete, so a client would hard-delete locally believing the row is gone. A distinct route 404s on an old server instead.

**Files:**
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core/IHmmNoteManager.cs` (after `DeleteAsync`, line 48)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core/DefaultManager/HmmNoteManager.cs` (after `DeleteAsync`, line 243)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs` (usings; `Put` lines 211–222; `Delete` lines 378–389; new actions + helper before the closing brace of the class, line 415)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Utility.TestHelp/CoreTestFixtureBase.cs` (`GetNoteRepository`, add a `DeleteAsync` setup before `return mockNotes.Object;`, ~line 615)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.Core.Tests/HmmNoteManagerRestorePurgeTests.cs` (create)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerRestorePurgeTests.cs` (create)

**Interfaces:**
- Consumes: `ICurrentUserAuthorProvider.GetCurrentUserAuthorAsync()`, `IVaultBlobStore.ListAsync/DeleteAsync(int authorId, string path, CancellationToken)`, `IVersionRepository<HmmNoteDao>.DeleteAsync(HmmNoteDao)`.
- Produces (C#):
  - `Task<ProcessingResult<HmmNote>> IHmmNoteManager.RestoreAsync(int noteId)` — clears `IsDeleted`; idempotent for a live note; NotFound passes through.
  - `Task<ProcessingResult<Unit>> IHmmNoteManager.PurgeAsync(int noteId)` — removes a soft-deleted row (tag refs cascade); `Conflict` for a live note; `NotFound` for a missing one.
  - `POST /v1/notes/{id}/restore` → 200 `ApiNote` | 401 | 404 (missing or another author's).
  - `DELETE /v1/notes/{id}/purge` → 204 | 401 | 404 | 409 (live note). Best-effort removes `attachments/note-{id}/*` from the owner's vault.
  - `PUT /v1/notes/{id}` on a soft-deleted note → 409 (was 500). `DELETE /v1/notes/{id}` on an already-deleted note → 204 (was 500).
  - private `Task<(IActionResult Error, int AuthorId)> ResolveOwnerAsync(int id, ICurrentUserAuthorProvider authorProvider)` in `HmmNoteController` (reused by Task 4).

- [ ] **Step 1: Write the failing manager tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Tests/HmmNoteManagerRestorePurgeTests.cs`:

```csharp
using Hmm.Core.DefaultManager;
using Hmm.Core.Map.DomainEntity;
using Hmm.Utility.Misc;
using Hmm.Utility.TestHelp;
using Hmm.Utility.Validation;
using Moq;
using System.Threading.Tasks;
using Xunit;

namespace Hmm.Core.Tests
{
    public class HmmNoteManagerRestorePurgeTests : CoreTestFixtureBase, IAsyncLifetime
    {
        private readonly HmmNoteManager _noteManager;
        private Author _author;
        private NoteCatalog _catalog;

        public HmmNoteManagerRestorePurgeTests()
        {
            var mockValidator = new Mock<IHmmValidator<HmmNote>>();
            mockValidator.Setup(v => v.ValidateEntityAsync(It.IsAny<HmmNote>()))
                .ReturnsAsync((HmmNote note) => ProcessingResult<HmmNote>.Ok(note));
            _noteManager = new HmmNoteManager(NoteRepository, UnitOfWork, Mapper, LookupRepository, DateProvider, mockValidator.Object);
        }

        private async Task<int> CreateAsync(bool deleted)
        {
            var created = await _noteManager.CreateAsync(new HmmNote
            {
                Author = _author, Catalog = _catalog, Subject = "restore me", Content = "c",
            });
            if (deleted) Assert.True(await _noteManager.DeleteAsync(created.Value.Id));
            return created.Value.Id;
        }

        [Fact]
        public async Task Restore_clears_IsDeleted()
        {
            var id = await CreateAsync(deleted: true);

            var result = await _noteManager.RestoreAsync(id);

            Assert.True(result.Success);
            Assert.False(result.Value.IsDeleted);
            Assert.True((await _noteManager.GetNoteByIdAsync(id)).Success);
        }

        [Fact]
        public async Task Restore_of_a_live_note_is_idempotent()
        {
            var id = await CreateAsync(deleted: false);

            var result = await _noteManager.RestoreAsync(id);

            Assert.True(result.Success);
            Assert.False(result.Value.IsDeleted);
        }

        [Fact]
        public async Task Restore_of_a_missing_note_is_NotFound()
        {
            var result = await _noteManager.RestoreAsync(9999);

            Assert.False(result.Success);
            Assert.True(result.IsNotFound);
        }

        [Fact]
        public async Task Purge_removes_a_soft_deleted_note()
        {
            var id = await CreateAsync(deleted: true);

            var result = await _noteManager.PurgeAsync(id);

            Assert.True(result.Success);
            Assert.True((await _noteManager.GetNoteByIdAsync(id, true)).IsNotFound);
        }

        [Fact]
        public async Task Purge_refuses_a_live_note_with_Conflict()
        {
            var id = await CreateAsync(deleted: false);

            var result = await _noteManager.PurgeAsync(id);

            Assert.False(result.Success);
            Assert.Equal(ErrorCategory.Conflict, result.ErrorType);
            Assert.True((await _noteManager.GetNoteByIdAsync(id)).Success);
        }

        [Fact]
        public async Task Purge_of_a_missing_note_is_NotFound()
        {
            var result = await _noteManager.PurgeAsync(9999);

            Assert.True(result.IsNotFound);
        }

        public async Task InitializeAsync()
        {
            _author = await GetTestAuthor();
            _catalog = await GetTestCatalog();
        }

        public Task DisposeAsync() => Task.CompletedTask;
    }
}
```

- [ ] **Step 2: Write the failing controller tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerRestorePurgeTests.cs`:

```csharp
using Hmm.Core;
using Hmm.Core.DefaultManager;
using Hmm.Core.Map.DomainEntity;
using Hmm.Core.Vault;
using Hmm.ServiceApi.Areas.HmmNoteService.Controllers;
using Hmm.ServiceApi.DtoEntity.HmmNote;
using Hmm.Utility.Misc;
using Hmm.Utility.TestHelp;
using Hmm.Utility.Validation;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;

namespace Hmm.ServiceApi.Core.Tests
{
    public class NoteControllerRestorePurgeTests : CoreTestFixtureBase
    {
        private readonly HmmNoteManager _noteManager;
        private readonly HmmNoteController _controller;
        private readonly Mock<ICurrentUserAuthorProvider> _authors = new();
        private readonly Mock<IVaultBlobStore> _vault = new();
        private Author _owner;

        public NoteControllerRestorePurgeTests()
        {
            var validator = new Mock<IHmmValidator<HmmNote>>();
            validator.Setup(v => v.ValidateEntityAsync(It.IsAny<HmmNote>()))
                .ReturnsAsync((HmmNote n) => ProcessingResult<HmmNote>.Ok(n));
            var tagValidator = new Mock<IHmmValidator<Tag>>();
            tagValidator.Setup(v => v.ValidateEntityAsync(It.IsAny<Tag>()))
                .ReturnsAsync((Tag t) => ProcessingResult<Tag>.Ok(t));
            _noteManager = new HmmNoteManager(NoteRepository, UnitOfWork, Mapper, LookupRepository, DateProvider, validator.Object);
            var tagManager = new TagManager(TagRepository, UnitOfWork, Mapper, LookupRepository, tagValidator.Object);
            _controller = new HmmNoteController(_noteManager, new NoteTagAssociationManager(_noteManager, tagManager),
                ApiMapper, new Mock<ILogger<HmmNoteController>>().Object)
            {
                ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
            };
            ConfigureControllerForValidation(_controller);
        }

        private async Task<HmmNote> CreateNoteAsync(bool deleted)
        {
            _owner = await GetTestAuthor();
            var created = await _noteManager.CreateAsync(new HmmNote
            {
                Author = _owner, Catalog = await GetTestCatalog(), Subject = "recently deleted", Content = "c",
            });
            if (deleted) Assert.True(await _noteManager.DeleteAsync(created.Value.Id));
            SignInAs(_owner);
            return created.Value;
        }

        private void SignInAs(Author author) =>
            _authors.Setup(a => a.GetCurrentUserAuthorAsync()).ReturnsAsync(ProcessingResult<Author>.Ok(author));

        [Fact]
        public async Task Restore_returns_the_live_note()
        {
            var note = await CreateNoteAsync(deleted: true);

            var result = await _controller.Restore(note.Id, _authors.Object);

            var ok = Assert.IsType<OkObjectResult>(result);
            Assert.False(Assert.IsType<HmmNote>(ok.Value).IsDeleted);
            Assert.True((await _noteManager.GetNoteByIdAsync(note.Id)).Success);
        }

        [Fact]
        public async Task Restore_by_another_author_is_NotFound_and_keeps_it_deleted()
        {
            var note = await CreateNoteAsync(deleted: true);
            SignInAs(new Author { Id = 999, AccountName = "intruder" });

            var result = await _controller.Restore(note.Id, _authors.Object);

            Assert.IsType<NotFoundObjectResult>(result);
            Assert.True((await _noteManager.GetNoteByIdAsync(note.Id, true)).Value.IsDeleted);
        }

        [Fact]
        public async Task Restore_of_an_unknown_note_is_NotFound()
        {
            SignInAs(await GetTestAuthor());

            var result = await _controller.Restore(9999, _authors.Object);

            Assert.IsType<NotFoundObjectResult>(result);
        }

        [Fact]
        public async Task Restore_without_a_signed_in_author_is_Unauthorized()
        {
            var note = await CreateNoteAsync(deleted: true);
            _authors.Setup(a => a.GetCurrentUserAuthorAsync())
                .ReturnsAsync(ProcessingResult<Author>.Fail("no user", ErrorCategory.Unauthorized));

            var result = await _controller.Restore(note.Id, _authors.Object);

            Assert.IsType<UnauthorizedResult>(result);
        }

        [Fact]
        public async Task Purge_removes_the_row_and_its_vault_files()
        {
            var note = await CreateNoteAsync(deleted: true);
            var prefix = $"attachments/note-{note.Id}";
            _vault.Setup(v => v.ListAsync(_owner.Id, prefix, It.IsAny<CancellationToken>()))
                .ReturnsAsync(new List<VaultEntry> { new() { RelativePath = $"{prefix}/a.jpg", ByteSize = 3 } });

            var result = await _controller.Purge(note.Id, _authors.Object, _vault.Object, CancellationToken.None);

            Assert.IsType<NoContentResult>(result);
            Assert.True((await _noteManager.GetNoteByIdAsync(note.Id, true)).IsNotFound);
            _vault.Verify(v => v.DeleteAsync(_owner.Id, $"{prefix}/a.jpg", It.IsAny<CancellationToken>()), Times.Once);
        }

        [Fact]
        public async Task Purge_of_a_live_note_is_Conflict_and_keeps_it()
        {
            var note = await CreateNoteAsync(deleted: false);

            var result = await _controller.Purge(note.Id, _authors.Object, _vault.Object, CancellationToken.None);

            Assert.IsType<ConflictObjectResult>(result);
            Assert.True((await _noteManager.GetNoteByIdAsync(note.Id)).Success);
            _vault.Verify(v => v.DeleteAsync(It.IsAny<int>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
        }

        [Fact]
        public async Task Purge_by_another_author_is_NotFound_and_keeps_it()
        {
            var note = await CreateNoteAsync(deleted: true);
            SignInAs(new Author { Id = 999, AccountName = "intruder" });

            var result = await _controller.Purge(note.Id, _authors.Object, _vault.Object, CancellationToken.None);

            Assert.IsType<NotFoundObjectResult>(result);
            Assert.True((await _noteManager.GetNoteByIdAsync(note.Id, true)).Success);
        }

        [Fact]
        public async Task Purge_still_succeeds_when_vault_cleanup_fails()
        {
            var note = await CreateNoteAsync(deleted: true);
            _vault.Setup(v => v.ListAsync(It.IsAny<int>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
                .ThrowsAsync(new IOException("disk"));

            var result = await _controller.Purge(note.Id, _authors.Object, _vault.Object, CancellationToken.None);

            Assert.IsType<NoContentResult>(result);
        }

        [Fact]
        public async Task Put_on_a_deleted_note_is_Conflict_not_500()
        {
            var note = await CreateNoteAsync(deleted: true);

            var result = await _controller.Put(note.Id, new ApiNoteForUpdate { Subject = "edited", Content = "c" });

            Assert.IsType<ConflictObjectResult>(result);
        }

        [Fact]
        public async Task Delete_of_an_already_deleted_note_is_NoContent_not_500()
        {
            var note = await CreateNoteAsync(deleted: true);

            var result = await _controller.Delete(note.Id);

            Assert.IsType<NoContentResult>(result);
        }
    }
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.Core.Tests --filter "FullyQualifiedName~HmmNoteManagerRestorePurgeTests" 2>&1 | tail -5
```
Expected: build FAILS with `error CS1061: 'HmmNoteManager' does not contain a definition for 'RestoreAsync'`.

- [ ] **Step 4: Add the fixture `DeleteAsync` mock**

In `CoreTestFixtureBase.GetNoteRepository()`, insert before `return mockNotes.Object;`:

```csharp
            mockNotes.Setup(a => a.DeleteAsync(It.IsAny<HmmNoteDao>())).ReturnsAsync((HmmNoteDao note) =>
            {
                var removed = _noteDaos.RemoveAll(n => n.Id == note.Id);
                return removed == 0
                    ? ProcessingResult<Unit>.NotFound($"Note with ID {note.Id} not found")
                    : ProcessingResult<Unit>.Ok(Unit.Value);
            });
```

- [ ] **Step 5: Add the manager methods**

In `IHmmNoteManager.cs`, after `Task<ProcessingResult<Unit>> DeleteAsync(int noteId);` add:

```csharp

        /// <summary>
        /// Undo a soft delete (Recently Deleted → Restore). Idempotent: a
        /// live note is returned unchanged. NotFound passes through.
        /// </summary>
        Task<ProcessingResult<HmmNote>> RestoreAsync(int noteId);

        /// <summary>
        /// Permanently remove a soft-deleted note; its tag refs cascade.
        /// Returns Conflict for a live note (only Recently Deleted notes can
        /// be purged — a restore that won the race must never be destroyed)
        /// and NotFound for a missing one.
        /// </summary>
        Task<ProcessingResult<Unit>> PurgeAsync(int noteId);
```

In `HmmNoteManager.cs`, after the `DeleteAsync` method add:

```csharp

        public async Task<ProcessingResult<HmmNote>> RestoreAsync(int id)
        {
            var noteResult = await GetNoteByIdAsync(id, includeDelete: true);
            if (!noteResult.Success)
            {
                return noteResult;
            }

            var note = noteResult.Value;
            if (!note.IsDeleted)
            {
                return ProcessingResult<HmmNote>.Ok(note);
            }

            note.IsDeleted = false;
            return await UpdateAsync(note);
        }

        public async Task<ProcessingResult<Unit>> PurgeAsync(int id)
        {
            var noteResult = await GetNoteByIdAsync(id, includeDelete: true);
            if (!noteResult.Success)
            {
                return noteResult.IsNotFound
                    ? ProcessingResult<Unit>.NotFound($"Cannot find note with id {id}")
                    : ProcessingResult<Unit>.Fail(noteResult.ErrorMessage, noteResult.ErrorType);
            }

            if (!noteResult.Value.IsDeleted)
            {
                return ProcessingResult<Unit>.Conflict(
                    $"Note {id} is not deleted; only deleted notes can be purged");
            }

            // Only the key is needed to remove the row; mapping the whole
            // note (tags included) back to a DAO is unnecessary here.
            var deleteResult = await _noteRepository.DeleteAsync(
                new HmmNoteDao { Id = id, Subject = noteResult.Value.Subject });
            if (!deleteResult.Success)
            {
                return ProcessingResult<Unit>.Fail(deleteResult.ErrorMessage, deleteResult.ErrorType);
            }

            await _unitOfWork.CommitAsync();
            return ProcessingResult<Unit>.Ok(Unit.Value, $"Note with id {id} has been purged");
        }
```

- [ ] **Step 6: Add the controller actions**

In `HmmNoteController.cs` add usings `using Hmm.Core.Vault;` and `using System.Threading;`.

In `Put`, inside `if (!curNoteResult.Success)` (line 212), insert before the `IsNotFound` check:

```csharp
                    if (curNoteResult.ErrorType == ErrorCategory.Deleted)
                    {
                        return Conflict(ProblemDetailsHelper.Conflict(
                            $"Note {id} is deleted; restore it first (POST /v1/notes/{id}/restore).", HttpContext));
                    }
```

In `Delete`, inside `if (!curNoteResult.Success)` (line 379), insert before the `IsNotFound` check:

```csharp
                    if (curNoteResult.ErrorType == ErrorCategory.Deleted)
                    {
                        // Already a tombstone: deleting again is a no-op, not a 500.
                        return NoContent();
                    }
```

Before the final closing brace of the class add:

```csharp

        /// <summary>
        /// Undo a soft delete. Owner-only: another author's note (or a
        /// missing one) is a 404, never revealing which ids exist.
        /// </summary>
        [HttpPost("{id:int}/restore", Name = "RestoreNote")]
        [TypeFilter(typeof(NoteResultFilter))]
        [ProducesResponseType(typeof(ApiNote), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
        public async Task<IActionResult> Restore(int id, [FromServices] ICurrentUserAuthorProvider authorProvider)
        {
            try
            {
                var (error, _) = await ResolveOwnerAsync(id, authorProvider);
                if (error != null) return error;

                var result = await _noteManager.RestoreAsync(id);
                if (!result.Success)
                {
                    if (result.IsNotFound)
                    {
                        return NotFound(ProblemDetailsHelper.NotFound($"Note with id {id} not found", HttpContext));
                    }
                    _logger.LogError("Failed to restore note {NoteId}. ErrorType: {ErrorType}, TraceId: {TraceId}",
                        id, result.ErrorType, HttpContext.TraceIdentifier);
                    return StatusCode(StatusCodes.Status500InternalServerError,
                        ProblemDetailsHelper.InternalServerError("An error occurred while restoring the note.", HttpContext));
                }

                return Ok(result.Value);
            }
            catch (Exception ex)
            {
                _logger.LogError("Unexpected {ErrorType} while restoring note {NoteId}. TraceId: {TraceId}",
                    ex.GetType().Name, id, HttpContext.TraceIdentifier);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ProblemDetailsHelper.InternalServerError("An unexpected error occurred while restoring the note.", HttpContext));
            }
        }

        /// <summary>
        /// Permanently remove a soft-deleted note (Recently Deleted → Delete
        /// now / 30-day purge). Owner-only; 409 for a live note. Removes the
        /// note's vault folder <c>attachments/note-{id}</c> best-effort.
        /// </summary>
        [HttpDelete("{id:int}/purge", Name = "PurgeNote")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
        public async Task<IActionResult> Purge(
            int id,
            [FromServices] ICurrentUserAuthorProvider authorProvider,
            [FromServices] IVaultBlobStore vaultStore,
            CancellationToken cancellationToken)
        {
            try
            {
                var (error, authorId) = await ResolveOwnerAsync(id, authorProvider);
                if (error != null) return error;

                var result = await _noteManager.PurgeAsync(id);
                if (!result.Success)
                {
                    if (result.IsNotFound)
                    {
                        return NotFound(ProblemDetailsHelper.NotFound($"Note with id {id} not found", HttpContext));
                    }
                    if (result.ErrorType == ErrorCategory.Conflict)
                    {
                        return Conflict(ProblemDetailsHelper.Conflict(result.ErrorMessage, HttpContext));
                    }
                    _logger.LogError("Failed to purge note {NoteId}. ErrorType: {ErrorType}, TraceId: {TraceId}",
                        id, result.ErrorType, HttpContext.TraceIdentifier);
                    return StatusCode(StatusCodes.Status500InternalServerError,
                        ProblemDetailsHelper.InternalServerError("An error occurred while purging the note.", HttpContext));
                }

                try
                {
                    var entries = await vaultStore.ListAsync(authorId, $"attachments/note-{id}", cancellationToken);
                    foreach (var entry in entries)
                    {
                        await vaultStore.DeleteAsync(authorId, entry.RelativePath, cancellationToken);
                    }
                }
                catch (Exception ex)
                {
                    // The row is gone; leftover bytes are unreachable and harmless.
                    _logger.LogWarning("Vault cleanup after purging note {NoteId} failed: {ErrorType}",
                        id, ex.GetType().Name);
                }

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError("Unexpected {ErrorType} while purging note {NoteId}. TraceId: {TraceId}",
                    ex.GetType().Name, id, HttpContext.TraceIdentifier);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ProblemDetailsHelper.InternalServerError("An unexpected error occurred while purging the note.", HttpContext));
            }
        }

        /// <summary>
        /// (This file has no nullable context, so the tuple's Error is a plain
        /// IActionResult that is null on success.)
        /// Resolve the signed-in author and verify they own note
        /// <paramref name="id"/> (deleted notes included). A missing note and
        /// another author's note both map to the same 404.
        /// </summary>
        private async Task<(IActionResult Error, int AuthorId)> ResolveOwnerAsync(
            int id, ICurrentUserAuthorProvider authorProvider)
        {
            var authorResult = await authorProvider.GetCurrentUserAuthorAsync();
            if (!authorResult.Success || authorResult.Value == null)
            {
                return (Unauthorized(), 0);
            }

            var noteResult = await _noteManager.GetNoteByIdAsync(id, includeDelete: true);
            if (!noteResult.Success || noteResult.Value == null
                || noteResult.Value.Author == null
                || noteResult.Value.Author.Id != authorResult.Value.Id)
            {
                return (NotFound(ProblemDetailsHelper.NotFound($"Note with id {id} not found", HttpContext)), 0);
            }

            return (null, authorResult.Value.Id);
        }
```

- [ ] **Step 7: Run tests**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.Core.Tests --filter "FullyQualifiedName~HmmNoteManagerRestorePurgeTests" 2>&1 | tail -1          # Passed: 6
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~NoteControllerRestorePurgeTests" 2>&1 | tail -1 # Passed: 10
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1             # Passed: 241
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1  # Passed: 462
```

- [ ] **Step 8: Commit**

```bash
cd /Users/fchy/Projects/hmm
git add src/Hmm.Core/IHmmNoteManager.cs src/Hmm.Core/DefaultManager/HmmNoteManager.cs \
  src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs \
  src/Hmm.Utility.TestHelp/CoreTestFixtureBase.cs \
  src/Hmm.Core.Tests/HmmNoteManagerRestorePurgeTests.cs src/Hmm.ServiceApi.Core.Tests/NoteControllerRestorePurgeTests.cs
git commit -m "$(cat <<'MSG'
feat(notes): owner-only restore + purge endpoints; PUT on deleted is 409

POST /v1/notes/{id}/restore undoes a soft delete (previously impossible:
PUT on a deleted note returned 500). DELETE /v1/notes/{id}/purge removes a
soft-deleted row and its vault folder; a live note is 409 so a restore that
won the race is never destroyed. Re-deleting a tombstone is now 204.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 4: Server — note tag membership (`GET|PUT /v1/notes/{id}/tags`, `ApiNote.TagNames`)

Why not just `PUT /notes/{id}/applyTag`: on EF it cannot work. `EfEntityLookup` and `NoteEfRepository` load `Tags` without `ThenInclude(Tag)`, so `HmmNote.Tags` holds nulls and the next `UpdateAsync` mapping throws (every PUT/DELETE/restore of a tagged note would 500); and the `HmmNote → HmmNoteDao` map emits `NoteTagRefDao { Id = 0 }` rows that `Update()` INSERTs as duplicates. Slice 1 therefore (a) loads tags properly, (b) stops note updates from touching tag refs when the note arrives detached (the API path), and (c) owns membership in one set-replace repository, which `applyTag` now uses too. This mirrors cloudStorage, where the note body's `tags` list is the complete set.

**Files:**
- Create: `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/Repositories/INoteTagMembershipRepository.cs`
- Create: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Repositories/NoteTagMembershipEfRepository.cs`
- Create: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteTagsForUpdate.cs`
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/EfEntityLookup.cs` (HmmNoteDao branches, lines 67–71 and 113–116)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Repositories/NoteEfRepository.cs` (`GetEntitiesAsync` lines 42–44, `GetEntityAsync` lines 58–60, `UpdateAsync` line 202)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi/Startup.cs` (DI, after line 196)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs`, `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs` (`HmmNote → ApiNote`, lines 72–76)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs` (`ApplyTag`, lines 259–296; new actions)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF.Tests/NoteTagMembershipRepositoryTests.cs` (create)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerTagsTests.cs` (create)

**Interfaces:**
- Produces (C#):
  - `namespace Hmm.Core.Map.Repositories; public interface INoteTagMembershipRepository { Task<IReadOnlyList<string>> GetTagNamesAsync(int noteId); Task<IReadOnlyList<string>> SetTagNamesAsync(int noteId, IReadOnlyCollection<string> names); }` — set-replace, names matched case-insensitively, missing tags created, deactivated tags reactivated, commits itself, returns the saved names sorted.
  - `ApiNote.TagNames : IList<string>` (JSON `"tagNames"`).
  - `ApiNoteTagsForUpdate { IList<string> Names }` (JSON `{"names": [...]}`).
  - `GET /v1/notes/{id}/tags` → 200 `string[]`; `PUT /v1/notes/{id}/tags` → 200 `string[]` (saved) | 400 (null names / a name > 200 chars) | 401 | 404.
  - `PUT /v1/notes/{id}/applyTag` keeps its contract (204) but now adds one name through the membership repository.

- [ ] **Step 1: Write the failing EF tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF.Tests/NoteTagMembershipRepositoryTests.cs`:

```csharp
using Hmm.Core.Dal.EF.Repositories;
using Hmm.Core.Map.DbEntity;
using Hmm.Utility.TestHelp;
using Microsoft.EntityFrameworkCore;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Xunit;

namespace Hmm.Core.Dal.EF.Tests
{
    public class NoteTagMembershipRepositoryTests : DbTestFixtureBase, IAsyncLifetime
    {
        private AuthorDao _author;
        private NoteCatalogDao _catalog;
        private NoteTagMembershipEfRepository _membership;

        private DbContext Ef => (DbContext)DbContext;

        private async Task<int> AddNoteAsync()
        {
            var note = new HmmNoteDao { Author = _author, Catalog = _catalog, Subject = "tagged", Content = "c" };
            await NoteRepository.AddAsync(note);
            await DbContext.CommitAsync();
            return note.Id;
        }

        [Fact]
        public async Task Set_replaces_the_membership()
        {
            var id = await AddNoteAsync();

            Assert.Equal(new[] { "urgent", "work" }, await _membership.SetTagNamesAsync(id, new[] { "work", "urgent" }));
            Assert.Equal(new[] { "work" }, await _membership.SetTagNamesAsync(id, new[] { "work" }));
            Assert.Empty(await _membership.SetTagNamesAsync(id, new string[0]));
            Assert.Empty(await _membership.GetTagNamesAsync(id));
        }

        [Fact]
        public async Task Set_matches_names_case_insensitively_and_reuses_tags()
        {
            DbContext.Set<TagDao>().Add(new TagDao { Name = "Work", IsActivated = true });
            await DbContext.CommitAsync();
            var id = await AddNoteAsync();

            var saved = await _membership.SetTagNamesAsync(id, new[] { "work", "WORK " });

            Assert.Equal(new[] { "Work" }, saved);
            Assert.Equal(1, await DbContext.Set<TagDao>().CountAsync(t => t.Name.ToLower() == "work"));
        }

        [Fact]
        public async Task Set_reactivates_a_deactivated_tag()
        {
            DbContext.Set<TagDao>().Add(new TagDao { Name = "old", IsActivated = false });
            await DbContext.CommitAsync();
            var id = await AddNoteAsync();

            await _membership.SetTagNamesAsync(id, new[] { "old" });

            Assert.True((await DbContext.Set<TagDao>().SingleAsync(t => t.Name == "old")).IsActivated);
        }

        [Fact]
        public async Task Lookup_loads_tag_names_with_the_note()
        {
            var id = await AddNoteAsync();
            await _membership.SetTagNamesAsync(id, new[] { "work" });
            Ef.ChangeTracker.Clear();

            var dao = (await LookupRepository.GetEntityAsync<HmmNoteDao>(id)).Value;

            Assert.Equal("work", dao.Tags.Single().Tag.Name);
        }

        [Fact]
        public async Task A_detached_note_update_neither_duplicates_nor_drops_tag_refs()
        {
            var id = await AddNoteAsync();
            await _membership.SetTagNamesAsync(id, new[] { "work" });
            var tagId = (await DbContext.Set<TagDao>().SingleAsync(t => t.Name == "work")).Id;
            Ef.ChangeTracker.Clear();

            // The API path: the manager maps the domain note into a NEW dao
            // whose tag refs carry Id = 0.
            var detached = new HmmNoteDao
            {
                Id = id, Subject = "renamed", Content = "c", Author = _author, Catalog = _catalog,
                Tags = new List<NoteTagRefDao> { new() { NoteId = id, TagId = tagId } },
            };
            var result = await NoteRepository.UpdateAsync(detached);
            Assert.True(result.Success);
            await DbContext.CommitAsync();
            Ef.ChangeTracker.Clear();

            Assert.Equal(1, await DbContext.Set<NoteTagRefDao>().CountAsync(r => r.NoteId == id));
            Assert.Equal(new[] { "work" }, await _membership.GetTagNamesAsync(id));
        }

        public async Task InitializeAsync()
        {
            Transaction = await Ef.Database.BeginTransactionAsync();
            _catalog = (await CatalogRepository.AddAsync(new NoteCatalogDao
            {
                Name = "tags-dal-test-catalog", Schema = "", FormatType = NoteContentFormatType.PlainText,
                IsDefault = true, Description = "tag membership test catalog",
            })).Value;
            var contact = (await ContactRepository.AddAsync(new ContactDao
            {
                Contact = "{ \"FirstName\": \"Tag\", \"LastName\": \"Member\" }", Description = "tags contact", IsActivated = true,
            })).Value;
            _author = (await AuthorRepository.AddAsync(new AuthorDao
            {
                AccountName = "tags-dal-test", ContactInfo = contact, Description = "tags author", IsActivated = true,
            })).Value;
            await DbContext.CommitAsync();
            _membership = new NoteTagMembershipEfRepository(DbContext);
        }

        public async Task DisposeAsync()
        {
            await Transaction.RollbackAsync();
            await Transaction.DisposeAsync();
        }
    }
}
```

- [ ] **Step 2: Write the failing controller + mapping tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerTagsTests.cs`:

```csharp
using Hmm.Core;
using Hmm.Core.DefaultManager;
using Hmm.Core.Map.DomainEntity;
using Hmm.Core.Map.Repositories;
using Hmm.ServiceApi.Areas.HmmNoteService.Controllers;
using Hmm.ServiceApi.DtoEntity.HmmNote;
using Hmm.Utility.Misc;
using Hmm.Utility.TestHelp;
using Hmm.Utility.Validation;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;

namespace Hmm.ServiceApi.Core.Tests
{
    public class NoteControllerTagsTests : CoreTestFixtureBase
    {
        private readonly HmmNoteManager _noteManager;
        private readonly HmmNoteController _controller;
        private readonly Mock<ICurrentUserAuthorProvider> _authors = new();
        private readonly Mock<INoteTagMembershipRepository> _membership = new();

        public NoteControllerTagsTests()
        {
            var validator = new Mock<IHmmValidator<HmmNote>>();
            validator.Setup(v => v.ValidateEntityAsync(It.IsAny<HmmNote>()))
                .ReturnsAsync((HmmNote n) => ProcessingResult<HmmNote>.Ok(n));
            var tagValidator = new Mock<IHmmValidator<Tag>>();
            tagValidator.Setup(v => v.ValidateEntityAsync(It.IsAny<Tag>()))
                .ReturnsAsync((Tag t) => ProcessingResult<Tag>.Ok(t));
            _noteManager = new HmmNoteManager(NoteRepository, UnitOfWork, Mapper, LookupRepository, DateProvider, validator.Object);
            var tagManager = new TagManager(TagRepository, UnitOfWork, Mapper, LookupRepository, tagValidator.Object);
            _controller = new HmmNoteController(_noteManager, new NoteTagAssociationManager(_noteManager, tagManager),
                ApiMapper, new Mock<ILogger<HmmNoteController>>().Object)
            {
                ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
            };
            ConfigureControllerForValidation(_controller);
        }

        private async Task<int> CreateOwnedNoteAsync()
        {
            var owner = await GetTestAuthor();
            var created = await _noteManager.CreateAsync(new HmmNote
            {
                Author = owner, Catalog = await GetTestCatalog(), Subject = "tagged", Content = "c",
            });
            _authors.Setup(a => a.GetCurrentUserAuthorAsync()).ReturnsAsync(ProcessingResult<Author>.Ok(owner));
            return created.Value.Id;
        }

        [Fact]
        public async Task GetTags_returns_the_note_tag_names()
        {
            var id = await CreateOwnedNoteAsync();
            _membership.Setup(m => m.GetTagNamesAsync(id)).ReturnsAsync(new List<string> { "urgent", "work" });

            var result = await _controller.GetTags(id, _membership.Object, _authors.Object);

            var ok = Assert.IsType<OkObjectResult>(result);
            Assert.Equal(new[] { "urgent", "work" }, Assert.IsAssignableFrom<IReadOnlyList<string>>(ok.Value));
        }

        [Fact]
        public async Task SetTags_replaces_membership_and_returns_the_saved_names()
        {
            var id = await CreateOwnedNoteAsync();
            _membership.Setup(m => m.SetTagNamesAsync(id, It.IsAny<IReadOnlyCollection<string>>()))
                .ReturnsAsync(new List<string> { "home" });

            var result = await _controller.SetTags(id, new ApiNoteTagsForUpdate { Names = new List<string> { "home" } },
                _membership.Object, _authors.Object);

            var ok = Assert.IsType<OkObjectResult>(result);
            Assert.Equal(new[] { "home" }, Assert.IsAssignableFrom<IReadOnlyList<string>>(ok.Value));
            _membership.Verify(m => m.SetTagNamesAsync(id,
                It.Is<IReadOnlyCollection<string>>(n => n.SequenceEqual(new[] { "home" }))), Times.Once);
        }

        [Fact]
        public async Task SetTags_with_null_names_is_BadRequest()
        {
            var id = await CreateOwnedNoteAsync();

            var result = await _controller.SetTags(id, new ApiNoteTagsForUpdate { Names = null },
                _membership.Object, _authors.Object);

            Assert.IsType<BadRequestObjectResult>(result);
        }

        [Fact]
        public async Task SetTags_with_a_name_over_200_chars_is_BadRequest()
        {
            var id = await CreateOwnedNoteAsync();

            var result = await _controller.SetTags(id, new ApiNoteTagsForUpdate { Names = new List<string> { new string('x', 201) } },
                _membership.Object, _authors.Object);

            Assert.IsType<BadRequestObjectResult>(result);
            _membership.Verify(m => m.SetTagNamesAsync(It.IsAny<int>(), It.IsAny<IReadOnlyCollection<string>>()), Times.Never);
        }

        [Fact]
        public async Task SetTags_by_another_author_is_NotFound()
        {
            var id = await CreateOwnedNoteAsync();
            _authors.Setup(a => a.GetCurrentUserAuthorAsync())
                .ReturnsAsync(ProcessingResult<Author>.Ok(new Author { Id = 999, AccountName = "intruder" }));

            var result = await _controller.SetTags(id, new ApiNoteTagsForUpdate { Names = new List<string> { "x" } },
                _membership.Object, _authors.Object);

            Assert.IsType<NotFoundObjectResult>(result);
            _membership.Verify(m => m.SetTagNamesAsync(It.IsAny<int>(), It.IsAny<IReadOnlyCollection<string>>()), Times.Never);
        }

        [Fact]
        public async Task ApplyTag_adds_one_name_through_the_membership()
        {
            var id = await CreateOwnedNoteAsync();
            _membership.Setup(m => m.GetTagNamesAsync(id)).ReturnsAsync(new List<string> { "work" });
            _membership.Setup(m => m.SetTagNamesAsync(id, It.IsAny<IReadOnlyCollection<string>>()))
                .ReturnsAsync(new List<string> { "home", "work" });

            var result = await _controller.ApplyTag(id, new ApiTagForApply { Name = "home" }, _membership.Object, _authors.Object);

            Assert.IsType<NoContentResult>(result);
            _membership.Verify(m => m.SetTagNamesAsync(id,
                It.Is<IReadOnlyCollection<string>>(n => n.SequenceEqual(new[] { "work", "home" }))), Times.Once);
        }

        [Fact]
        public void ApiNote_exposes_TagNames()
        {
            var note = new HmmNote
            {
                Id = 1, Subject = "s", Content = "c", Author = new Author { Id = 1 }, Catalog = new NoteCatalog { Id = 1 },
                Tags = new List<Tag> { new() { Name = "work" }, new() { Name = "home" } },
            };

            var api = ApiMapper.Map<ApiNote>(note);

            Assert.Equal(new[] { "work", "home" }, api.TagNames);
        }
    }
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.Core.Dal.EF.Tests --filter "FullyQualifiedName~NoteTagMembershipRepositoryTests" 2>&1 | tail -5
```
Expected: build FAILS with `error CS0246: The type or namespace name 'NoteTagMembershipEfRepository' could not be found`.

- [ ] **Step 4: Add the repository interface and EF implementation**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/Repositories/INoteTagMembershipRepository.cs`:

```csharp
using System.Collections.Generic;
using System.Threading.Tasks;

namespace Hmm.Core.Map.Repositories
{
    /// <summary>
    /// Owns which tags a note carries. Set-replace by name, matching the
    /// cloudStorage note body where the <c>tags</c> list is the complete set.
    /// Note updates never touch tag refs; this is the only writer.
    /// </summary>
    public interface INoteTagMembershipRepository
    {
        /// <summary>The note's tag names, sorted.</summary>
        Task<IReadOnlyList<string>> GetTagNamesAsync(int noteId);

        /// <summary>
        /// Make <paramref name="names"/> the note's complete tag set. Names
        /// are trimmed and matched case-insensitively; missing tags are
        /// created, deactivated ones reactivated. Commits. Returns the saved
        /// names, sorted.
        /// </summary>
        Task<IReadOnlyList<string>> SetTagNamesAsync(int noteId, IReadOnlyCollection<string> names);
    }
}
```

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Repositories/NoteTagMembershipEfRepository.cs`:

```csharp
using Hmm.Core.Map.DbEntity;
using Hmm.Core.Map.Repositories;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Hmm.Core.Dal.EF.Repositories
{
    public class NoteTagMembershipEfRepository : INoteTagMembershipRepository
    {
        private readonly IHmmDataContext _dataContext;

        public NoteTagMembershipEfRepository(IHmmDataContext dataContext)
        {
            ArgumentNullException.ThrowIfNull(dataContext);
            _dataContext = dataContext;
        }

        public async Task<IReadOnlyList<string>> GetTagNamesAsync(int noteId)
        {
            return await _dataContext.Set<NoteTagRefDao>()
                .AsNoTracking()
                .Where(r => r.NoteId == noteId)
                .Select(r => r.Tag.Name)
                .OrderBy(n => n)
                .ToListAsync();
        }

        public async Task<IReadOnlyList<string>> SetTagNamesAsync(int noteId, IReadOnlyCollection<string> names)
        {
            ArgumentNullException.ThrowIfNull(names);

            var wanted = names
                .Where(n => !string.IsNullOrWhiteSpace(n))
                .Select(n => n.Trim())
                .GroupBy(n => n.ToLowerInvariant())
                .Select(g => g.First())
                .ToList();
            var wantedKeys = wanted.Select(n => n.ToLowerInvariant()).ToHashSet();

            var refs = await _dataContext.Set<NoteTagRefDao>()
                .Include(r => r.Tag)
                .Where(r => r.NoteId == noteId)
                .ToListAsync();

            foreach (var stale in refs.Where(r => !wantedKeys.Contains(r.Tag.Name.ToLowerInvariant())))
            {
                _dataContext.Set<NoteTagRefDao>().Remove(stale);
            }

            var haveKeys = refs.Select(r => r.Tag.Name.ToLowerInvariant()).ToHashSet();
            foreach (var name in wanted.Where(n => !haveKeys.Contains(n.ToLowerInvariant())))
            {
                var lower = name.ToLowerInvariant();
                var tag = await _dataContext.Set<TagDao>().FirstOrDefaultAsync(t => t.Name.ToLower() == lower);
                if (tag == null)
                {
                    tag = new TagDao { Name = name, IsActivated = true };
                    _dataContext.Set<TagDao>().Add(tag);
                }
                else if (!tag.IsActivated)
                {
                    tag.IsActivated = true;
                }

                _dataContext.Set<NoteTagRefDao>().Add(new NoteTagRefDao { NoteId = noteId, Tag = tag });
            }

            await _dataContext.CommitAsync();
            return await GetTagNamesAsync(noteId);
        }
    }
}
```

- [ ] **Step 5: Load tags properly and keep note updates off tag refs**

In `EfEntityLookup.cs`, in both `HmmNoteDao` branches replace `.Include(n => n.Tags)` with `.Include(n => n.Tags).ThenInclude(r => r.Tag)` (lines ~71 and ~115).

In `NoteEfRepository.GetEntitiesAsync`, replace lines 42–44 with:

```csharp
            var notes = query == null
                ? _dataContext.Set<HmmNoteDao>().Include(n => n.Author).Include(n => n.Catalog).Include(n => n.Tags).ThenInclude(r => r.Tag)
                : _dataContext.Set<HmmNoteDao>().Include(n => n.Author).Include(n => n.Catalog).Include(n => n.Tags).ThenInclude(r => r.Tag).Where(query);
```

In `NoteEfRepository.GetEntityAsync`, replace `.Include(n => n.Tags)` with `.Include(n => n.Tags).ThenInclude(r => r.Tag)`.

In `NoteEfRepository.UpdateAsync`, replace

```csharp
                _dataContext.Set<HmmNoteDao>().Update(entity);
```

with

```csharp
                // Tag membership is owned by INoteTagMembershipRepository. A
                // note arriving detached (the API path maps the domain note
                // into a NEW dao) carries NoteTagRefDao rows with Id = 0 that
                // Update() would INSERT as duplicates. Drop them: untracked
                // refs are not orphan-deleted, so stored membership is kept.
                if (_dataContext is DbContext db && db.Entry(entity).State == EntityState.Detached)
                {
                    entity.Tags = new List<NoteTagRefDao>();
                }
                _dataContext.Set<HmmNoteDao>().Update(entity);
```

and add `using System.Collections.Generic;` to `NoteEfRepository.cs`.

- [ ] **Step 6: DTOs, mapping and DI**

Create `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteTagsForUpdate.cs`:

```csharp
using System.Collections.Generic;

namespace Hmm.ServiceApi.DtoEntity.HmmNote
{
    /// <summary>Body of PUT /v1/notes/{id}/tags: the note's complete tag set.</summary>
    public class ApiNoteTagsForUpdate
    {
        public IList<string> Names { get; set; } = new List<string>();
    }
}
```

In `ApiNote.cs`, after the `FlagColor` property add:

```csharp

        /// <summary>
        /// The note's tag names (read-only projection; written through
        /// PUT /v1/notes/{id}/tags).
        /// </summary>
        public IList<string> TagNames { get; set; } = new List<string>();
```

In `ApiMappingProfile.cs`, replace the `CreateMap<Core.Map.DomainEntity.HmmNote, ApiNote>()` chain's last member mapping

```csharp
                .ForMember(n => n.CatalogName,
                    opt => opt.MapFrom(s => s.Catalog != null ? s.Catalog.Name : null));
```

with

```csharp
                .ForMember(n => n.CatalogName,
                    opt => opt.MapFrom(s => s.Catalog != null ? s.Catalog.Name : null))
                .ForMember(n => n.TagNames,
                    opt => opt.MapFrom(s => s.Tags == null
                        ? new List<string>()
                        : s.Tags.Where(t => t != null).Select(t => t.Name).ToList()));
```

(add `using System.Linq;` and `using System.Collections.Generic;` to `ApiMappingProfile.cs` if absent).

In `Startup.cs`, after `.AddScoped<IVersionRepository<HmmNoteDao>, NoteEfRepository>()` add:

```csharp
                .AddScoped<INoteTagMembershipRepository, NoteTagMembershipEfRepository>()
```

and add `using Hmm.Core.Map.Repositories;` to `Startup.cs`.

- [ ] **Step 7: Controller endpoints and the `applyTag` rewire**

In `HmmNoteController.cs` add `using Hmm.Core.Map.Repositories;` and `using System.Collections.Generic;`. Replace the whole `ApplyTag` action (lines 254–296, doc comment included) with:

```csharp
        /// <summary>
        /// Applies one tag to a note (creating the tag if needed). Kept for
        /// compatibility; implemented on the set-replace membership.
        /// </summary>
        [HttpPut("{id:int}/applyTag", Name = "ApplyTagToNote")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
        public async Task<IActionResult> ApplyTag(
            int id,
            [FromBody] ApiTagForApply tag,
            [FromServices] INoteTagMembershipRepository membership,
            [FromServices] ICurrentUserAuthorProvider authorProvider)
        {
            if (tag == null || string.IsNullOrWhiteSpace(tag.Name))
            {
                return BadRequest(ProblemDetailsHelper.BadRequest("Tag information is null", HttpContext));
            }

            try
            {
                var (error, _) = await ResolveOwnerAsync(id, authorProvider);
                if (error != null) return error;

                var names = (await membership.GetTagNamesAsync(id)).ToList();
                names.Add(tag.Name.Trim());
                await membership.SetTagNamesAsync(id, names);
                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError("Unexpected {ErrorType} while applying a tag to note {NoteId}. TraceId: {TraceId}",
                    ex.GetType().Name, id, HttpContext.TraceIdentifier);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ProblemDetailsHelper.InternalServerError("An unexpected error occurred while applying the tag.", HttpContext));
            }
        }

        /// <summary>The note's tag names, sorted. Owner-only.</summary>
        [HttpGet("{id:int}/tags", Name = "GetNoteTags")]
        [ProducesResponseType(typeof(string[]), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetTags(
            int id,
            [FromServices] INoteTagMembershipRepository membership,
            [FromServices] ICurrentUserAuthorProvider authorProvider)
        {
            var (error, _) = await ResolveOwnerAsync(id, authorProvider);
            if (error != null) return error;
            return Ok(await membership.GetTagNamesAsync(id));
        }

        /// <summary>
        /// Replace the note's complete tag set (set-replace by name). Owner-only.
        /// </summary>
        [HttpPut("{id:int}/tags", Name = "SetNoteTags")]
        [ProducesResponseType(typeof(string[]), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
        public async Task<IActionResult> SetTags(
            int id,
            [FromBody] ApiNoteTagsForUpdate body,
            [FromServices] INoteTagMembershipRepository membership,
            [FromServices] ICurrentUserAuthorProvider authorProvider)
        {
            if (body?.Names == null)
            {
                return BadRequest(ProblemDetailsHelper.BadRequest("Tag names are required", HttpContext));
            }
            if (body.Names.Any(n => n != null && n.Trim().Length > 200))
            {
                return BadRequest(ProblemDetailsHelper.BadRequest("A tag name cannot exceed 200 characters", HttpContext));
            }

            try
            {
                var (error, _) = await ResolveOwnerAsync(id, authorProvider);
                if (error != null) return error;

                var saved = await membership.SetTagNamesAsync(id, body.Names.Where(n => n != null).ToList());
                return Ok(saved);
            }
            catch (Exception ex)
            {
                _logger.LogError("Unexpected {ErrorType} while setting tags on note {NoteId}. TraceId: {TraceId}",
                    ex.GetType().Name, id, HttpContext.TraceIdentifier);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ProblemDetailsHelper.InternalServerError("An unexpected error occurred while saving the note's tags.", HttpContext));
            }
        }
```

- [ ] **Step 8: Run tests**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.Core.Dal.EF.Tests --filter "FullyQualifiedName~NoteTagMembershipRepositoryTests" 2>&1 | tail -1   # Passed: 5
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~NoteControllerTagsTests" 2>&1 | tail -1        # Passed: 7
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1             # Passed: 241
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1  # Passed: 469
dotnet test src/Hmm.Core.Dal.EF.Tests 2>&1 | tail -1      # Passed: 75
dotnet build Hmm.sln 2>&1 | tail -3                       # Build succeeded, 0 Error(s)
```

- [ ] **Step 9: Commit**

```bash
cd /Users/fchy/Projects/hmm
git add src/Hmm.Core.Map/Repositories/INoteTagMembershipRepository.cs \
  src/Hmm.Core.Dal.EF/Repositories/NoteTagMembershipEfRepository.cs \
  src/Hmm.Core.Dal.EF/EfEntityLookup.cs src/Hmm.Core.Dal.EF/Repositories/NoteEfRepository.cs \
  src/Hmm.ServiceApi/Startup.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNote.cs \
  src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteTagsForUpdate.cs src/Hmm.ServiceApi.DtoEntity/Profiles/ApiMappingProfile.cs \
  src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs \
  src/Hmm.Core.Dal.EF.Tests/NoteTagMembershipRepositoryTests.cs src/Hmm.ServiceApi.Core.Tests/NoteControllerTagsTests.cs
git status --short   # CLAUDE.md still unstaged
git commit -m "$(cat <<'MSG'
feat(notes): set-replace note tags (GET|PUT /v1/notes/{id}/tags), ApiNote.TagNames

Tag refs were loaded without their Tag (null tags made every update of a
tagged note throw) and detached note updates re-inserted refs with Id 0.
Load tags with ThenInclude, keep note updates off tag refs, and own
membership in INoteTagMembershipRepository; applyTag now uses it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 5: Client — Drift v9 (`isPinned`, `flagColor`), model, inputs, repository pin/flag/restore

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/local/database.dart` (Notes table after `locationLabel`, line 65; `schemaVersion` line 114; `onUpgrade` after the `from < 8` block, line 250)
- Regenerate: `/Users/fchy/Projects/hmm_console/lib/core/data/local/database.g.dart`
- Create: `/Users/fchy/Projects/hmm_console/lib/core/notes/note_flag.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/features/notes/data/models/hmm_note.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/features/notes/data/mappers/hmm_note_mapper.dart` (lines 15–37)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/hmm_note_input.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/local/local_hmm_note_repository.dart` (interface lines 30–65; `createNote` 140–173; `updateNote` 176–213; new methods after `setParentNote`, line 239)
- Modify: `/Users/fchy/Projects/hmm_console/test/features/notes/states/mutate_note_state_test.dart` (`_FakeNoteRepo`, lines 17–64)
- Modify: `/Users/fchy/Projects/hmm_console/test/core/data/local/tags_schema_v6_test.dart` (line 13)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/local/notes_schema_v9_migration_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/local/local_hmm_note_repository_pin_flag_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/notes/note_flag_test.dart` (create)

**Interfaces:**
- Produces (Dart):
  - Drift: `Notes.isPinned` (`BoolColumn`, default false, SQL `is_pinned`), `Notes.flagColor` (`IntColumn` nullable, SQL `flag_color`); `HmmDatabase.schemaVersion == 9`.
  - `enum NoteFlagColor { red, orange, yellow, green, blue, purple, grey }` with `Color color`, `int get stored`, `static NoteFlagColor? fromStored(int? value)`.
  - `HmmNote.isPinned` (`bool`, default `false`), `HmmNote.flagColor` (`int?`), `NoteFlagColor? get flag`.
  - `HmmNoteCreate({..., bool isPinned = false, int? flagColor})`.
  - `class NoteFlagPatch { const NoteFlagPatch(int? color); const NoteFlagPatch.clear(); final int? color; }`
  - `HmmNoteUpdate({..., bool? isPinned, NoteFlagPatch? flag})` — null = don't touch.
  - `IHmmNoteRepository.setPinned(int id, bool pinned) → Future<HmmNote>`, `setFlagColor(int id, int? flagColor) → Future<HmmNote>`, `restoreNote(int id) → Future<HmmNote>`.
  - `DateTime restoreStamp(DateTime previous, DateTime now)` (top-level, `local_hmm_note_repository.dart`).

- [ ] **Step 1: Write the failing migration test**

Create `/Users/fchy/Projects/hmm_console/test/core/data/local/notes_schema_v9_migration_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';

/// The v8 `notes` table exactly as Drift created it (DateTime columns are
/// unix seconds). Only `notes` is needed: the v8 → v9 step touches nothing
/// else.
const _v8Notes = '''
CREATE TABLE notes (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NULL,
  subject TEXT NOT NULL,
  content TEXT NULL,
  author_id INTEGER NOT NULL,
  catalog_id INTEGER NULL,
  parent_note_id INTEGER NULL,
  deleted_at INTEGER NULL,
  version BLOB NULL,
  create_date INTEGER NOT NULL,
  note_date INTEGER NULL,
  latitude REAL NULL,
  longitude REAL NULL,
  location_label TEXT NULL,
  last_modified_date INTEGER NULL,
  description TEXT NULL,
  attachments TEXT NULL
)''';

void main() {
  test('v8 → v9 adds is_pinned (false) and flag_color (null), rows untouched',
      () async {
    final db = HmmDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute(_v8Notes);
      raw.execute(
          "INSERT INTO notes (uuid, subject, content, author_id, create_date, "
          "last_modified_date) VALUES ('u-old', 'old note', 'body', 1, "
          "1700000000, 1700000000)");
      raw.userVersion = 8;
    }));
    addTearDown(db.close);

    expect(db.schemaVersion, 9);
    final row = await db.select(db.notes).getSingle();
    expect(row.uuid, 'u-old');
    expect(row.subject, 'old note');
    expect(row.content, 'body');
    expect(row.isPinned, isFalse);
    expect(row.flagColor, isNull);
    expect(row.lastModifiedDate!.toUtc(),
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true));
  });

  test('a fresh v9 database defaults new notes to unpinned and unflagged',
      () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));

    final id = await db.into(db.notes).insert(
        NotesCompanion.insert(subject: 'new', authorId: authorId));
    final row = await (db.select(db.notes)..where((n) => n.id.equals(id)))
        .getSingle();
    expect(row.isPinned, isFalse);
    expect(row.flagColor, isNull);

    await (db.update(db.notes)..where((n) => n.id.equals(id))).write(
        const NotesCompanion(isPinned: Value(true), flagColor: Value(42)));
    final updated = await (db.select(db.notes)..where((n) => n.id.equals(id)))
        .getSingle();
    expect(updated.isPinned, isTrue);
    expect(updated.flagColor, 42, reason: 'unknown colours are stored verbatim');
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/local/notes_schema_v9_migration_test.dart
```
Expected: compile error `The getter 'isPinned' isn't defined for the type 'Note'`.

- [ ] **Step 3: Add the columns and the migration step**

In `database.dart`, after `TextColumn get locationLabel => text().withLength(min: 0, max: 500).nullable()();` add:

```dart
  // v9: pin + coloured flag (Notes redesign slice 1). Additive; existing
  // rows read as unpinned / unflagged.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  // null = unflagged; 0 red, 1 orange, 2 yellow, 3 green, 4 blue, 5 purple,
  // 6 grey. Any other int (a newer client) is stored verbatim and shown grey.
  IntColumn get flagColor => integer().nullable()();
```

Change `int get schemaVersion => 8;` to `int get schemaVersion => 9;`.

After the `if (from < 8) { ... }` block inside `onUpgrade`, add:

```dart
      if (from < 9) {
        // v9: pin + flag. No backfill — every existing note is unpinned and
        // unflagged by the column defaults.
        await m.addColumn(notes, notes.isPinned);
        await m.addColumn(notes, notes.flagColor);
      }
```

Regenerate:

```bash
cd /Users/fchy/Projects/hmm_console
dart run build_runner build --delete-conflicting-outputs
```

In `test/core/data/local/tags_schema_v6_test.dart` replace

```dart
    // v7 added Notes.noteDate, v8 added Notes location columns; the tag sync
    // columns from v6 are unchanged.
    expect(db.schemaVersion, 8);
```

with

```dart
    // v7 added Notes.noteDate, v8 Notes location, v9 Notes pin/flag; the tag
    // sync columns from v6 are unchanged.
    expect(db.schemaVersion, 9);
```

- [ ] **Step 4: Run the migration test**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/local/notes_schema_v9_migration_test.dart test/core/data/local/tags_schema_v6_test.dart
```
Expected: `All tests passed!` (3 tests).

- [ ] **Step 5: Write the failing flag + repository tests**

Create `/Users/fchy/Projects/hmm_console/test/core/notes/note_flag_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_flag.dart';

void main() {
  test('stored ints map to the seven colours in spec order', () {
    expect(NoteFlagColor.values.map((c) => c.stored), [0, 1, 2, 3, 4, 5, 6]);
    expect(NoteFlagColor.fromStored(0), NoteFlagColor.red);
    expect(NoteFlagColor.fromStored(4), NoteFlagColor.blue);
    expect(NoteFlagColor.fromStored(6), NoteFlagColor.grey);
  });

  test('null is unflagged; unknown values show as grey', () {
    expect(NoteFlagColor.fromStored(null), isNull);
    expect(NoteFlagColor.fromStored(42), NoteFlagColor.grey);
    expect(NoteFlagColor.fromStored(-1), NoteFlagColor.grey);
  });
}
```

Create `/Users/fchy/Projects/hmm_console/test/core/data/local/local_hmm_note_repository_pin_flag_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/notes/note_flag.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository repo;
  var writes = 0;

  setUp(() async {
    writes = 0;
    db = HmmDatabase(NativeDatabase.memory());
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();
    repo = LocalHmmNoteRepository(db, () async => author,
        onLocalWrite: () => writes++);
  });

  tearDown(() => db.close());

  test('createNote stores the initial pin and flag', () async {
    final n = await repo.createNote(const HmmNoteCreate(
        subject: 's', catalogId: 1, isPinned: true, flagColor: 2));
    expect(n.isPinned, isTrue);
    expect(n.flagColor, 2);
    expect(n.flag, NoteFlagColor.yellow);
  });

  test('setPinned flips only the pin, bumps version and notifies sync',
      () async {
    final created = await repo.createNote(const HmmNoteCreate(
        subject: 'keep me', catalogId: 1, content: 'body'));
    writes = 0;

    final pinned = await repo.setPinned(created.id, true);
    expect(pinned.isPinned, isTrue);
    expect(pinned.subject, 'keep me');
    expect(pinned.content, 'body');
    expect(pinned.version, isNot(equals(created.version)));
    expect(pinned.lastModifiedDate, isNotNull);
    expect(writes, 1);

    final unpinned = await repo.setPinned(created.id, false);
    expect(unpinned.isPinned, isFalse);
    expect(writes, 2);
  });

  test('setFlagColor sets, clears, and keeps an unknown value verbatim',
      () async {
    final created =
        await repo.createNote(const HmmNoteCreate(subject: 's', catalogId: 1));

    expect((await repo.setFlagColor(created.id, 3)).flagColor, 3);
    expect((await repo.setFlagColor(created.id, null)).flagColor, isNull);
    final future = await repo.setFlagColor(created.id, 42);
    expect(future.flagColor, 42);
    expect(future.flag, NoteFlagColor.grey);
  });

  test('a pin change leaves the flag alone and vice versa', () async {
    final created = await repo.createNote(
        const HmmNoteCreate(subject: 's', catalogId: 1, flagColor: 5));
    final pinned = await repo.setPinned(created.id, true);
    expect(pinned.flagColor, 5);
    final flagged = await repo.setFlagColor(created.id, 1);
    expect(flagged.isPinned, isTrue);
  });

  test('restoreNote clears deletedAt with a stamp strictly after the tombstone',
      () async {
    final created =
        await repo.createNote(const HmmNoteCreate(subject: 's', catalogId: 1));
    await repo.deleteNote(created.id);
    final tombstone = (await repo.getNoteById(created.id))!;
    expect(tombstone.deletedAt, isNotNull);
    writes = 0;

    final restored = await repo.restoreNote(created.id);

    expect(restored.deletedAt, isNull);
    expect(
        restored.lastModifiedDate!
            .difference(tombstone.lastModifiedDate!)
            .inSeconds,
        greaterThanOrEqualTo(1),
        reason: 'the store keeps whole seconds; a same-second restore would tie');
    expect(writes, 1);
  });

  test('restoreNote on a live note is a no-op', () async {
    final created =
        await repo.createNote(const HmmNoteCreate(subject: 's', catalogId: 1));
    writes = 0;
    final same = await repo.restoreNote(created.id);
    expect(same.deletedAt, isNull);
    expect(same.version, created.version);
    expect(writes, 0);
  });

  test('restoreNote throws for a missing note', () async {
    expect(() => repo.restoreNote(999), throwsStateError);
  });

  test('raw writes outside the repository keep pin/flag columns', () async {
    final created = await repo.createNote(
        const HmmNoteCreate(subject: 's', catalogId: 1, isPinned: true));
    await (db.update(db.notes)..where((n) => n.id.equals(created.id)))
        .write(const NotesCompanion(subject: Value('renamed')));
    expect((await repo.getNoteById(created.id))!.isPinned, isTrue);
  });

  group('restoreStamp', () {
    final prev = DateTime.utc(2026, 10, 18, 9, 0, 0);
    test('a clock in the same second moves to the next whole second', () {
      expect(restoreStamp(prev, DateTime.utc(2026, 10, 18, 9, 0, 0, 700)),
          DateTime.utc(2026, 10, 18, 9, 0, 1));
    });
    test('a clock behind the tombstone still moves past it', () {
      expect(restoreStamp(prev, DateTime.utc(2026, 10, 18, 8, 59, 0)),
          DateTime.utc(2026, 10, 18, 9, 0, 1));
    });
    test('a clock well ahead is used as is', () {
      final now = DateTime.utc(2026, 10, 18, 9, 5, 0);
      expect(restoreStamp(prev, now), now);
    });
    test('a sub-second previous value is floored first', () {
      expect(
          restoreStamp(DateTime.utc(2026, 10, 18, 9, 0, 0, 900),
              DateTime.utc(2026, 10, 18, 9, 0, 0, 950)),
          DateTime.utc(2026, 10, 18, 9, 0, 1));
    });
  });
}
```

- [ ] **Step 6: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/notes/note_flag_test.dart test/core/data/local/local_hmm_note_repository_pin_flag_test.dart
```
Expected: compile errors `Target of URI doesn't exist: 'package:hmm_console/core/notes/note_flag.dart'` and `No named parameter with the name 'isPinned'`.

- [ ] **Step 7: Add `NoteFlagColor`**

Create `/Users/fchy/Projects/hmm_console/lib/core/notes/note_flag.dart`:

```dart
import 'dart:ui' show Color;

/// The seven note flag colours (Apple Mail palette). Persisted as
/// `Notes.flagColor`: null = unflagged, otherwise the enum index.
enum NoteFlagColor {
  red(Color(0xFFFF3B30)),
  orange(Color(0xFFFF9500)),
  yellow(Color(0xFFFFCC00)),
  green(Color(0xFF34C759)),
  blue(Color(0xFF007AFF)),
  purple(Color(0xFFAF52DE)),
  grey(Color(0xFF8E8E93));

  const NoteFlagColor(this.color);

  final Color color;

  /// The int stored in `Notes.flagColor` for this colour.
  int get stored => index;

  /// Display colour for a stored value. Null ⇒ unflagged (null). A value
  /// this build does not know (written by a newer client) shows as grey;
  /// the stored value itself is never rewritten.
  static NoteFlagColor? fromStored(int? value) {
    if (value == null) return null;
    if (value < 0 || value >= NoteFlagColor.values.length) {
      return NoteFlagColor.grey;
    }
    return NoteFlagColor.values[value];
  }
}
```

- [ ] **Step 8: Extend the domain model and mapper**

In `hmm_note.dart`, add `import '../../../../core/notes/note_flag.dart';` to the imports; add `this.isPinned = false,` and `this.flagColor,` to the constructor parameter list (after `this.attachments,`); and add before `/// Note-level attachments`:

```dart
  /// Pinned notes list first (slice 2+). A real edit: changing it bumps
  /// lastModifiedDate so sync carries it.
  final bool isPinned;

  /// Raw stored flag: null = unflagged; 0–6 = [NoteFlagColor] index; any
  /// other int came from a newer client and is preserved verbatim.
  final int? flagColor;

  /// Display flag ([NoteFlagColor.grey] for an unknown stored value).
  NoteFlagColor? get flag => NoteFlagColor.fromStored(flagColor);
```

In `hmm_note_mapper.dart`, in `fromDriftRow` add after `attachments: _decodeAttachments(row.attachments),`:

```dart
        isPinned: row.isPinned,
        flagColor: row.flagColor,
```

- [ ] **Step 9: Extend the input objects**

In `hmm_note_input.dart`:

Add to `HmmNoteCreate`'s constructor `this.isPinned = false,` and `this.flagColor,` and the fields:

```dart
  /// Initial pin. Defaults to unpinned.
  final bool isPinned;

  /// Initial flag (null = unflagged). Stored verbatim.
  final int? flagColor;
```

Add before `class HmmNoteUpdate`:

```dart
/// Patch for `Notes.flagColor`. Wrapping the value keeps "clear the flag"
/// (`NoteFlagPatch(null)` / [NoteFlagPatch.clear]) distinct from "don't
/// touch" (no patch at all).
class NoteFlagPatch {
  const NoteFlagPatch(this.color);
  const NoteFlagPatch.clear() : color = null;

  final int? color;
}
```

Add to `HmmNoteUpdate`'s constructor `this.isPinned,` and `this.flag,`, the fields:

```dart
  /// Replacement pin. Null ⇒ don't touch.
  final bool? isPinned;

  /// Replacement flag. Null ⇒ don't touch; `NoteFlagPatch(null)` clears.
  final NoteFlagPatch? flag;
```

and replace the `isEmpty` getter with:

```dart
  bool get isEmpty =>
      subject == null &&
      content == null &&
      description == null &&
      attachments == null &&
      noteDate == null &&
      location == null &&
      isPinned == null &&
      flag == null;
```

- [ ] **Step 10: Extend the repository**

In `local_hmm_note_repository.dart`, add to `IHmmNoteRepository` after `Future<HmmNote> setParentNote(int id, int? parentNoteId);`:

```dart

  /// Pin or unpin. A real edit: bumps lastModifiedDate + version and
  /// notifies sync, leaving every other column untouched.
  Future<HmmNote> setPinned(int id, bool pinned);

  /// Set a flag colour (0–6; any other int is stored verbatim) or clear it
  /// with null. Same edit semantics as [setPinned].
  Future<HmmNote> setFlagColor(int id, int? flagColor);

  /// Undo a soft delete: clears deletedAt and stamps lastModifiedDate
  /// strictly later than the tombstone (see [restoreStamp]) so the restore
  /// wins last-writer-wins on other devices. A live note is returned
  /// unchanged. Throws [StateError] when the note does not exist.
  Future<HmmNote> restoreNote(int id);
```

In `createNote`, add after `lastModifiedDate: Value(now),`:

```dart
          isPinned: Value(input.isPinned),
          flagColor: Value(input.flagColor),
```

In `updateNote`, add after the `locationLabel:` entry:

```dart
      isPinned: patch.isPinned != null
          ? Value(patch.isPinned!)
          : const Value.absent(),
      // null = don't touch; NoteFlagPatch(null) writes SQL NULL (clears).
      flagColor:
          patch.flag != null ? Value(patch.flag!.color) : const Value.absent(),
```

After the `setParentNote` method add:

```dart

  @override
  Future<HmmNote> setPinned(int id, bool pinned) =>
      updateNote(id, HmmNoteUpdate(isPinned: pinned));

  @override
  Future<HmmNote> setFlagColor(int id, int? flagColor) =>
      updateNote(id, HmmNoteUpdate(flag: NoteFlagPatch(flagColor)));

  @override
  Future<HmmNote> restoreNote(int id) async {
    final author = await _currentAuthor();
    final row = await (_db.select(_db.notes)
          ..where((n) => n.id.equals(id) & n.authorId.equals(author.id)))
        .getSingleOrNull();
    if (row == null) throw StateError('Note $id not found');
    if (row.deletedAt == null) return HmmNoteMapper.fromDriftRow(row);

    final stamp = restoreStamp(
        row.lastModifiedDate ?? row.createDate, DateTime.now().toUtc());
    await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        deletedAt: const Value(null),
        lastModifiedDate: Value(stamp),
        version: Value(_versionStamp()),
      ),
    );
    final note = (await getNoteById(id))!;
    _onLocalWrite?.call();
    return note;
  }
```

At the end of the file (top level, after the provider) add:

```dart

/// The lastModifiedDate a restore writes. Drift stores DateTime as whole
/// unix seconds, so "later than the tombstone" must be at least the next
/// whole second — a restore in the same second as its delete would otherwise
/// tie, and last-writer-wins keeps the tombstone on every other device.
DateTime restoreStamp(DateTime previous, DateTime now) {
  final prev = previous.toUtc();
  final floored = DateTime.fromMillisecondsSinceEpoch(
      prev.millisecondsSinceEpoch ~/ 1000 * 1000,
      isUtc: true);
  final next = floored.add(const Duration(seconds: 1));
  final candidate = now.toUtc();
  return candidate.isBefore(next) ? next : candidate;
}
```

- [ ] **Step 11: Keep the test fake compiling**

In `test/features/notes/states/mutate_note_state_test.dart`, add to `_FakeNoteRepo` after `getUnattachedNotes`:

```dart
  @override
  Future<HmmNote> setPinned(int id, bool pinned) async => stored;
  @override
  Future<HmmNote> setFlagColor(int id, int? flagColor) async => stored;
  @override
  Future<HmmNote> restoreNote(int id) async => stored;
```

(All other `IHmmNoteRepository` fakes under `test/` already use `noSuchMethod`.)

- [ ] **Step 12: Run tests and analyze**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/notes/note_flag_test.dart test/core/data/local/
flutter test test/features/notes/
flutter analyze
```
Expected: all pass; analyze reports only the 2 pre-existing infos.

- [ ] **Step 13: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/core/data/local/database.dart lib/core/data/local/database.g.dart lib/core/notes/note_flag.dart \
  lib/features/notes/data/models/hmm_note.dart lib/features/notes/data/mappers/hmm_note_mapper.dart \
  lib/core/data/hmm_note_input.dart lib/core/data/local/local_hmm_note_repository.dart \
  test/features/notes/states/mutate_note_state_test.dart test/core/data/local/tags_schema_v6_test.dart \
  test/core/data/local/notes_schema_v9_migration_test.dart \
  test/core/data/local/local_hmm_note_repository_pin_flag_test.dart test/core/notes/note_flag_test.dart
git commit -m "$(cat <<'MSG'
feat(notes): schema v9 pin + flag columns, repository setPinned/setFlagColor/restoreNote

Additive v8→v9 migration. Restore stamps the next whole second after the
tombstone so it cannot tie under Drift's 1-second DateTime resolution.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 6: Client — OneDrive blob carries pin/flag; absent keys keep; restore propagation pinned by tests

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/sync_orchestrator.dart` (`_applyPulledNote` lines 404–503; `_noteRowToBlob` body lines 777–802)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_pin_flag_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_restore_test.dart` (create)

**Interfaces:**
- Consumes: `SyncOrchestrator({provider, db, meta, vaultStore})`, `noopVaultStore` (`test/core/data/sync/onedrive_test_fakes.dart`), `LocalHmmNoteRepository.restoreNote` (Task 5).
- Produces: note blob keys `isPinned: bool`, `flagColor: int?`. Pull: `isPinned` present (bool) ⇒ apply, absent ⇒ keep; `flagColor` present ⇒ apply (null clears), absent ⇒ keep; `tags` present ⇒ set-replace, absent ⇒ keep (was: clear).

- [ ] **Step 1: Write the failing pin/flag sync tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_pin_flag_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;
  late SyncOrchestrator orchestrator;

  final t0 = DateTime.utc(2026, 10, 1, 9);
  final t1 = t0.add(const Duration(hours: 1));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeProvider();
    orchestrator = SyncOrchestrator(
        provider: provider, db: db, meta: SyncMetaRepository(), vaultStore: noopVaultStore);
  });

  tearDown(() => db.close());

  Future<int> insertLocal({bool pinned = false, int? flag}) =>
      db.into(db.notes).insert(NotesCompanion.insert(
            uuid: const Value('n1'),
            subject: 'mine',
            authorId: 1,
            createDate: Value(t0),
            lastModifiedDate: Value(t0),
            isPinned: Value(pinned),
            flagColor: Value(flag),
          ));

  Future<Note> row(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

  void remoteNewer(Map<String, dynamic> body) {
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: t1, deviceId: 'other',
      notes: [ManifestEntry(id: 'n1', updatedAt: t1, deleted: false)],
      attachments: const [],
    );
    provider.remoteBodies['n1'] = {
      'uuid': 'n1',
      'subject': 'mine (edited elsewhere)',
      'createDate': t0.toIso8601String(),
      'lastModifiedDate': t1.toIso8601String(),
      ...body,
    };
  }

  test('outbound: the pushed blob carries isPinned and flagColor', () async {
    await insertLocal(pinned: true, flag: 4);
    provider.remoteManifest = SyncManifest(
        version: 1, generatedAt: t0, deviceId: 'x', notes: const [], attachments: const []);

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(provider.pushedBodies['n1']!['isPinned'], isTrue);
    expect(provider.pushedBodies['n1']!['flagColor'], 4);
  });

  test('outbound: an unflagged note sends an explicit null flagColor', () async {
    await insertLocal();
    provider.remoteManifest = SyncManifest(
        version: 1, generatedAt: t0, deviceId: 'x', notes: const [], attachments: const []);

    await orchestrator.syncNow();

    final body = provider.pushedBodies['n1']!;
    expect(body.containsKey('flagColor'), isTrue);
    expect(body['flagColor'], isNull);
    expect(body['isPinned'], isFalse);
  });

  test('inbound update with pin/flag keys applies them (null clears the flag)',
      () async {
    final id = await insertLocal(pinned: true, flag: 2);
    remoteNewer({'isPinned': false, 'flagColor': null, 'tags': const <String>[]});

    await orchestrator.syncNow();

    final r = await row(id);
    expect(r.isPinned, isFalse);
    expect(r.flagColor, isNull);
  });

  test('inbound update without pin/flag keys keeps the local pin and flag '
      '(older client edit)', () async {
    final id = await insertLocal(pinned: true, flag: 3);
    remoteNewer({'tags': const <String>[]}); // older app: no isPinned/flagColor

    await orchestrator.syncNow();

    final r = await row(id);
    expect(r.subject, 'mine (edited elsewhere)', reason: 'the edit applied');
    expect(r.isPinned, isTrue);
    expect(r.flagColor, 3);
  });

  test('inbound insert without pin/flag keys lands unpinned and unflagged',
      () async {
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: t1, deviceId: 'other',
      notes: [ManifestEntry(id: 'r1', updatedAt: t1, deleted: false)],
      attachments: const [],
    );
    provider.remoteBodies['r1'] = {
      'uuid': 'r1', 'subject': 'from old app', 'createDate': t1.toIso8601String(),
    };

    await orchestrator.syncNow();

    final r = await (db.select(db.notes)..where((n) => n.uuid.equals('r1'))).getSingle();
    expect(r.isPinned, isFalse);
    expect(r.flagColor, isNull);
  });

  test('inbound unknown flag value is kept verbatim', () async {
    final id = await insertLocal();
    remoteNewer({'isPinned': true, 'flagColor': 42});

    await orchestrator.syncNow();

    expect((await row(id)).flagColor, 42);
  });

  test('an absent tags key keeps membership; a present empty list clears it',
      () async {
    final id = await insertLocal();
    final tags = LocalTagRepository(db);
    await tags.setTagsForNote(id, ['work']);

    remoteNewer({}); // no 'tags' key
    await orchestrator.syncNow();
    expect(await tags.tagNamesForNote(id), ['work']);

    final t2 = t1.add(const Duration(hours: 1));
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: t2, deviceId: 'other',
      notes: [ManifestEntry(id: 'n1', updatedAt: t2, deleted: false)],
      attachments: const [],
    );
    provider.remoteBodies['n1'] = {
      'uuid': 'n1', 'subject': 'mine', 'lastModifiedDate': t2.toIso8601String(),
      'tags': const <String>[],
    };
    await orchestrator.syncNow();
    expect(await tags.tagNamesForNote(id), isEmpty);
  });
}

class _FakeProvider extends CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> pushedBodies = {};
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  SyncManifest? lastPushedManifest;

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
  Future<void> pushManifest(SyncManifest manifest) async => lastPushedManifest = manifest;
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async => pushedBodies[id] = body;
}
```

- [ ] **Step 2: Write the restore-propagation tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_restore_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

/// Pins the cloudStorage restore semantics verified 2026-10-18 (spec "Data
/// model and sync → Recently Deleted"): a restore is "clear deletedAt with a
/// newer lastModifiedDate" and travels by last-writer-wins, EXCEPT against a
/// tombstone with an equal-or-later timestamp. On a tie the receiving
/// device keeps what it has (`_maybePullNote`: `!entry.updatedAt.isAfter(local)`
/// ⇒ local wins).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;
  late SyncOrchestrator orchestrator;
  final t = DateTime.utc(2026, 10, 1, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeProvider();
    orchestrator = SyncOrchestrator(
        provider: provider, db: db, meta: SyncMetaRepository(), vaultStore: noopVaultStore);
  });

  tearDown(() => db.close());

  Future<int> insert({required DateTime modified, DateTime? deletedAt}) =>
      db.into(db.notes).insert(NotesCompanion.insert(
            uuid: const Value('n1'),
            subject: 'note',
            authorId: 1,
            createDate: Value(t),
            lastModifiedDate: Value(modified),
            deletedAt: Value(deletedAt),
          ));

  Future<Note> row(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

  void remote({required DateTime at, required bool deleted}) {
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: at, deviceId: 'other',
      notes: [ManifestEntry(id: 'n1', updatedAt: at, deleted: deleted)],
      attachments: const [],
    );
    if (!deleted) {
      provider.remoteBodies['n1'] = {
        'uuid': 'n1', 'subject': 'restored elsewhere',
        'lastModifiedDate': at.toIso8601String(), 'deletedAt': null,
        'tags': const <String>[],
      };
    }
  }

  test('a local restore newer than the remote tombstone stays live and is pushed',
      () async {
    final id = await insert(modified: t.add(const Duration(seconds: 5)));
    remote(at: t, deleted: true);

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect((await row(id)).deletedAt, isNull);
    expect(provider.pushedBodies['n1']!['deletedAt'], isNull);
    final entry = provider.lastPushedManifest!.notes.single;
    expect(entry.deleted, isFalse);
  });

  test('a newer remote restore revives the local tombstone', () async {
    final id = await insert(modified: t, deletedAt: t);
    remote(at: t.add(const Duration(seconds: 1)), deleted: false);

    await orchestrator.syncNow();

    final r = await row(id);
    expect(r.deletedAt, isNull);
    expect(r.subject, 'restored elsewhere');
  });

  test('equal timestamps keep the local tombstone (documented tie)', () async {
    final id = await insert(modified: t, deletedAt: t);
    remote(at: t, deleted: false);

    await orchestrator.syncNow();

    expect((await row(id)).deletedAt, isNotNull,
        reason: 'LWW tie: the receiver keeps what it has');
  });

  test('a restore made in the same second as its delete still wins on peers',
      () async {
    final author = await (db.select(db.authors)).getSingle();
    final repo = LocalHmmNoteRepository(db, () async => author);
    final created = await repo.createNote(const HmmNoteCreate(subject: 's', catalogId: 1));
    await repo.deleteNote(created.id);
    final tombstone = (await repo.getNoteById(created.id))!;
    // A peer already holds the tombstone at exactly the delete's timestamp.
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: tombstone.lastModifiedDate!, deviceId: 'peer',
      notes: [ManifestEntry(
          id: created.uuid, updatedAt: tombstone.lastModifiedDate!.toUtc(), deleted: true)],
      attachments: const [],
    );

    await repo.restoreNote(created.id); // immediately: same wall-clock second

    await orchestrator.syncNow();
    final pushed = provider.lastPushedManifest!.notes.single;
    expect(pushed.deleted, isFalse);
    expect(pushed.updatedAt.isAfter(tombstone.lastModifiedDate!.toUtc()), isTrue,
        reason: 'strictly newer, so the peer applies it instead of tying');
  });
}

class _FakeProvider extends CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> pushedBodies = {};
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  SyncManifest? lastPushedManifest;

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
  Future<void> pushManifest(SyncManifest manifest) async => lastPushedManifest = manifest;
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async => pushedBodies[id] = body;
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/sync/sync_orchestrator_pin_flag_test.dart test/core/data/sync/sync_orchestrator_restore_test.dart
```
Expected: the pin/flag file FAILS — `outbound: the pushed blob carries isPinned and flagColor` (`Expected: true Actual: <null>`), `inbound update with pin/flag keys applies them` (`isPinned` still true), `an absent tags key keeps membership` (`Expected: ['work'] Actual: []`). The restore file already PASSES: it pins existing last-writer-wins behaviour plus Task 5's `restoreStamp`. If any restore test fails here, stop and investigate before changing the orchestrator.

- [ ] **Step 4: Implement the blob keys and absent-keeps pull**

In `sync_orchestrator.dart` `_noteRowToBlob`, add after `'attachments': n.attachments,`:

```dart
        // Pin + flag (Notes redesign slice 1). Older clients omit them; the
        // inbound apply keeps the stored value when a key is absent.
        'isPinned': n.isPinned,
        'flagColor': n.flagColor,
```

In `_applyPulledNote`, after `final attachmentsJson = body['attachments'] as String?;` add:

```dart

    // Pin + flag: present key ⇒ apply (a null flagColor clears), absent key
    // (an older client) ⇒ keep the stored value.
    final hasPinned = body['isPinned'] is bool;
    final pinned = hasPinned ? body['isPinned'] as bool : false;
    final hasFlag = body.containsKey('flagColor');
    final flagColor = (body['flagColor'] as num?)?.toInt();
```

In the `existing != null` update companion, add after the `attachments:` entry:

```dart
        isPinned: hasPinned ? Value(pinned) : const Value.absent(),
        flagColor: hasFlag ? Value(flagColor) : const Value.absent(),
```

In the insert companion, add after `attachments: Value(attachmentsJson),`:

```dart
              isPinned: Value(pinned),
              flagColor: Value(flagColor),
```

Replace the tag-membership tail

```dart
    // Rebuild tag membership from the note body (set-replace). The body's
    // tag list is the complete current set; absence means removal.
    final tagNames =
        (body['tags'] as List?)?.whereType<String>().toList() ??
            const <String>[];
    await _tagRepo.setTagsForNote(childId, tagNames);
```

with

```dart
    // Rebuild tag membership from the note body (set-replace) when the body
    // carries a `tags` list — it is then the complete current set. An absent
    // key (an older client, or a server that predates note tags) keeps the
    // local membership, like every other optional key.
    if (body.containsKey('tags')) {
      final tagNames =
          (body['tags'] as List?)?.whereType<String>().toList() ??
              const <String>[];
      await _tagRepo.setTagsForNote(childId, tagNames);
    }
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/sync/
```
Expected: `All tests passed!`.

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/core/data/sync/sync_orchestrator.dart \
  test/core/data/sync/sync_orchestrator_pin_flag_test.dart test/core/data/sync/sync_orchestrator_restore_test.dart
git commit -m "$(cat <<'MSG'
feat(sync): OneDrive note blob carries isPinned/flagColor; absent keys keep

An older client's blob (no pin/flag/tags keys) no longer unpins, unflags or
untags on pull. Restore propagation and the equal-timestamp tie are pinned
by tests.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 7: Client — `ApiSyncProvider` sends/reads pin/flag, restores via the undelete endpoint, syncs tags

Note: there is no cloudApi note *repository* in the app today — `hmmNoteRepositoryProvider` throws `UnimplementedError` for `DataMode.cloudApi` (`lib/core/data/repository_providers.dart:38`). Notes reach the API only through `SyncOrchestrator` + `ApiSyncProvider` over the local Drift store, so that is where slice 1 wires the cloudApi side.

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/api_sync_provider.dart` (imports line 19–28; fields after line 61; `pushNoteBody` 173–224; `_createNote` 289–304; `_updateNote` 306–315; `_orchestratorBodyFromApiNote` 369–384; `pullTags`/`pushTags` 414–424)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/api_sync_provider_slice1_test.dart` (create)

**Interfaces:**
- Consumes (server, Tasks 1–4): `ApiNote.isPinned/flagColor/tagNames`, `PUT /notes/{id}` with `isPinned`/`flagColor`, `POST /notes/{id}/restore`, `PUT /notes/{id}/tags {"names": [...]}`, `GET|POST /tags`, `DELETE /tags/{id}`.
- Produces: pulled body keys `isPinned`, `flagColor`, `tags` only when the server sent them; push: restore-then-PUT for a server tombstone being revived; no DELETE for an already-deleted server note; tag definitions doc `{'version': 1, 'tags': [{name, description, is_activated, last_modified (epoch), deleted: false}]}`.

- [ ] **Step 1: Write the failing tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/api_sync_provider_slice1_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/api_sync_provider.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiSyncProvider provider;
  late List<String> writes;
  late Map<String, Object?> sent;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    provider = ApiSyncProvider(client: ApiClient(dio), tokenService: _FakeIdpTokenService());
    writes = [];
    sent = {};
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (o.method != 'GET') {
        writes.add('${o.method} ${o.path}');
        sent['${o.method} ${o.path}'] = o.data;
      }
      h.next(o);
    }));
  });

  void existing(String uuid, Map<String, dynamic> note) => adapter.onGet(
      '/notes/by-uuid/$uuid', (s) => s.reply(200, {'uuid': uuid, ...note}));

  group('pull', () {
    test('pin, flag and tag names come through when the server sends them', () async {
      existing('abc', {
        'id': 7, 'subject': 's', 'content': 'c', 'catalogName': 'General',
        'lastModifiedDate': '2026-10-18T10:00:00Z', 'isDeleted': false,
        'isPinned': true, 'flagColor': 2, 'tagNames': ['work'],
      });

      final body = (await provider.pullNoteBody('abc'))!;

      expect(body['isPinned'], isTrue);
      expect(body['flagColor'], 2);
      expect(body['tags'], ['work']);
    });

    test('an explicit null flagColor stays a present key (clears on apply)', () async {
      existing('abc', {'id': 7, 'subject': 's', 'isPinned': false, 'flagColor': null, 'tagNames': []});

      final body = (await provider.pullNoteBody('abc'))!;

      expect(body.containsKey('flagColor'), isTrue);
      expect(body['flagColor'], isNull);
      expect(body['tags'], isEmpty);
    });

    test('an old server (no pin/flag/tag keys) yields a body without those keys', () async {
      existing('abc', {'id': 7, 'subject': 's', 'content': 'c', 'isDeleted': false});

      final body = (await provider.pullNoteBody('abc'))!;

      expect(body.containsKey('isPinned'), isFalse);
      expect(body.containsKey('flagColor'), isFalse);
      expect(body.containsKey('tags'), isFalse);
    });
  });

  group('push', () {
    test('update sends isPinned and flagColor (null included)', () async {
      existing('u', {'id': 42});
      adapter.onPut('/notes/42', (s) => s.reply(204, null), data: Matchers.any);

      await provider.pushNoteBody('u', {'subject': 's', 'content': 'c', 'isPinned': true, 'flagColor': null});

      final payload = sent['PUT /notes/42'] as Map<String, dynamic>;
      expect(payload['isPinned'], isTrue);
      expect(payload.containsKey('flagColor'), isTrue);
      expect(payload['flagColor'], isNull);
      expect(writes, ['PUT /notes/42'], reason: 'no tags key ⇒ no tags call');
    });

    test('create sends pin/flag and pushes tags to the new id', () async {
      adapter.onGet('/notes/by-uuid/new', (s) => s.reply(404, {'detail': 'nf'}));
      adapter.onGet('/authors', (s) => s.reply(200, {'value': [{'id': 3}]}));
      adapter.onGet('/notecatalogs', (s) => s.reply(200, {'value': [{'id': 1, 'name': 'General'}]}));
      adapter.onPost('/notes', (s) => s.reply(201, {'id': 99, 'uuid': 'new'}), data: Matchers.any);
      adapter.onPut('/notes/99/tags', (s) => s.reply(200, ['work']), data: Matchers.any);

      await provider.pushNoteBody('new', {
        'subject': 's', 'content': 'c', 'catalogName': 'General',
        'isPinned': true, 'flagColor': 5, 'tags': ['work'],
      });

      final create = sent['POST /notes'] as Map<String, dynamic>;
      expect(create['isPinned'], isTrue);
      expect(create['flagColor'], 5);
      expect(writes, ['POST /notes', 'PUT /notes/99/tags']);
      expect(sent['PUT /notes/99/tags'], {'names': ['work']});
    });

    test('a restored note is undeleted on the server before it is updated', () async {
      existing('r', {'id': 8, 'isDeleted': true});
      adapter.onPost('/notes/8/restore', (s) => s.reply(200, {'id': 8, 'uuid': 'r', 'isDeleted': false}),
          data: Matchers.any);
      adapter.onPut('/notes/8', (s) => s.reply(204, null), data: Matchers.any);

      await provider.pushNoteBody('r', {'subject': 'back', 'content': 'c', 'deletedAt': null});

      expect(writes, ['POST /notes/8/restore', 'PUT /notes/8']);
    });

    test('restoring against a server without the restore endpoint fails clearly', () async {
      existing('r', {'id': 8, 'isDeleted': true});
      adapter.onPost('/notes/8/restore', (s) => s.reply(404, {'detail': 'nf'}), data: Matchers.any);

      await expectLater(
        provider.pushNoteBody('r', {'subject': 'back', 'content': 'c'}),
        throwsA(isA<ApiSyncProviderException>()
            .having((e) => e.message, 'message', contains('restore'))),
      );
      expect(writes, ['POST /notes/8/restore'], reason: 'never PUT a deleted note');
    });

    test('a tombstone for a note already deleted on the server is a no-op', () async {
      existing('gone', {'id': 9, 'isDeleted': true});
      // No DELETE mock: a DELETE would fail the test.

      await provider.pushNoteBody('gone', {'subject': 's', 'deletedAt': '2026-10-18T10:00:00Z'});

      expect(writes, isEmpty);
    });

    test('tags are set-replaced on the server after an update', () async {
      existing('u', {'id': 42});
      adapter.onPut('/notes/42', (s) => s.reply(204, null), data: Matchers.any);
      adapter.onPut('/notes/42/tags', (s) => s.reply(200, ['a', 'b']), data: Matchers.any);

      await provider.pushNoteBody('u', {'subject': 's', 'content': 'c', 'tags': ['a', 'b']});

      expect(writes, ['PUT /notes/42', 'PUT /notes/42/tags']);
      expect(sent['PUT /notes/42/tags'], {'names': ['a', 'b']});
    });

    test('an old server without the tags endpoint does not fail the push', () async {
      existing('u', {'id': 42});
      adapter.onPut('/notes/42', (s) => s.reply(204, null), data: Matchers.any);
      adapter.onPut('/notes/42/tags', (s) => s.reply(404, {'detail': 'nf'}), data: Matchers.any);

      await provider.pushNoteBody('u', {'subject': 's', 'content': 'c', 'tags': ['a']});

      expect(writes, ['PUT /notes/42', 'PUT /notes/42/tags']);
    });
  });

  group('tag definitions', () {
    test('pullTags maps server tags with an epoch timestamp', () async {
      adapter.onGet('/tags', (s) => s.reply(200, {'value': [
            {'id': 1, 'name': 'work', 'description': 'job'},
          ]}));

      final doc = (await provider.pullTags())!;

      final tag = (doc['tags'] as List).single as Map<String, dynamic>;
      expect(tag['name'], 'work');
      expect(tag['description'], 'job');
      expect(tag['is_activated'], isTrue);
      expect(tag['deleted'], isFalse);
      expect(DateTime.parse(tag['last_modified'] as String),
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });

    test('pushTags creates missing live tags and deactivates tombstoned ones', () async {
      adapter.onGet('/tags', (s) => s.reply(200, {'value': [
            {'id': 1, 'name': 'work'},
            {'id': 2, 'name': 'keep'},
          ]}));
      adapter.onPost('/tags', (s) => s.reply(201, {'id': 3, 'name': 'home'}), data: Matchers.any);
      adapter.onDelete('/tags/1', (s) => s.reply(204, null));
      await provider.pullTags();

      await provider.pushTags({
        'tags': [
          {'name': 'home', 'deleted': false},
          {'name': 'Work', 'deleted': true},
          {'name': 'keep', 'deleted': false},
        ],
      });

      expect(writes, ['POST /tags', 'DELETE /tags/1']);
      expect((sent['POST /tags'] as Map)['name'], 'home');
    });
  });
}

class _FakeIdpTokenService implements IdpTokenService {
  @override
  Future<Map<String, dynamic>?> getStoredClaims() async => {'sub': 'user-1'};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_FakeIdpTokenService.${invocation.memberName} not stubbed.');
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/sync/api_sync_provider_slice1_test.dart
```
Expected: FAIL — e.g. `pin, flag and tag names come through` (`Expected: true Actual: <null>`), `a restored note is undeleted` (`Expected: ['POST /notes/8/restore', 'PUT /notes/8'] Actual: ['PUT /notes/8']`), `pullTags maps server tags` (`Null check operator used on a null value`).

- [ ] **Step 3: Implement**

In `api_sync_provider.dart` add `import 'package:flutter/foundation.dart' show debugPrint;` to the imports. After the `_catalogIdByName` field add:

```dart

  /// Lower-cased tag name → server tag id, filled by [pullTags] and used by
  /// [pushTags] in the same sync run (the orchestrator calls them in order).
  final Map<String, int> _serverTagIdByName = {};

  /// The server keeps no per-tag modification time; epoch 0 means a server
  /// tag only fills a gap locally and never overrides a local edit or
  /// tombstone in `TagSyncService`'s last-writer-wins merge.
  static final DateTime _tagEpoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
```

Replace `pushNoteBody` (from `@override Future<void> pushNoteBody(` to its closing brace) with:

```dart
  @override
  Future<void> pushNoteBody(String uuid, Map<String, dynamic> body) async {
    if (uuid.isEmpty) {
      throw const ApiSyncProviderException(
        'pushNoteBody requires a non-empty uuid.',
      );
    }

    // Existence check first — the orchestrator hands us the same
    // method for creates and updates, and the server splits the
    // two onto different routes. by-uuid is a single indexed
    // probe, cheap enough to do per push at v1 volumes.
    Map<String, dynamic>? existing;
    try {
      final probe = await _dio.get<Map<String, dynamic>>(
        '/notes/by-uuid/$uuid',
        queryParameters: {'includeDeleted': true},
      );
      existing = probe.data;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
      existing = null;
    }

    final deletedAtRaw = body['deletedAt'] as String?;
    final isDeletedPush = deletedAtRaw != null && deletedAtRaw.isNotEmpty;

    if (existing == null) {
      // Server-side delete-only with no row to delete is a no-op —
      // pushing a tombstone for a note the server never saw would
      // create it just to delete it.
      if (isDeletedPush) return;
      await _createNote(uuid, body);
      return;
    }

    final existingId = existing['id'] as int?;
    if (existingId == null) {
      throw const ApiSyncProviderException(
        'Server returned a note without an id during push existence check.',
      );
    }
    final serverDeleted = (existing['isDeleted'] as bool?) ?? false;

    if (isDeletedPush) {
      // Already a tombstone on the server: nothing to do (re-deleting used
      // to 500 because the controller cannot load a deleted note).
      if (serverDeleted) return;
      await _dio.delete<void>('/notes/$existingId');
      return;
    }

    if (serverDeleted) {
      // A restore (Recently Deleted → Undo/Restore). The server refuses a
      // PUT on a soft-deleted note, so flip IsDeleted back first.
      await _restoreNote(existingId);
    }
    await _updateNote(existingId, uuid, body);
    await _pushTagMembership(existingId, body);
  }
```

Replace `_createNote` and `_updateNote` with:

```dart
  Future<void> _createNote(String uuid, Map<String, dynamic> body) async {
    final authorId = await _resolveAuthorId();
    final catalogName = body['catalogName'] as String?;
    final catalogId = catalogName != null && catalogName.isNotEmpty
        ? await _resolveCatalogId(catalogName)
        : 0;
    final payload = <String, dynamic>{
      'uuid': uuid,
      'subject': body['subject'] ?? '(untitled)',
      'content': body['content'] ?? '',
      'authorId': authorId,
      'catalogId': catalogId,
      'description': body['description'],
      ..._pinFlagFields(body),
    };
    final resp = await _dio.post<dynamic>('/notes', data: payload);
    final data = resp.data;
    final newId = data is Map ? data['id'] as int? : null;
    if (newId != null) await _pushTagMembership(newId, body);
  }

  Future<void> _updateNote(
      int existingId, String uuid, Map<String, dynamic> body) async {
    final payload = <String, dynamic>{
      'uuid': uuid,
      'subject': body['subject'] ?? '(untitled)',
      'content': body['content'] ?? '',
      'description': body['description'],
      ..._pinFlagFields(body),
    };
    await _dio.put<void>('/notes/$existingId', data: payload);
  }

  /// Pin/flag go on the wire only when the orchestrator's body carries them,
  /// and then always as present keys: the server keeps the stored value for
  /// an absent key and clears the flag for an explicit null.
  static Map<String, dynamic> _pinFlagFields(Map<String, dynamic> body) => {
        if (body.containsKey('isPinned')) 'isPinned': body['isPinned'] ?? false,
        if (body.containsKey('flagColor')) 'flagColor': body['flagColor'],
      };

  Future<void> _restoreNote(int id) async {
    try {
      await _dio.post<void>('/notes/$id/restore');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405) {
        throw const ApiSyncProviderException(
          'The server cannot restore deleted notes yet (no /notes/{id}/restore). '
          'Deploy the latest Hmm API, then sync again.',
        );
      }
      rethrow;
    }
  }

  /// Set-replace the note's tags on the server when the body carries a
  /// `tags` list (the complete set, as in cloudStorage).
  Future<void> _pushTagMembership(int noteId, Map<String, dynamic> body) async {
    if (!body.containsKey('tags')) return;
    final names =
        (body['tags'] as List?)?.whereType<String>().toList() ?? const <String>[];
    try {
      await _dio.put<void>('/notes/$noteId/tags', data: {'names': names});
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405) {
        // Server predates note tags. The note itself synced; its tags follow
        // once the server is updated (the note is re-pushed on its next edit).
        debugPrint('ApiSyncProvider: no note-tags endpoint ($code) for note $noteId');
        return;
      }
      rethrow;
    }
  }
```

Replace `_orchestratorBodyFromApiNote` with:

```dart
  static Map<String, dynamic> _orchestratorBodyFromApiNote(
      Map<String, dynamic> apiNote) {
    final isDeleted = (apiNote['isDeleted'] as bool?) ?? false;
    final modifiedRaw = apiNote['lastModifiedDate'] as String?;
    return <String, dynamic>{
      'uuid': apiNote['uuid'],
      'subject': apiNote['subject'],
      'content': apiNote['content'],
      'catalogName': apiNote['catalogName'],
      'parentNoteUuid': null,
      'description': apiNote['description'],
      'createDate': apiNote['createDate'],
      'lastModifiedDate': modifiedRaw,
      'deletedAt': isDeleted ? modifiedRaw : null,
      // Only what the server actually sent: an older server has none of
      // these keys, and an absent key makes the orchestrator keep the local
      // pin, flag and tags instead of wiping them.
      if (apiNote.containsKey('isPinned')) 'isPinned': apiNote['isPinned'],
      if (apiNote.containsKey('flagColor')) 'flagColor': apiNote['flagColor'],
      if (apiNote['tagNames'] is List)
        'tags': (apiNote['tagNames'] as List).whereType<String>().toList(),
    };
  }
```

Replace the `// ---- Tags (Phase 4) ----` comment block and the two tag methods with:

```dart
  // ---- Tags ----
  //
  // Definitions come from /v1/tags (no per-tag timestamps on the server, see
  // [_tagEpoch]); membership rides each note push (PUT /notes/{id}/tags) and
  // pull (ApiNote.tagNames).

  @override
  Future<Map<String, dynamic>?> pullTags() async {
    _serverTagIdByName.clear();
    final tags = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final resp = await _dio.get<dynamic>(
        '/tags',
        queryParameters: {'PageNumber': page, 'PageSize': 100},
      );
      for (final raw in _unwrapValueList(resp.data)) {
        if (raw is! Map) continue;
        final name = (raw['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        final id = raw['id'] as int?;
        if (id != null) _serverTagIdByName[name.toLowerCase()] = id;
        tags.add({
          'name': name,
          'description': raw['description'],
          'is_activated': (raw['isActivated'] as bool?) ?? true,
          'last_modified': _tagEpoch.toIso8601String(),
          'deleted': false,
        });
      }
      final totalPages =
          _readPaginationHeader(resp.headers)?['totalPages'] as int? ?? 1;
      if (page >= totalPages) break;
      page++;
    }
    return {'version': 1, 'tags': tags};
  }

  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {
    final rawTags = (doc['tags'] as List?) ?? const [];
    for (final raw in rawTags) {
      if (raw is! Map) continue;
      final name = (raw['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final key = name.toLowerCase();
      final deleted = (raw['deleted'] as bool?) ?? false;
      final serverId = _serverTagIdByName[key];
      if (deleted) {
        if (serverId == null) continue;
        await _dio.delete<void>('/tags/$serverId'); // deactivates server-side
        _serverTagIdByName.remove(key);
      } else if (serverId == null) {
        final resp = await _dio.post<dynamic>(
          '/tags',
          data: {'name': name, 'description': raw['description']},
        );
        final data = resp.data;
        final id = data is Map ? data['id'] as int? : null;
        if (id != null) _serverTagIdByName[key] = id;
      }
    }
  }
```

Also update the file header comment's wire mapping (lines 5–12) by adding after the `pushManifest` line:

```dart
//   restore        POST /v1/notes/{id}/restore before the PUT when the
//                  server row is soft-deleted but the pushed body is live
//   tags           GET|POST /v1/tags, DELETE /v1/tags/{id} (definitions);
//                  PUT /v1/notes/{id}/tags (membership, set-replace)
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/sync/api_sync_provider_slice1_test.dart test/core/data/sync/api_sync_provider_test.dart
flutter analyze
```
Expected: `All tests passed!`; analyze at the 2 pre-existing infos.

- [ ] **Step 5: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/core/data/sync/api_sync_provider.dart test/core/data/sync/api_sync_provider_slice1_test.dart
git commit -m "$(cat <<'MSG'
feat(sync): cloudApi carries pin/flag/tags and restores through the undelete endpoint

A revived server tombstone is restored before the PUT (which 500'd), a
tombstone already deleted on the server is no longer re-DELETEd, and keys an
old server does not send are left out so local pins, flags and tags survive.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 8: Client — real purge (`NotePurgeService`), provider `purgeNote`, deferred OneDrive purge

Safe behaviour per mode (G6/G9/G11):

| Mode | Local row | Remote | Why |
|------|-----------|--------|-----|
| `local` | hard-deleted (+ tag refs, children detached) | — | nothing else holds it |
| `cloudStorage` | **scrubbed to a content-free tombstone** (`subject = '(deleted)'`, content/attachments/location/pin/flag/catalog/parent cleared, `uuid`/`deletedAt`/`lastModifiedDate` kept) | blob (+ released vault files) deleted **inside the next sync, after the pull** | `_buildManifest` is built from local rows; a hard-deleted row would vanish from the manifest and a device that never saw the delete would re-push its live copy (`_collectMissingFromRemote`). The kept tombstone keeps propagating the delete. Deferring the blob deletion lets the pull first revive a note restored on another device. `lastModifiedDate` is NOT bumped, so peers' 30-day clocks are not reset and a newer restore elsewhere still wins. |
| `cloudApi` | hard-deleted **after** `DELETE /notes/{id}/purge` succeeds (or 404) | server row removed by the purge endpoint (409 if live) | the server is the manifest; the 409 guard means a restore that reached the server first is never destroyed |

Every local write is guarded by `deletedAt = <value just read>`, so a restore that lands between the candidate query and the write wins.

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/sync_models.dart` (add `kTombstoneSubject`)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/cloud_sync_provider.dart` (add `purgeNote`, `NoteLiveOnServerException`)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/onedrive_sync_provider.dart` (after `listAttachmentPaths`, line 75)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/api_sync_provider.dart` (after `listAttachmentPaths`, end of class)
- Create: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/pending_remote_purge_store.dart`
- Create: `/Users/fchy/Projects/hmm_console/lib/core/data/local/note_purge_service.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/sync_orchestrator.dart` (constructor 39–55; tombstone insert line 384; call site before `timer.stop(SyncPhase.pullNotes)` line 271; `metadataClean` line 326; new `_flushRemotePurges`)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/local/note_purge_service_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_remote_purge_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/api_sync_provider_purge_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/onedrive_sync_provider_purge_test.dart` (create)

**Interfaces:**
- Consumes: `collectReferencedVaultPaths(HmmDatabase)` (`lib/core/data/vault/vault_gc.dart`), `IVaultStore.delete`, `baseVaultStoreProvider`, `OneDriveGraphClient.deleteNoteBlob/deleteAttachment`, server `DELETE /notes/{id}/purge` (Task 3).
- Produces (Dart):
  - `const String kTombstoneSubject = '(deleted)';`
  - `class NoteLiveOnServerException implements Exception`
  - `CloudSyncProvider.purgeNote(String uuid, {Set<String> releasedVaultPaths = const {}}) → Future<void>` (default no-op)
  - `class PendingRemotePurgeStore { Future<Map<String, Set<String>>> read(String providerId); Future<void> add(String providerId, String uuid, Set<String> vaultPaths); Future<void> remove(String providerId, String uuid); }`
  - `enum PurgeOutcome { purged, notEligible, keptLiveOnServer, failed }`
  - `class NotePurgeService { static const Duration retention; Future<int> purgeExpired(DateTime now); Future<PurgeOutcome> purgeNow(int id); }`
  - `final notePurgeServiceProvider = Provider<NotePurgeService>`
  - `SyncOrchestrator({..., PendingRemotePurgeStore? pendingPurges})`; sync error `recordType: 'purge'` is non-fatal (cursor still advances).

- [ ] **Step 1: Write the failing service tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/local/note_purge_service_test.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/local/note_purge_service.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/pending_remote_purge_store.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HmmDatabase db;
  late _RecordingVault vault;
  late _FakeProvider provider;
  final now = DateTime.utc(2026, 10, 18, 12);
  final old = now.subtract(const Duration(days: 31));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    vault = _RecordingVault();
    provider = _FakeProvider();
  });

  tearDown(() => db.close());

  NotePurgeService service(DataMode mode) => NotePurgeService(
        db: db,
        mode: mode,
        baseVaultStore: () async => vault,
        provider: mode == DataMode.local ? null : provider,
      );

  String withImages(List<String> paths) => NoteAttachmentsCodec.encode(NoteAttachments(
        images: [for (final p in paths) VaultRef(path: p, contentType: 'image/jpeg', byteSize: 1)],
      ))!;

  Future<int> insert(String uuid,
          {DateTime? deletedAt, String? attachments, int? parentId, int? catalogId}) =>
      db.into(db.notes).insert(NotesCompanion.insert(
            uuid: Value(uuid),
            subject: 'note $uuid',
            content: const Value('body'),
            authorId: 1,
            catalogId: Value(catalogId),
            createDate: Value(old.subtract(const Duration(days: 1))),
            lastModifiedDate: Value(deletedAt ?? old),
            deletedAt: Value(deletedAt),
            attachments: Value(attachments),
            parentNoteId: Value(parentId),
          ));

  Future<Note?> byUuid(String uuid) =>
      (db.select(db.notes)..where((n) => n.uuid.equals(uuid))).getSingleOrNull();

  group('local mode', () {
    test('purgeExpired hard-deletes notes deleted more than 30 days ago, '
        'with their tag refs, detaching children and releasing vault files', () async {
      final id = await insert('gone', deletedAt: old, attachments: withImages(['note-1/a.jpg']));
      await LocalTagRepository(db).setTagsForNote(id, ['work']);
      await insert('child', parentId: id);

      final purged = await service(DataMode.local).purgeExpired(now);

      expect(purged, 1);
      expect(await byUuid('gone'), isNull);
      expect(await (db.select(db.noteTagRefs)..where((r) => r.noteId.equals(id))).get(), isEmpty);
      expect((await byUuid('child'))!.parentNoteId, isNull, reason: 'G12: unattached after purge');
      expect(vault.deleted, ['note-1/a.jpg']);
    });

    test('notes deleted 30 days ago or less are kept', () async {
      await insert('recent', deletedAt: now.subtract(const Duration(days: 29)));
      await insert('edge', deletedAt: now.subtract(const Duration(days: 30)));
      await insert('live');

      expect(await service(DataMode.local).purgeExpired(now), 0);
      expect(await byUuid('recent'), isNotNull);
      expect(await byUuid('edge'), isNotNull);
      expect(await byUuid('live'), isNotNull);
    });

    test('applies to entity notes too (G11)', () async {
      final catalogId = await db.into(db.noteCatalogs).insert(
          NoteCatalogsCompanion.insert(name: 'Hmm.AutomobileMan.GasLog', schema: '{}'));
      await insert('fuel', deletedAt: old, catalogId: catalogId);

      expect(await service(DataMode.local).purgeExpired(now), 1);
      expect(await byUuid('fuel'), isNull);
    });

    test('a vault file another note still references is kept', () async {
      await insert('gone', deletedAt: old, attachments: withImages(['shared.jpg']));
      await insert('keeper', attachments: withImages(['shared.jpg']));

      await service(DataMode.local).purgeExpired(now);

      expect(vault.deleted, isEmpty);
    });

    test('purgeNow purges a recently deleted note and refuses a live one', () async {
      final recent = await insert('recent', deletedAt: now.subtract(const Duration(days: 1)));
      final live = await insert('live');

      expect(await service(DataMode.local).purgeNow(recent), PurgeOutcome.purged);
      expect(await service(DataMode.local).purgeNow(live), PurgeOutcome.notEligible);
      expect(await byUuid('live'), isNotNull);
    });
  });

  group('cloudStorage mode', () {
    test('scrubs to a content-free tombstone, keeps uuid and timestamps, '
        'and queues the remote purge for the next sync', () async {
      final id = await insert('gone', deletedAt: old, attachments: withImages(['note-1/a.jpg']));
      await LocalTagRepository(db).setTagsForNote(id, ['work']);
      final before = (await byUuid('gone'))!;

      expect(await service(DataMode.cloudStorage).purgeExpired(now), 1);

      final stub = (await byUuid('gone'))!;
      expect(stub.subject, kTombstoneSubject);
      expect(stub.content, isNull);
      expect(stub.attachments, isNull);
      expect(stub.deletedAt, before.deletedAt);
      expect(stub.lastModifiedDate, before.lastModifiedDate,
          reason: 'not bumped: peers keep their own 30-day clock');
      expect(await (db.select(db.noteTagRefs)..where((r) => r.noteId.equals(id))).get(), isEmpty);
      expect(provider.purged, isEmpty, reason: 'remote deletion is deferred into sync');
      final pending = await PendingRemotePurgeStore().read('fake');
      expect(pending['gone'], {'note-1/a.jpg'});
      expect(vault.deleted, ['note-1/a.jpg']);
    });

    test('an already scrubbed tombstone is not processed again', () async {
      await insert('gone', deletedAt: old);
      final s = service(DataMode.cloudStorage);

      expect(await s.purgeExpired(now), 1);
      expect(await s.purgeExpired(now.add(const Duration(days: 1))), 0);
    });
  });

  group('cloudApi mode', () {
    test('calls the server purge, then deletes the row', () async {
      await insert('gone', deletedAt: old);

      expect(await service(DataMode.cloudApi).purgeExpired(now), 1);

      expect(provider.purged, ['gone']);
      expect(await byUuid('gone'), isNull);
      expect(vault.deleted, isEmpty, reason: 'the server releases cloudApi vault bytes');
    });

    test('keeps the row when the server says the note is live', () async {
      final id = await insert('gone', deletedAt: old);
      provider.liveOnServer = true;

      expect(await service(DataMode.cloudApi).purgeNow(id), PurgeOutcome.keptLiveOnServer);
      expect(await byUuid('gone'), isNotNull);
    });

    test('keeps the row when the server purge fails', () async {
      final id = await insert('gone', deletedAt: old);
      provider.failure = StateError('offline');

      expect(await service(DataMode.cloudApi).purgeNow(id), PurgeOutcome.failed);
      expect(await byUuid('gone'), isNotNull);
    });

    test('a restore that lands during the purge wins', () async {
      final id = await insert('gone', deletedAt: old);
      provider.duringPurge = () => (db.update(db.notes)..where((n) => n.id.equals(id)))
          .write(NotesCompanion(deletedAt: const Value(null), lastModifiedDate: Value(now)));

      expect(await service(DataMode.cloudApi).purgeNow(id), PurgeOutcome.notEligible);
      final row = (await byUuid('gone'))!;
      expect(row.deletedAt, isNull, reason: 'the guarded delete matched nothing');
    });
  });
}

class _RecordingVault implements IVaultStore {
  final deleted = <String>[];

  @override
  Future<void> putBytes(String relativePath, Uint8List bytes, {String? contentType}) async {}
  @override
  Future<Uint8List> getBytes(String relativePath) async => Uint8List(0);
  @override
  Future<bool> exists(String relativePath) async => true;
  @override
  Future<void> delete(String relativePath) async => deleted.add(relativePath);
  @override
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

class _FakeProvider extends CloudSyncProvider {
  final purged = <String>[];
  bool liveOnServer = false;
  Object? failure;
  Future<void> Function()? duringPurge;

  @override
  String get providerId => 'fake';
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<void> signIn() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<SyncManifest?> pullManifest() async => null;
  @override
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => null;
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}

  @override
  Future<void> purgeNote(String uuid, {Set<String> releasedVaultPaths = const {}}) async {
    if (liveOnServer) throw const NoteLiveOnServerException();
    final f = failure;
    if (f != null) throw f;
    await duringPurge?.call();
    purged.add(uuid);
  }
}
```

- [ ] **Step 2: Write the failing orchestrator + provider tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_remote_purge_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/pending_remote_purge_store.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;
  late PendingRemotePurgeStore pending;
  late SyncMetaRepository meta;
  late SyncOrchestrator orchestrator;
  final t = DateTime.utc(2026, 9, 1, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeProvider();
    pending = PendingRemotePurgeStore();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(
        provider: provider, db: db, meta: meta, vaultStore: noopVaultStore, pendingPurges: pending);
    await db.into(db.notes).insert(NotesCompanion.insert(
          uuid: const Value('p1'),
          subject: kTombstoneSubject,
          authorId: 1,
          createDate: Value(t),
          lastModifiedDate: Value(t),
          deletedAt: Value(t),
        ));
    await pending.add('fake', 'p1', {'note-1/a.jpg'});
  });

  tearDown(() => db.close());

  void remote({required DateTime at, required bool deleted}) {
    provider.remoteManifest = SyncManifest(
      version: 1, generatedAt: at, deviceId: 'peer',
      notes: [ManifestEntry(id: 'p1', updatedAt: at, deleted: deleted)],
      attachments: const [],
    );
  }

  test('purges the remote blob once the tombstone still wins', () async {
    remote(at: t, deleted: true);

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(provider.purged, ['p1']);
    expect(provider.purgedPaths, {'note-1/a.jpg'});
    expect(await pending.read('fake'), isEmpty);
  });

  test('a note restored on another device is revived, never purged remotely', () async {
    final later = t.add(const Duration(seconds: 10));
    remote(at: later, deleted: false);
    provider.remoteBodies['p1'] = {
      'uuid': 'p1', 'subject': 'restored elsewhere', 'content': 'body',
      'lastModifiedDate': later.toIso8601String(), 'deletedAt': null, 'tags': const <String>[],
    };

    await orchestrator.syncNow();

    final row = await (db.select(db.notes)..where((n) => n.uuid.equals('p1'))).getSingle();
    expect(row.deletedAt, isNull);
    expect(row.subject, 'restored elsewhere');
    expect(provider.purged, isEmpty);
    expect(await pending.read('fake'), isEmpty);
  });

  test('a failed remote purge stays pending and does not hold the cursor back', () async {
    remote(at: t, deleted: true);
    provider.failPurge = true;

    final result = await orchestrator.syncNow();

    expect(result.errors.map((e) => e.recordType), ['purge']);
    expect((await pending.read('fake')).keys, ['p1']);
    expect(await meta.getLastPushedAt('fake'), isNotNull);
  });

  test('a vault path another note still references is not deleted remotely', () async {
    await db.into(db.notes).insert(NotesCompanion.insert(
          uuid: const Value('keeper'),
          subject: 'keeper',
          authorId: 1,
          attachments: Value(NoteAttachmentsCodec.encode(NoteAttachments(images: [
            const VaultRef(path: 'note-1/a.jpg', contentType: 'image/jpeg', byteSize: 1),
          ]))),
        ));
    remote(at: t, deleted: true);

    await orchestrator.syncNow();

    expect(provider.purged, ['p1']);
    expect(provider.purgedPaths, isEmpty);
  });
}

class _FakeProvider extends CloudSyncProvider {
  SyncManifest? remoteManifest;
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  final purged = <String>[];
  final purgedPaths = <String>{};
  bool failPurge = false;

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
  Future<void> pushManifest(SyncManifest manifest) async {}
  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async => remoteBodies[id];
  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async {}

  @override
  Future<void> purgeNote(String uuid, {Set<String> releasedVaultPaths = const {}}) async {
    if (failPurge) throw StateError('graph down');
    purged.add(uuid);
    purgedPaths.addAll(releasedVaultPaths);
  }
}
```


Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/api_sync_provider_purge_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/api_sync_provider.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiSyncProvider provider;
  late List<String> deletes;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    provider = ApiSyncProvider(client: ApiClient(dio), tokenService: _FakeIdpTokenService());
    deletes = [];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (o.method == 'DELETE') deletes.add(o.path);
      h.next(o);
    }));
  });

  test('a deleted server note is purged through /purge', () async {
    adapter.onGet('/notes/by-uuid/p1', (s) => s.reply(200, {'id': 5, 'uuid': 'p1', 'isDeleted': true}));
    adapter.onDelete('/notes/5/purge', (s) => s.reply(204, null));

    await provider.purgeNote('p1');

    expect(deletes, ['/notes/5/purge']);
  });

  test('a live server note is never purged', () async {
    adapter.onGet('/notes/by-uuid/p1', (s) => s.reply(200, {'id': 5, 'uuid': 'p1', 'isDeleted': false}));

    await expectLater(provider.purgeNote('p1'), throwsA(isA<NoteLiveOnServerException>()));
    expect(deletes, isEmpty);
  });

  test('a 409 from /purge (restored meanwhile) surfaces as live', () async {
    adapter.onGet('/notes/by-uuid/p1', (s) => s.reply(200, {'id': 5, 'uuid': 'p1', 'isDeleted': true}));
    adapter.onDelete('/notes/5/purge', (s) => s.reply(409, {'detail': 'not deleted'}));

    await expectLater(provider.purgeNote('p1'), throwsA(isA<NoteLiveOnServerException>()));
  });

  test('a note the server never had (or already purged) is done', () async {
    adapter.onGet('/notes/by-uuid/p1', (s) => s.reply(404, {'detail': 'nf'}));

    await provider.purgeNote('p1');

    expect(deletes, isEmpty);
  });

  test('a 404 from /purge is treated as already gone', () async {
    adapter.onGet('/notes/by-uuid/p1', (s) => s.reply(200, {'id': 5, 'uuid': 'p1', 'isDeleted': true}));
    adapter.onDelete('/notes/5/purge', (s) => s.reply(404, {'detail': 'nf'}));

    await provider.purgeNote('p1');

    expect(deletes, ['/notes/5/purge']);
  });
}

class _FakeIdpTokenService implements IdpTokenService {
  @override
  Future<Map<String, dynamic>?> getStoredClaims() async => {'sub': 'user-1'};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_FakeIdpTokenService.${invocation.memberName} not stubbed.');
}
```

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/onedrive_sync_provider_purge_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:hmm_console/core/data/sync/onedrive_sync_provider.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'onedrive_test_fakes.dart';

class _FakeIdpTokenService implements IdpTokenService {
  @override
  Future<Map<String, dynamic>?> getStoredClaims() async => {'sub': 'SUB-1'};
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('purgeNote deletes the note blob and each released vault file', () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true));
    final adapter = DioAdapter(dio: dio);
    const root = '/me/drive/special/approot:/users/SUB-1';
    adapter.onDelete('$root/notes/n1.json', (s) => s.reply(204, null));
    adapter.onDelete('$root/vault/note-1/a.jpg', (s) => s.reply(204, null));
    final deletes = <String>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (o.method == 'DELETE') deletes.add(o.path);
      h.next(o);
    }));
    final graph = OneDriveGraphClient(FakeOneDriveAuth(), () async => 'SUB-1', dio: dio);
    final provider = OneDriveSyncProvider(FakeOneDriveAuth(), graph, _FakeIdpTokenService());

    await provider.purgeNote('n1', releasedVaultPaths: {'note-1/a.jpg'});

    expect(deletes, ['$root/notes/n1.json', '$root/vault/note-1/a.jpg']);
  });
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/local/note_purge_service_test.dart
```
Expected: compile error `Target of URI doesn't exist: 'package:hmm_console/core/data/local/note_purge_service.dart'`.

- [ ] **Step 4: Provider contract**

In `sync_models.dart`, after the `library;` line add:

```dart

/// Subject of a content-free tombstone row: one pulled for a note this device
/// never had, or a cloudStorage note purged after 30 days. The row keeps its
/// uuid and deletedAt so the manifest keeps propagating the delete.
const String kTombstoneSubject = '(deleted)';
```

In `cloud_sync_provider.dart`, add before `abstract class CloudSyncProvider`:

```dart
/// Thrown by [CloudSyncProvider.purgeNote] when the remote copy is live
/// (restored on another device): the caller must keep its local row.
class NoteLiveOnServerException implements Exception {
  const NoteLiveOnServerException();

  @override
  String toString() => 'NoteLiveOnServerException';
}
```

and inside the class, after `listAttachmentPaths`:

```dart

  // ---- Purge ----

  /// Permanently remove [uuid]'s remote copy after a local purge, plus any
  /// [releasedVaultPaths] no local note references any more. Throws
  /// [NoteLiveOnServerException] when the remote copy is live. A remote copy
  /// that is already gone is success. Default: no-op.
  Future<void> purgeNote(String uuid,
      {Set<String> releasedVaultPaths = const {}}) async {}
```

In `onedrive_sync_provider.dart`, after `listAttachmentPaths` add:

```dart

  @override
  Future<void> purgeNote(String uuid,
      {Set<String> releasedVaultPaths = const {}}) async {
    // The manifest keeps the tombstone entry (built from the local stub), so
    // peers still learn about the delete; only the content blob goes.
    await _graph.deleteNoteBlob(uuid);
    for (final path in releasedVaultPaths) {
      await _graph.deleteAttachment(path);
    }
  }
```

In `api_sync_provider.dart`, after `listAttachmentPaths` add:

```dart

  @override
  Future<void> purgeNote(String uuid,
      {Set<String> releasedVaultPaths = const {}}) async {
    if (uuid.isEmpty) return;
    Map<String, dynamic>? existing;
    try {
      final probe = await _dio.get<Map<String, dynamic>>(
        '/notes/by-uuid/$uuid',
        queryParameters: {'includeDeleted': true},
      );
      existing = probe.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return; // never synced, or purged
      rethrow;
    }
    final id = existing?['id'] as int?;
    if (id == null) return;
    if ((existing?['isDeleted'] as bool?) == false) {
      throw const NoteLiveOnServerException();
    }
    try {
      // The server also removes the note's vault folder; releasedVaultPaths
      // is unused here.
      await _dio.delete<void>('/notes/$id/purge');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) return;
      if (code == 409) throw const NoteLiveOnServerException();
      rethrow;
    }
  }
```

- [ ] **Step 5: The pending store**

Create `/Users/fchy/Projects/hmm_console/lib/core/data/sync/pending_remote_purge_store.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// cloudStorage purges whose remote half (note blob + released vault files)
/// waits for the next sync, keyed per provider like the sync cursor. Sync
/// runs it after the pull, so a note restored on another device is revived
/// first and never deleted remotely.
class PendingRemotePurgeStore {
  static String _key(String providerId) => 'sync_pending_remote_purge:$providerId';

  /// uuid → vault paths released when the note was purged locally.
  Future<Map<String, Set<String>>> read(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(providerId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is List)
            e.key as String: (e.value as List).whereType<String>().toSet(),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> add(String providerId, String uuid, Set<String> vaultPaths) async {
    final current = await read(providerId);
    current[uuid] = {...?current[uuid], ...vaultPaths};
    await _write(providerId, current);
  }

  Future<void> remove(String providerId, String uuid) async {
    final current = await read(providerId);
    if (current.remove(uuid) == null) return;
    await _write(providerId, current);
  }

  Future<void> _write(String providerId, Map<String, Set<String>> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await prefs.remove(_key(providerId));
      return;
    }
    await prefs.setString(_key(providerId),
        jsonEncode({for (final e in value.entries) e.key: (e.value.toList()..sort())}));
  }
}
```

- [ ] **Step 6: The purge service**

Create `/Users/fchy/Projects/hmm_console/lib/core/data/local/note_purge_service.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachments/attachment_providers.dart';
import '../attachments/attachment_ref.dart';
import '../attachments/attachment_ref_codec.dart';
import '../data_mode.dart';
import '../sync/cloud_sync_provider.dart';
import '../sync/pending_remote_purge_store.dart';
import '../sync/sync_models.dart';
import '../sync/sync_orchestrator.dart';
import '../vault/vault_gc.dart';
import '../vault/vault_store.dart';
import 'database.dart';

enum PurgeOutcome { purged, notEligible, keptLiveOnServer, failed }

/// Permanently removes soft-deleted notes (Recently Deleted, G6/G9/G11).
///
/// [purgeExpired] covers EVERY soft-deleted note older than [retention] —
/// entity notes too, so deleted gas logs' and cards' photos finally leave the
/// vault. Callers run it outside sync (`NotePurgeScheduler` uses
/// `SyncController.runExclusive`). Per-mode behaviour is in the plan's Task 8
/// table; every write is guarded by the `deletedAt` value just read, so a
/// restore that lands meanwhile always wins.
class NotePurgeService {
  NotePurgeService({
    required HmmDatabase db,
    required DataMode mode,
    required Future<IVaultStore> Function() baseVaultStore,
    CloudSyncProvider? provider,
    PendingRemotePurgeStore? pending,
  })  : _db = db,
        _mode = mode,
        _baseVaultStore = baseVaultStore,
        _provider = provider,
        _pending = pending ?? PendingRemotePurgeStore();

  static const Duration retention = Duration(days: 30);

  final HmmDatabase _db;
  final DataMode _mode;

  /// The store underneath encryption — deleting never needs to decrypt.
  final Future<IVaultStore> Function() _baseVaultStore;
  final CloudSyncProvider? _provider;
  final PendingRemotePurgeStore _pending;

  /// Purge every note soft-deleted more than [retention] before [now].
  /// Returns how many were purged.
  Future<int> purgeExpired(DateTime now) async {
    final cutoff = now.toUtc().subtract(retention);
    final candidates = await (_db.select(_db.notes)
          ..where((n) =>
              n.deletedAt.isNotNull() & n.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    var purged = 0;
    for (final row in candidates) {
      if (_mode == DataMode.cloudStorage && _isScrubbedTombstone(row)) continue;
      if (await _purge(row.id, cutoff: cutoff) == PurgeOutcome.purged) purged++;
    }
    return purged;
  }

  /// "Delete now" (slice 5 UI): purge one soft-deleted note immediately.
  Future<PurgeOutcome> purgeNow(int id) => _purge(id, cutoff: null);

  Future<PurgeOutcome> _purge(int id, {required DateTime? cutoff}) async {
    final row = await (_db.select(_db.notes)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
    final deletedAt = row?.deletedAt;
    if (row == null || deletedAt == null) return PurgeOutcome.notEligible;
    if (cutoff != null && !deletedAt.toUtc().isBefore(cutoff)) {
      return PurgeOutcome.notEligible;
    }

    final paths = _vaultPathsOf(row.attachments);
    try {
      final done = switch (_mode) {
        DataMode.local => await _hardDelete(row.id, deletedAt),
        DataMode.cloudStorage => await _scrubToTombstone(row.id, deletedAt),
        DataMode.cloudApi => await _purgeOnServerThenDelete(row, deletedAt),
      };
      if (!done) return PurgeOutcome.notEligible;
      final p = _provider;
      final uuid = row.uuid;
      if (_mode == DataMode.cloudStorage && p != null && uuid != null) {
        await _pending.add(p.providerId, uuid, paths);
      }
    } on NoteLiveOnServerException {
      return PurgeOutcome.keptLiveOnServer;
    } catch (e) {
      debugPrint('NotePurgeService: purging note $id failed (${e.runtimeType})');
      return PurgeOutcome.failed;
    }
    // cloudApi bytes live server-side; the purge endpoint released them.
    if (_mode != DataMode.cloudApi) await _releaseVault(paths);
    return PurgeOutcome.purged;
  }

  Future<bool> _purgeOnServerThenDelete(Note row, DateTime deletedAt) async {
    final p = _provider;
    final uuid = row.uuid;
    if (p != null && uuid != null) {
      await p.purgeNote(uuid); // throws NoteLiveOnServerException when live
    }
    return _hardDelete(row.id, deletedAt);
  }

  Future<bool> _hardDelete(int id, DateTime deletedAt) =>
      _db.transaction(() async {
        final gone = await (_db.delete(_db.notes)
              ..where((n) => n.id.equals(id) & n.deletedAt.equals(deletedAt)))
            .go();
        if (gone == 0) return false; // restored meanwhile
        await (_db.delete(_db.noteTagRefs)..where((r) => r.noteId.equals(id)))
            .go();
        await _detachChildren(id);
        return true;
      });

  /// cloudStorage: keep a content-free tombstone so the manifest keeps
  /// propagating the delete. lastModifiedDate is deliberately NOT bumped:
  /// peers keep their own 30-day clock, and a newer restore elsewhere still
  /// wins the pull and refills this row.
  Future<bool> _scrubToTombstone(int id, DateTime deletedAt) =>
      _db.transaction(() async {
        final changed = await (_db.update(_db.notes)
              ..where((n) => n.id.equals(id) & n.deletedAt.equals(deletedAt)))
            .write(const NotesCompanion(
          subject: Value(kTombstoneSubject),
          content: Value(null),
          description: Value(null),
          attachments: Value(null),
          latitude: Value(null),
          longitude: Value(null),
          locationLabel: Value(null),
          catalogId: Value(null),
          parentNoteId: Value(null),
          isPinned: Value(false),
          flagColor: Value(null),
        ));
        if (changed == 0) return false; // restored meanwhile
        await (_db.delete(_db.noteTagRefs)..where((r) => r.noteId.equals(id)))
            .go();
        await _detachChildren(id);
        return true;
      });

  /// G12: attached notes become unattached once their parent is purged. The
  /// bump makes the detach sync like any other edit.
  Future<void> _detachChildren(int parentId) async {
    await (_db.update(_db.notes)
          ..where((n) => n.parentNoteId.equals(parentId)))
        .write(NotesCompanion(
      parentNoteId: const Value(null),
      lastModifiedDate: Value(DateTime.now().toUtc()),
    ));
  }

  bool _isScrubbedTombstone(Note row) =>
      row.subject == kTombstoneSubject &&
      row.content == null &&
      row.attachments == null;

  static Set<String> _vaultPathsOf(String? raw) {
    final a = NoteAttachmentsCodec.decode(raw);
    return {
      for (final ref in <AttachmentRef?>[a.primaryImage, ...a.images, ...a.files])
        if (ref is VaultRef) ref.path,
    };
  }

  /// Release the purged note's vault files that no remaining note references
  /// (the VaultGc rule). Best effort: leftovers are reclaimed by VaultGc.
  Future<void> _releaseVault(Set<String> paths) async {
    if (paths.isEmpty) return;
    try {
      final stillReferenced = await collectReferencedVaultPaths(_db);
      final store = await _baseVaultStore();
      for (final path in paths) {
        if (!stillReferenced.contains(path)) await store.delete(path);
      }
    } catch (e) {
      debugPrint('NotePurgeService: vault release failed (${e.runtimeType})');
    }
  }
}

final notePurgeServiceProvider = Provider<NotePurgeService>((ref) {
  return NotePurgeService(
    db: ref.watch(hmmDatabaseProvider),
    mode: ref.watch(dataModeProvider),
    baseVaultStore: () => ref.read(baseVaultStoreProvider.future),
    provider: ref.watch(syncOrchestratorProvider).provider,
  );
});
```

- [ ] **Step 7: Flush deferred purges inside sync**

In `sync_orchestrator.dart`:

1. Add the import `import 'pending_remote_purge_store.dart';`.
2. Constructor: add the parameter `PendingRemotePurgeStore? pendingPurges,` after `Future<int> Function()? currentAuthorId,`, the initializer `_pendingPurges = pendingPurges ?? PendingRemotePurgeStore(),` before `_tagRepo = LocalTagRepository(db);`, and the field `final PendingRemotePurgeStore _pendingPurges;` next to `final LocalTagRepository _tagRepo;`.
3. In `_maybePullNote`'s tombstone insert, replace `subject: '(deleted)',` with `subject: kTombstoneSubject,`.
4. Immediately before `timer.stop(SyncPhase.pullNotes);` (after the `if (remote != null) { ... }` block) add:

```dart

    // Deferred remote purges (cloudStorage, see NotePurgeService). Runs only
    // after the pull above had its chance to revive a note restored on
    // another device.
    await _flushRemotePurges(p, remote, errors);
```

5. Replace

```dart
    final metadataClean =
        errors.every((e) => e.recordType == 'attachment');
```

with

```dart
    // A failed remote purge is retried from the pending store next sync, so
    // it must not hold the note cursor back either.
    final metadataClean = errors.every(
        (e) => e.recordType == 'attachment' || e.recordType == 'purge');
```

6. Add the method after `_syncTags`:

```dart

  // ==================== Deferred remote purge ====================

  Future<void> _flushRemotePurges(
    CloudSyncProvider p,
    SyncManifest? remote,
    List<SyncError> errors,
  ) async {
    final pending = await _pendingPurges.read(p.providerId);
    if (pending.isEmpty) return;
    final remoteById = {
      for (final e in remote?.notes ?? const <ManifestEntry>[]) e.id: e,
    };
    for (final entry in pending.entries) {
      final uuid = entry.key;
      final local = await (_db.select(_db.notes)
            ..where((n) => n.uuid.equals(uuid)))
          .getSingleOrNull();
      if (local == null || local.deletedAt == null) {
        // Gone, or revived by this sync's pull (restored elsewhere):
        // nothing to delete remotely, now or later.
        await _pendingPurges.remove(p.providerId, uuid);
        continue;
      }
      final r = remoteById[uuid];
      final localStamp = (local.lastModifiedDate ?? local.createDate).toUtc();
      if (r != null && (!r.deleted || r.updatedAt.isAfter(localStamp))) {
        // The remote copy is newer than our tombstone but the pull did not
        // apply it (it failed). Leave it for the next sync.
        continue;
      }
      try {
        final referenced = await collectReferencedVaultPaths(_db);
        await p.purgeNote(uuid,
            releasedVaultPaths:
                entry.value.where((path) => !referenced.contains(path)).toSet());
        await _pendingPurges.remove(p.providerId, uuid);
      } catch (e) {
        errors.add(SyncError(
          recordType: 'purge',
          recordId: uuid,
          message: 'Remote purge failed (${e.runtimeType}); retrying next sync',
        ));
      }
    }
  }
```

- [ ] **Step 8: Run tests**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/local/note_purge_service_test.dart test/core/data/sync/
flutter analyze
```
Expected: `All tests passed!`; analyze at the 2 pre-existing infos.

- [ ] **Step 9: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/core/data/sync/sync_models.dart lib/core/data/sync/cloud_sync_provider.dart \
  lib/core/data/sync/onedrive_sync_provider.dart lib/core/data/sync/api_sync_provider.dart \
  lib/core/data/sync/pending_remote_purge_store.dart lib/core/data/local/note_purge_service.dart \
  lib/core/data/sync/sync_orchestrator.dart \
  test/core/data/local/note_purge_service_test.dart test/core/data/sync/sync_orchestrator_remote_purge_test.dart \
  test/core/data/sync/api_sync_provider_purge_test.dart test/core/data/sync/onedrive_sync_provider_purge_test.dart
git commit -m "$(cat <<'MSG'
feat(notes): real 30-day purge with vault release, per data mode

local hard-deletes; cloudStorage keeps a content-free tombstone and deletes
the OneDrive blob inside the next sync, after the pull could revive a note
restored elsewhere; cloudApi purges on the server first (409 keeps a live
note). Guarded writes mean a restore that lands meanwhile always wins.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 9: Client — run the purge at most daily, never during sync

Sync-in-progress is exposed as `SyncController.status.isSyncing` (`lib/core/data/sync/sync_controller.dart:53`). Reading it is not enough — a sync could start while a purge runs — so the controller gains an exclusive slot that both sides respect.

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/sync_controller.dart` (fields ~line 170; `triggerAutoSync` line 265; `triggerManualSync` line 285; new `runExclusive`)
- Create: `/Users/fchy/Projects/hmm_console/lib/core/data/local/note_purge_scheduler.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/main.dart` (imports; `initState` line 54; `build` line 78)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_controller_exclusive_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/local/note_purge_scheduler_test.dart` (create)

**Interfaces:**
- Produces (Dart):
  - `Future<T?> SyncController.runExclusive<T>(Future<T> Function() body)` — returns null without running when a sync is in flight (or another exclusive run); while `body` runs, `triggerAutoSync`/`triggerManualSync` return null.
  - `class NotePurgeScheduler { NotePurgeScheduler({required Future<int> Function(DateTime now) purgeExpired, required SyncController controller, DateTime Function()? now}); static const String lastRunKey = 'notes_purge_last_run_at'; static const Duration interval = Duration(days: 1); Future<int?> maybeRun(); }`
  - `final notePurgeSchedulerProvider = Provider<NotePurgeScheduler>` — also re-checks after every sync finishes.

- [ ] **Step 1: Write the failing tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_controller_exclusive_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';

SyncResult _ok() => SyncResult(
      pulledNotes: 0, pulledAttachments: 0, pushedNotes: 0, pushedAttachments: 0,
      completedAt: DateTime.utc(2026, 10, 18));

void main() {
  test('runExclusive refuses while a sync is in flight', () async {
    final gate = Completer<SyncResult>();
    final c = SyncController(syncAction: () => gate.future);
    addTearDown(c.dispose);

    final syncing = c.triggerManualSync();
    var ran = false;
    expect(await c.runExclusive(() async => ran = true), isNull);
    expect(ran, isFalse);

    gate.complete(_ok());
    await syncing;
    expect(await c.runExclusive(() async => 2), 2);
  });

  test('syncs triggered during an exclusive run are skipped', () async {
    var syncs = 0;
    final c = SyncController(syncAction: () async {
      syncs++;
      return _ok();
    }, throttle: Duration.zero);
    addTearDown(c.dispose);

    final gate = Completer<void>();
    final run = c.runExclusive(() => gate.future.then((_) => 'done'));
    expect(await c.triggerManualSync(), isNull);
    expect(await c.triggerAutoSync(SyncTriggerReason.periodic), isNull);
    expect(syncs, 0);

    gate.complete();
    expect(await run, 'done');
    expect(await c.triggerManualSync(), isNotNull);
    expect(syncs, 1);
  });

  test('a throwing exclusive body releases the slot', () async {
    final c = SyncController(syncAction: () async => _ok());
    addTearDown(c.dispose);

    await expectLater(c.runExclusive<int>(() async => throw StateError('x')), throwsStateError);
    expect(await c.runExclusive(() async => 1), 1);
  });
}
```

Create `/Users/fchy/Projects/hmm_console/test/core/data/local/note_purge_scheduler_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/note_purge_scheduler.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

SyncResult _ok() => SyncResult(
      pulledNotes: 0, pulledAttachments: 0, pushedNotes: 0, pushedAttachments: 0,
      completedAt: DateTime.utc(2026, 10, 18));

void main() {
  late DateTime clock;
  late List<DateTime> runs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime.utc(2026, 10, 18, 8);
    runs = [];
  });

  NotePurgeScheduler scheduler(SyncController c, {Object? fail}) => NotePurgeScheduler(
        controller: c,
        now: () => clock,
        purgeExpired: (now) async {
          if (fail != null) throw fail;
          runs.add(now);
          return 3;
        },
      );

  test('runs once, then waits a day', () async {
    final c = SyncController(syncAction: () async => _ok());
    addTearDown(c.dispose);
    final s = scheduler(c);

    expect(await s.maybeRun(), 3);
    expect(runs, [clock]);
    final prefs = await SharedPreferences.getInstance();
    expect(DateTime.parse(prefs.getString(NotePurgeScheduler.lastRunKey)!), clock);

    clock = clock.add(const Duration(hours: 23));
    expect(await s.maybeRun(), isNull);
    expect(runs, hasLength(1));

    clock = clock.add(const Duration(hours: 2));
    expect(await s.maybeRun(), 3);
    expect(runs, hasLength(2));
  });

  test('skips while a sync runs and does not record a run', () async {
    final gate = Completer<SyncResult>();
    final c = SyncController(syncAction: () => gate.future);
    addTearDown(c.dispose);
    final s = scheduler(c);

    final syncing = c.triggerManualSync();
    expect(await s.maybeRun(), isNull);
    expect(runs, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NotePurgeScheduler.lastRunKey), isNull);

    gate.complete(_ok());
    await syncing;
    expect(await s.maybeRun(), 3);
  });

  test('a throwing purge is swallowed and not recorded', () async {
    final c = SyncController(syncAction: () async => _ok());
    addTearDown(c.dispose);

    expect(await scheduler(c, fail: StateError('db')).maybeRun(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NotePurgeScheduler.lastRunKey), isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/sync/sync_controller_exclusive_test.dart test/core/data/local/note_purge_scheduler_test.dart
```
Expected: compile errors `The method 'runExclusive' isn't defined for the type 'SyncController'` and `Target of URI doesn't exist: 'package:hmm_console/core/data/local/note_purge_scheduler.dart'`.

- [ ] **Step 3: Add `runExclusive`**

In `sync_controller.dart`, after `bool _started = false;` add:

```dart

  /// True while a [runExclusive] body runs (e.g. the daily note purge).
  bool _exclusiveBusy = false;
```

In `triggerAutoSync` and in `triggerManualSync`, replace `if (_status.isSyncing) return null;` with:

```dart
    if (_status.isSyncing || _exclusiveBusy) return null;
```

After `notifyLocalChange()` add:

```dart

  /// Run [body] with sync locked out: returns null WITHOUT running it when a
  /// sync (or another exclusive run) is in flight; while it runs, every
  /// trigger is skipped (the next periodic/foreground trigger catches up).
  /// Used by the daily Recently-Deleted purge, which must never interleave
  /// with a sync. Errors from [body] propagate; the slot is always released.
  Future<T?> runExclusive<T>(Future<T> Function() body) async {
    if (_status.isSyncing || _exclusiveBusy) return null;
    _exclusiveBusy = true;
    try {
      return await body();
    } finally {
      _exclusiveBusy = false;
    }
  }
```

- [ ] **Step 4: Add the scheduler**

Create `/Users/fchy/Projects/hmm_console/lib/core/data/local/note_purge_scheduler.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/sync_controller.dart';
import 'note_purge_service.dart';

/// Runs the 30-day Recently-Deleted purge at most once a day and never while
/// a sync runs (spec "Recently Deleted → Purge", G6/G11).
class NotePurgeScheduler {
  NotePurgeScheduler({
    required Future<int> Function(DateTime now) purgeExpired,
    required SyncController controller,
    DateTime Function()? now,
  })  : _purgeExpired = purgeExpired,
        _controller = controller,
        _now = now ?? DateTime.now;

  /// Device-local: each device purges its own store on its own clock.
  static const String lastRunKey = 'notes_purge_last_run_at';
  static const Duration interval = Duration(days: 1);

  final Future<int> Function(DateTime now) _purgeExpired;
  final SyncController _controller;
  final DateTime Function() _now;
  bool _running = false;

  /// Purge if a day has passed since the last completed run and no sync is
  /// in flight. Returns how many notes were purged, or null when skipped or
  /// failed (a skipped or failed run is not recorded, so it retries soon).
  Future<int?> maybeRun() async {
    if (_running) return null;
    _running = true;
    try {
      final now = _now().toUtc();
      final prefs = await SharedPreferences.getInstance();
      final last = DateTime.tryParse(prefs.getString(lastRunKey) ?? '');
      if (last != null && now.difference(last) < interval) return null;

      final purged = await _controller.runExclusive(() => _purgeExpired(now));
      if (purged == null) return null; // a sync was running
      await prefs.setString(lastRunKey, now.toIso8601String());
      return purged;
    } catch (e) {
      debugPrint('NotePurgeScheduler: purge run failed (${e.runtimeType})');
      return null;
    } finally {
      _running = false;
    }
  }
}

/// Rebuilt with the sync controller (data-mode switches). Re-checks after
/// every sync finishes; `MainApp` also calls [NotePurgeScheduler.maybeRun]
/// once after the first frame, which covers `local` mode (it never syncs).
final notePurgeSchedulerProvider = Provider<NotePurgeScheduler>((ref) {
  final controller = ref.watch(syncControllerProvider);
  final service = ref.watch(notePurgeServiceProvider);
  final scheduler = NotePurgeScheduler(
    purgeExpired: service.purgeExpired,
    controller: controller,
  );
  void afterSync() {
    if (!controller.status.isSyncing) unawaited(scheduler.maybeRun());
  }

  controller.addListener(afterSync);
  ref.onDispose(() => controller.removeListener(afterSync));
  return scheduler;
});
```

- [ ] **Step 5: Wire it into `MainApp`**

In `lib/main.dart` add `import 'dart:async';` at the top and `import 'package:hmm_console/core/data/local/note_purge_scheduler.dart';` with the other package imports.

In `_MainAppState.initState`, after `ref.read(syncControllerProvider).start();` add:

```dart
    // Daily Recently-Deleted purge. The provider re-checks after each sync;
    // this first call covers local mode, which never syncs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(notePurgeSchedulerProvider).maybeRun());
    });
```

In `build`, after the `ref.listen<SyncController>(...)` block add:

```dart
    // Keep the purge scheduler alive (and re-created with the controller on a
    // data-mode switch) so its after-sync listener stays attached.
    ref.listen<NotePurgeScheduler>(notePurgeSchedulerProvider, (previous, next) {});
```

- [ ] **Step 6: Run tests and analyze**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/sync/ test/core/data/local/note_purge_scheduler_test.dart
flutter analyze
```
Expected: `All tests passed!`; analyze at the 2 pre-existing infos (the `lib/main.dart` `use_null_aware_elements` info moves down a few lines but stays the same single info).

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/core/data/sync/sync_controller.dart lib/core/data/local/note_purge_scheduler.dart lib/main.dart \
  test/core/data/sync/sync_controller_exclusive_test.dart test/core/data/local/note_purge_scheduler_test.dart
git commit -m "$(cat <<'MSG'
feat(notes): daily purge scheduler that never overlaps a sync

SyncController.runExclusive locks sync out while the purge runs and refuses
to start it during a sync; a skipped or failed run is not recorded.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 10: Client — entity-note delete guard (G7) + `MutateNote` restore/pin/flag

**Files:**
- Create: `/Users/fchy/Projects/hmm_console/lib/features/notes/states/note_delete_policy.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/features/notes/states/mutate_note_state.dart` (imports lines 1–12; `delete` lines 72–74)
- Test: `/Users/fchy/Projects/hmm_console/test/features/notes/states/note_delete_policy_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/features/notes/states/mutate_note_delete_guard_test.dart` (create)

**Interfaces:**
- Consumes: `contactCatalogName` (`lib/core/data/local/local_contact_repository.dart:20`), `cheatsheetCatalogName` (`lib/core/data/local/local_cheatsheet_repository.dart:17`), `kGeneralCatalogName` + `CatalogPalette.domainKeyFor` (`lib/core/notes/catalog_palette.dart`), `IHmmNoteRepository.restoreNote/setPinned/setFlagColor` (Task 5).
- Produces (Dart):
  - `bool canDeleteFromNotes(HmmNote note, String? catalogName)`
  - `enum NoteManagePlace { contacts, cheatsheets, automobile, ownScreen }`, `NoteManagePlace? managePlaceFor(String? catalogName)`
  - `class EntityNoteDeleteRefused implements Exception { final NoteManagePlace place; }`
  - `MutateNote.delete(int id)` now throws `EntityNoteDeleteRefused` for entity notes; `MutateNote.restore(int id) → Future<HmmNote>`, `setPinned(int id, bool pinned) → Future<HmmNote>`, `setFlagColor(int id, int? flagColor) → Future<HmmNote>`.

- [ ] **Step 1: Write the failing tests**

Create `/Users/fchy/Projects/hmm_console/test/features/notes/states/note_delete_policy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/note_delete_policy.dart';

void main() {
  final note = HmmNote(id: 1, uuid: 'u', subject: 's', authorId: 1, createDate: DateTime(2026));

  test('ordinary notes can be deleted from Notes', () {
    expect(canDeleteFromNotes(note, 'General'), isTrue);
    expect(canDeleteFromNotes(note, null), isTrue, reason: 'legacy row with no catalog');
    expect(managePlaceFor('General'), isNull);
    expect(managePlaceFor(null), isNull);
  });

  test('entity notes cannot (G7)', () {
    for (final name in [
      'Hmm.ContactMan.Contact',
      'Hmm.CheatsheetMan.Cheatsheet',
      'Hmm.AutomobileMan.GasLog',
      'Hmm.AutomobileMan.AutomobileInfo',
      'Hmm.AutomobileMan.ServiceRecord',
      'Hmm.AutomobileMan.AutoInsurancePolicy',
      'Hmm.AutomobileMan.AutoScheduledService',
      'Hmm.AutomobileMan.GasStation',
      'Hmm.AutomobileMan.DriverLicence',
      'Hmm.System.Subsystem',
      'Hmm.FutureMan.SomethingNew',
    ]) {
      expect(canDeleteFromNotes(note, name), isFalse, reason: name);
    }
  });

  test('each entity note says where it is managed', () {
    expect(managePlaceFor('Hmm.ContactMan.Contact'), NoteManagePlace.contacts);
    expect(managePlaceFor('Hmm.CheatsheetMan.Cheatsheet'), NoteManagePlace.cheatsheets);
    expect(managePlaceFor('Hmm.AutomobileMan.GasLog'), NoteManagePlace.automobile);
    expect(managePlaceFor('Hmm.AutomobileMan.DriverLicence'), NoteManagePlace.automobile);
    expect(managePlaceFor('Hmm.System.Subsystem'), NoteManagePlace.ownScreen);
    expect(managePlaceFor('Hmm.FutureMan.SomethingNew'), NoteManagePlace.ownScreen);
  });
}
```

Create `/Users/fchy/Projects/hmm_console/test/features/notes/states/mutate_note_delete_guard_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/note_delete_policy.dart';

void main() {
  late HmmDatabase db;
  late ProviderContainer container;
  late LocalHmmNoteRepository notes;
  late LocalNoteCatalogRepository catalogs;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final authorId =
        await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(authorId))).getSingle();
    notes = LocalHmmNoteRepository(db, () async => author);
    catalogs = LocalNoteCatalogRepository(db);
    container = ProviderContainer(overrides: [
      hmmNoteRepositoryProvider.overrideWithValue(notes),
      noteCatalogRepositoryProvider.overrideWithValue(catalogs),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> noteIn(String catalogName) async {
    final catalog = await catalogs.getOrCreateCatalog(catalogName, '{}');
    return (await notes.createNote(HmmNoteCreate(subject: 's', catalogId: catalog.id))).id;
  }

  test('delete soft-deletes an ordinary note', () async {
    final id = await noteIn('General');

    await container.read(mutateNoteProvider).delete(id);

    expect((await notes.getNoteById(id))!.deletedAt, isNotNull);
  });

  test('delete refuses an entity note and leaves it live', () async {
    final id = await noteIn('Hmm.ContactMan.Contact');

    await expectLater(
      container.read(mutateNoteProvider).delete(id),
      throwsA(isA<EntityNoteDeleteRefused>()
          .having((e) => e.place, 'place', NoteManagePlace.contacts)),
    );
    expect((await notes.getNoteById(id))!.deletedAt, isNull);
  });

  test('restore brings a deleted note back', () async {
    final id = await noteIn('General');
    final mutate = container.read(mutateNoteProvider);
    await mutate.delete(id);

    final restored = await mutate.restore(id);

    expect(restored.deletedAt, isNull);
  });

  test('pin and flag work on every note, entity notes included', () async {
    final id = await noteIn('Hmm.AutomobileMan.GasLog');
    final mutate = container.read(mutateNoteProvider);

    expect((await mutate.setPinned(id, true)).isPinned, isTrue);
    expect((await mutate.setFlagColor(id, 0)).flagColor, 0);
    expect((await mutate.setFlagColor(id, null)).flagColor, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/features/notes/states/note_delete_policy_test.dart test/features/notes/states/mutate_note_delete_guard_test.dart
```
Expected: compile error `Target of URI doesn't exist: 'package:hmm_console/features/notes/states/note_delete_policy.dart'`.

- [ ] **Step 3: Implement the policy**

Create `/Users/fchy/Projects/hmm_console/lib/features/notes/states/note_delete_policy.dart`:

```dart
import '../../../core/data/local/local_cheatsheet_repository.dart'
    show cheatsheetCatalogName;
import '../../../core/data/local/local_contact_repository.dart'
    show contactCatalogName;
import '../../../core/notes/catalog_palette.dart';
import '../data/models/hmm_note.dart';

/// Where an entity note is managed instead of the Notes delete (G7).
enum NoteManagePlace { contacts, cheatsheets, automobile, ownScreen }

/// True only for ordinary notes: the General catalog, or a legacy row with
/// no catalog. Contacts, cheatsheet cards, gas logs, cars, service records,
/// insurance, scheduled services, gas stations, the driver licence,
/// subsystem anchors and any catalog this build does not know belong to
/// their own feature, which owns their delete (G7). Pin, flag and tags still
/// work on every note.
bool canDeleteFromNotes(HmmNote note, String? catalogName) =>
    catalogName == null || catalogName == kGeneralCatalogName;

/// The screen that manages an entity note, or null for an ordinary note.
NoteManagePlace? managePlaceFor(String? catalogName) {
  if (catalogName == null || catalogName == kGeneralCatalogName) return null;
  if (catalogName == contactCatalogName) return NoteManagePlace.contacts;
  if (catalogName == cheatsheetCatalogName) return NoteManagePlace.cheatsheets;
  if (CatalogPalette.domainKeyFor(catalogName) == 'AutomobileMan') {
    return NoteManagePlace.automobile;
  }
  return NoteManagePlace.ownScreen;
}

/// Thrown by `MutateNote.delete` for an entity note.
class EntityNoteDeleteRefused implements Exception {
  const EntityNoteDeleteRefused(this.place);

  final NoteManagePlace place;

  @override
  String toString() => 'EntityNoteDeleteRefused(${place.name})';
}
```

- [ ] **Step 4: Guard `MutateNote.delete` and add restore/pin/flag**

In `mutate_note_state.dart` add `import 'note_delete_policy.dart';` and replace

```dart
  Future<void> delete(int id) async {
    await ref.read(hmmNoteRepositoryProvider).deleteNote(id);
  }
```

with

```dart
  /// Move an ordinary note to Recently Deleted (soft delete). Entity notes
  /// are refused with [EntityNoteDeleteRefused] — their own feature owns
  /// their delete (G7).
  Future<void> delete(int id) async {
    final repo = ref.read(hmmNoteRepositoryProvider);
    final note = await repo.getNoteById(id);
    if (note == null) return;
    final catalogName = await _catalogNameOf(note);
    if (!canDeleteFromNotes(note, catalogName)) {
      throw EntityNoteDeleteRefused(
          managePlaceFor(catalogName) ?? NoteManagePlace.ownScreen);
    }
    await repo.deleteNote(id);
  }

  /// Undo a delete (clear deletedAt with a newer lastModifiedDate).
  Future<HmmNote> restore(int id) =>
      ref.read(hmmNoteRepositoryProvider).restoreNote(id);

  Future<HmmNote> setPinned(int id, bool pinned) =>
      ref.read(hmmNoteRepositoryProvider).setPinned(id, pinned);

  /// [flagColor] null clears the flag.
  Future<HmmNote> setFlagColor(int id, int? flagColor) =>
      ref.read(hmmNoteRepositoryProvider).setFlagColor(id, flagColor);

  Future<String?> _catalogNameOf(HmmNote note) async {
    final cid = note.catalogId;
    if (cid == null) return null;
    return (await ref.read(noteCatalogRepositoryProvider).getCatalogById(cid))
        ?.name;
  }
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/features/notes/
flutter analyze
```
Expected: `All tests passed!` (including the existing `delete calls through` in `mutate_note_state_test.dart`, whose note has no catalog); analyze at the 2 pre-existing infos.

- [ ] **Step 6: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/features/notes/states/note_delete_policy.dart lib/features/notes/states/mutate_note_state.dart \
  test/features/notes/states/note_delete_policy_test.dart test/features/notes/states/mutate_note_delete_guard_test.dart
git commit -m "$(cat <<'MSG'
feat(notes): Notes never deletes entity notes (G7); MutateNote restore/pin/flag

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 11: Client — note detail: undoable Delete, "Manage in …", Pin/Unpin, Flag…, Help

The only UI change in slice 1: today's detail Delete is instant with no Undo (a bug the spec fixes), and pins/flags need one entry point to be usable before the list redesign.

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/l10n/app_en.arb` (append before the final `}`), `/Users/fchy/Projects/hmm_console/lib/l10n/app_zh.arb` (same)
- Regenerate: `/Users/fchy/Projects/hmm_console/lib/l10n/gen/*`
- Create: `/Users/fchy/Projects/hmm_console/lib/features/notes/presentation/widgets/note_flag_sheet.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/features/notes/presentation/catalog_labels.dart` (append `managePlaceLabel`)
- Modify (rewrite): `/Users/fchy/Projects/hmm_console/lib/features/notes/presentation/screens/note_detail_screen.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/help/help_registry.dart` (enum line 10–19; new case before the final `};`)
- Test: `/Users/fchy/Projects/hmm_console/test/features/notes/presentation/note_detail_actions_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/features/notes/presentation/widgets/note_flag_sheet_test.dart` (create)

**Interfaces:**
- Consumes: `MutateNote.delete/restore/setPinned/setFlagColor`, `canDeleteFromNotes`, `managePlaceFor` (Task 10), `NoteFlagColor` (Task 5), `showUndoableAction`, `HelpButton`, `HmmNote.isPinned/flag`.
- Produces (Dart):
  - `class NoteFlagChoice { const NoteFlagChoice(NoteFlagColor? color); final NoteFlagColor? color; }` (null color = Clear flag)
  - `Future<NoteFlagChoice?> showNoteFlagSheet(BuildContext context, {NoteFlagColor? current})` — `CupertinoActionSheet` on iOS/macOS, Material bottom sheet otherwise; null = dismissed.
  - `String noteFlagColorLabel(NoteFlagColor color, AppLocalizations l)`, `String managePlaceLabel(NoteManagePlace place, AppLocalizations l)`
  - `HelpId.noteDetail`
  - ARB keys (en + zh): `notesPin`, `notesUnpin`, `notesFlagAction`, `notesFlagSheetTitle`, `notesClearFlag`, `flagColorRed`, `flagColorOrange`, `flagColorYellow`, `flagColorGreen`, `flagColorBlue`, `flagColorPurple`, `flagColorGrey`, `notesPinnedLabel`, `notesFlaggedLabel(color)`, `notesPinFailed`, `notesFlagFailed`, `notesMovedToRecentlyDeleted`, `notesDeleteFailed`, `notesRestored`, `notesRestoreFailed`, `notesManageIn(place)`, `notesManagePlaceOwnScreen`, `helpNoteDetailTitle`, `helpNoteDetailSummary`, `helpNoteDetailPinTitle`, `helpNoteDetailPinBody`, `helpNoteDetailFlagTitle`, `helpNoteDetailFlagBody`, `helpNoteDetailDeleteTitle`, `helpNoteDetailDeleteBody`, `helpNoteDetailManageTitle`, `helpNoteDetailManageBody`.

- [ ] **Step 1: Add the strings (en + zh) and regenerate**

In `lib/l10n/app_en.arb` replace the final two lines

```json
  "@notesCheatsheetPreview": {"placeholders": {"group": {"type": "String"}, "count": {"type": "int"}}}
}
```

with

```json
  "@notesCheatsheetPreview": {"placeholders": {"group": {"type": "String"}, "count": {"type": "int"}}},
  "notesPin": "Pin",
  "notesUnpin": "Unpin",
  "notesFlagAction": "Flag…",
  "notesFlagSheetTitle": "Flag",
  "notesClearFlag": "Clear flag",
  "flagColorRed": "Red",
  "flagColorOrange": "Orange",
  "flagColorYellow": "Yellow",
  "flagColorGreen": "Green",
  "flagColorBlue": "Blue",
  "flagColorPurple": "Purple",
  "flagColorGrey": "Grey",
  "notesPinnedLabel": "Pinned",
  "notesFlaggedLabel": "Flagged {color}",
  "@notesFlaggedLabel": {"placeholders": {"color": {"type": "String"}}},
  "notesPinFailed": "Couldn't pin the note",
  "notesFlagFailed": "Couldn't flag the note",
  "notesMovedToRecentlyDeleted": "Moved to Recently Deleted",
  "notesDeleteFailed": "Couldn't delete the note",
  "notesRestored": "Note restored",
  "notesRestoreFailed": "Couldn't restore the note",
  "notesManageIn": "Manage in {place}",
  "@notesManageIn": {"placeholders": {"place": {"type": "String"}}},
  "notesManagePlaceOwnScreen": "its own screen",
  "helpNoteDetailTitle": "Note",
  "helpNoteDetailSummary": "Read a note and use the ⋯ menu to pin, flag, edit or delete it.",
  "helpNoteDetailPinTitle": "Pin",
  "helpNoteDetailPinBody": "Marks the note as pinned; the notes list will show pinned notes first. Pins sync to your other devices. Choose Unpin to remove it.",
  "helpNoteDetailFlagTitle": "Flag",
  "helpNoteDetailFlagBody": "Marks the note with one of seven colours. Choose Clear flag to remove it.",
  "helpNoteDetailDeleteTitle": "Delete",
  "helpNoteDetailDeleteBody": "Moves the note to Recently Deleted. Tap Undo in the message to bring it back. Deleted notes are removed for good after 30 days.",
  "helpNoteDetailManageTitle": "Manage in …",
  "helpNoteDetailManageBody": "Contacts, cheatsheet cards, cars, gas logs and other records are deleted from their own screens, not from Notes. Pin and flag still work here."
}
```

In `lib/l10n/app_zh.arb` replace the final two lines

```json
  "notesCheatsheetPreview": "{group} · {count} 行"
}
```

with

```json
  "notesCheatsheetPreview": "{group} · {count} 行",
  "notesPin": "置顶",
  "notesUnpin": "取消置顶",
  "notesFlagAction": "旗标…",
  "notesFlagSheetTitle": "旗标",
  "notesClearFlag": "清除旗标",
  "flagColorRed": "红色",
  "flagColorOrange": "橙色",
  "flagColorYellow": "黄色",
  "flagColorGreen": "绿色",
  "flagColorBlue": "蓝色",
  "flagColorPurple": "紫色",
  "flagColorGrey": "灰色",
  "notesPinnedLabel": "已置顶",
  "notesFlaggedLabel": "{color}旗标",
  "notesPinFailed": "无法置顶此笔记",
  "notesFlagFailed": "无法为此笔记加旗标",
  "notesMovedToRecentlyDeleted": "已移至“最近删除”",
  "notesDeleteFailed": "无法删除此笔记",
  "notesRestored": "笔记已恢复",
  "notesRestoreFailed": "无法恢复此笔记",
  "notesManageIn": "请在{place}中管理",
  "notesManagePlaceOwnScreen": "其所属页面",
  "helpNoteDetailTitle": "笔记",
  "helpNoteDetailSummary": "阅读笔记，并通过 ⋯ 菜单置顶、加旗标、编辑或删除。",
  "helpNoteDetailPinTitle": "置顶",
  "helpNoteDetailPinBody": "将笔记标记为置顶；笔记列表将把置顶笔记排在最前。置顶会同步到你的其他设备。选择“取消置顶”即可移除。",
  "helpNoteDetailFlagTitle": "旗标",
  "helpNoteDetailFlagBody": "用七种颜色之一标记笔记。选择“清除旗标”即可移除。",
  "helpNoteDetailDeleteTitle": "删除",
  "helpNoteDetailDeleteBody": "将笔记移至“最近删除”。点按提示中的“撤销”即可恢复。已删除的笔记会在 30 天后永久移除。",
  "helpNoteDetailManageTitle": "在其他位置管理",
  "helpNoteDetailManageBody": "联系人、速查卡、车辆、加油记录等记录需在各自的页面中删除，而不是在笔记中删除。置顶和旗标在此仍然可用。"
}
```

Regenerate:

```bash
cd /Users/fchy/Projects/hmm_console
flutter gen-l10n
```
Expected: no "untranslated message" warnings for the new keys.

- [ ] **Step 2: Write the failing widget tests**

Create `/Users/fchy/Projects/hmm_console/test/features/notes/presentation/widgets/note_flag_sheet_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_flag.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_flag_sheet.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

Widget _host(TargetPlatform platform, NoteFlagColor? current, void Function(NoteFlagChoice?) onResult) =>
    MaterialApp(
      theme: ThemeData(platform: platform),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => onResult(await showNoteFlagSheet(ctx, current: current)),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('Android: a bottom sheet with seven named colours, no Clear when unflagged',
      (tester) async {
    NoteFlagChoice? result;
    await tester.pumpWidget(_host(TargetPlatform.android, null, (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsNothing);
    for (final name in ['Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Purple', 'Grey']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Clear flag'), findsNothing);

    await tester.tap(find.text('Blue'));
    await tester.pumpAndSettle();
    expect(result!.color, NoteFlagColor.blue);
  });

  testWidgets('iOS: a Cupertino action sheet; Clear flag returns a null colour', (tester) async {
    NoteFlagChoice? result;
    await tester.pumpWidget(_host(TargetPlatform.iOS, NoteFlagColor.red, (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('Clear flag'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.color, isNull);
  });

  testWidgets('Cancel returns null (nothing changes)', (tester) async {
    NoteFlagChoice? result = const NoteFlagChoice(NoteFlagColor.red);
    await tester.pumpWidget(_host(TargetPlatform.iOS, null, (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('labels are localized in zh', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return Text(noteFlagColorLabel(NoteFlagColor.purple, l));
      }),
    ));
    expect(find.text('紫色'), findsOneWidget);
  });
}
```

Create `/Users/fchy/Projects/hmm_console/test/features/notes/presentation/note_detail_actions_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _RecordingMutate implements MutateNote {
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  HmmNote _n(int id) =>
      HmmNote(id: id, uuid: 'u$id', subject: 'My note', authorId: 1, createDate: DateTime(2026));

  @override
  Future<void> delete(int id) async => calls.add('delete $id');
  @override
  Future<HmmNote> restore(int id) async {
    calls.add('restore $id');
    return _n(id);
  }

  @override
  Future<HmmNote> setPinned(int id, bool pinned) async {
    calls.add('pin $id $pinned');
    return _n(id);
  }

  @override
  Future<HmmNote> setFlagColor(int id, int? flagColor) async {
    calls.add('flag $id $flagColor');
    return _n(id);
  }
}

NoteCatalog _catalog(String name) =>
    NoteCatalog(id: 1, name: name, schema: '{}', formatType: 3, isDefault: false);

Future<_RecordingMutate> _pump(WidgetTester tester,
    {String catalog = 'General', bool pinned = false, int? flag}) async {
  final mutate = _RecordingMutate();
  final note = HmmNote(
      id: 5, uuid: 'u5', subject: 'My note', authorId: 1, catalogId: 1,
      content: 'Hello body', createDate: DateTime(2026, 1, 1), isPinned: pinned, flagColor: flag);
  // A fresh key per pump: a second pump in one test gets a new scope with
  // its own overrides instead of updating the old one.
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      mutateNoteProvider.overrideWithValue(mutate),
      noteDetailProvider(5).overrideWith((ref) async => NoteDetailData(note, _catalog(catalog))),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(extensions: const [AppColors.light]),
      home: const NoteDetailScreen(noteId: 5),
    ),
  ));
  await tester.pumpAndSettle();
  return mutate;
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Show menu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the menu offers Pin, Flag… and Delete for an ordinary note', (tester) async {
    await _pump(tester);
    await _openMenu(tester);

    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Flag…'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.textContaining('Manage in'), findsNothing);
  });

  testWidgets('Pin calls setPinned(true); a pinned note offers Unpin', (tester) async {
    final mutate = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(mutate.calls, ['pin 5 true']);

    final pinnedMutate = await _pump(tester, pinned: true);
    expect(find.byIcon(Icons.push_pin), findsOneWidget, reason: 'pin shown by the title');
    await _openMenu(tester);
    await tester.tap(find.text('Unpin'));
    await tester.pumpAndSettle();
    expect(pinnedMutate.calls, ['pin 5 false']);
  });

  testWidgets('Flag… stores the chosen colour; Clear flag stores null', (tester) async {
    final mutate = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Flag…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue'));
    await tester.pumpAndSettle();
    expect(mutate.calls, ['flag 5 4']);

    final flagged = await _pump(tester, flag: 1);
    await _openMenu(tester);
    await tester.tap(find.text('Flag…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear flag'));
    await tester.pumpAndSettle();
    expect(flagged.calls, ['flag 5 null']);
  });

  testWidgets('Delete moves to Recently Deleted with Undo; Undo restores', (tester) async {
    final mutate = await _pump(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(mutate.calls, ['delete 5']);
    expect(find.text('Moved to Recently Deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(mutate.calls, ['delete 5', 'restore 5']);
    expect(find.text('Note restored'), findsOneWidget);
  });

  testWidgets('an entity note shows Manage in Automobile instead of Delete', (tester) async {
    final mutate = await _pump(tester, catalog: 'Hmm.AutomobileMan.GasLog');
    await _openMenu(tester);

    expect(find.text('Delete'), findsNothing);
    expect(find.text('Manage in Automobile'), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget, reason: 'pin works on every note');
    await tester.tap(find.text('Manage in Automobile'));
    await tester.pumpAndSettle();
    expect(mutate.calls, isEmpty);
  });

  testWidgets('the help button explains the menu', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    expect(find.text('Read a note and use the ⋯ menu to pin, flag, edit or delete it.'),
        findsOneWidget);
  });
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/features/notes/presentation/widgets/note_flag_sheet_test.dart test/features/notes/presentation/note_detail_actions_test.dart
```
Expected: compile error `Target of URI doesn't exist: 'package:hmm_console/features/notes/presentation/widgets/note_flag_sheet.dart'`.

- [ ] **Step 4: The flag sheet and labels**

Create `/Users/fchy/Projects/hmm_console/lib/features/notes/presentation/widgets/note_flag_sheet.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/notes/note_flag.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// What the flag sheet returns. A null [color] means "Clear flag"; a null
/// choice (the sheet dismissed / Cancel) means change nothing.
class NoteFlagChoice {
  const NoteFlagChoice(this.color);

  final NoteFlagColor? color;
}

/// Default (unrenamed) colour names. User-nameable flags arrive with the
/// synced settings in a later slice.
String noteFlagColorLabel(NoteFlagColor color, AppLocalizations l) =>
    switch (color) {
      NoteFlagColor.red => l.flagColorRed,
      NoteFlagColor.orange => l.flagColorOrange,
      NoteFlagColor.yellow => l.flagColorYellow,
      NoteFlagColor.green => l.flagColorGreen,
      NoteFlagColor.blue => l.flagColorBlue,
      NoteFlagColor.purple => l.flagColorPurple,
      NoteFlagColor.grey => l.flagColorGrey,
    };

bool _isApple(TargetPlatform p) =>
    p == TargetPlatform.iOS || p == TargetPlatform.macOS;

/// Pick a flag colour: a Cupertino action sheet on iOS/macOS, a Material
/// bottom sheet elsewhere. "Clear flag" appears only when [current] is set.
Future<NoteFlagChoice?> showNoteFlagSheet(BuildContext context,
    {NoteFlagColor? current}) {
  final l = AppLocalizations.of(context);
  if (_isApple(Theme.of(context).platform)) {
    return showCupertinoModalPopup<NoteFlagChoice>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l.notesFlagSheetTitle),
        actions: [
          for (final c in NoteFlagColor.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(NoteFlagChoice(c)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(c == current ? Icons.flag : Icons.flag_outlined, color: c.color),
                  const SizedBox(width: 8),
                  Text(noteFlagColorLabel(c, l)),
                ],
              ),
            ),
          if (current != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(const NoteFlagChoice(null)),
              child: Text(l.notesClearFlag),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l.commonCancel),
        ),
      ),
    );
  }
  return showModalBottomSheet<NoteFlagChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.notesFlagSheetTitle,
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final c in NoteFlagColor.values)
            ListTile(
              leading: Icon(c == current ? Icons.flag : Icons.flag_outlined,
                  color: c.color),
              title: Text(noteFlagColorLabel(c, l)),
              selected: c == current,
              onTap: () => Navigator.of(ctx).pop(NoteFlagChoice(c)),
            ),
          if (current != null)
            ListTile(
              leading: const Icon(Icons.outlined_flag),
              title: Text(l.notesClearFlag),
              onTap: () => Navigator.of(ctx).pop(const NoteFlagChoice(null)),
            ),
        ],
      ),
    ),
  );
}
```

Append to `lib/features/notes/presentation/catalog_labels.dart` (and add `import '../states/note_delete_policy.dart';` to its imports):

```dart

/// Localized name of the screen that manages an entity note (G7).
String managePlaceLabel(NoteManagePlace place, AppLocalizations l) =>
    switch (place) {
      NoteManagePlace.contacts => l.contactsTitle,
      NoteManagePlace.cheatsheets => l.cheatsheetWalletTitle,
      NoteManagePlace.automobile => l.domainAutomobile,
      NoteManagePlace.ownScreen => l.notesManagePlaceOwnScreen,
    };
```

- [ ] **Step 5: Help entry**

In `help_registry.dart`, add `noteDetail,` as the last value of `enum HelpId`, and before the final `};` of `helpFor` add:

```dart
  HelpId.noteDetail => ScreenHelp(
    title: l.helpNoteDetailTitle,
    summary: l.helpNoteDetailSummary,
    entries: [
      HelpEntry(
        icon: Icons.push_pin_outlined,
        title: l.helpNoteDetailPinTitle,
        body: l.helpNoteDetailPinBody,
      ),
      HelpEntry(
        icon: Icons.flag_outlined,
        title: l.helpNoteDetailFlagTitle,
        body: l.helpNoteDetailFlagBody,
      ),
      HelpEntry(
        icon: Icons.delete_outline,
        title: l.helpNoteDetailDeleteTitle,
        body: l.helpNoteDetailDeleteBody,
      ),
      HelpEntry(
        icon: Icons.open_in_new,
        title: l.helpNoteDetailManageTitle,
        body: l.helpNoteDetailManageBody,
      ),
    ],
  ),
```

- [ ] **Step 6: Rewrite the note detail screen**

Replace the whole of `lib/features/notes/presentation/screens/note_detail_screen.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/data/local/database.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/notes/editing/edit_dispatch.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/models/hmm_note.dart';
import '../../rendering/note_display.dart';
import '../../rendering/render_registry.dart';
import '../../states/mutate_note_state.dart';
import '../../states/note_delete_policy.dart';
import '../../states/note_selection.dart';
import '../catalog_labels.dart';
import '../widgets/markdown_view.dart';
import '../widgets/note_file_card_list.dart';
import '../widgets/note_flag_sheet.dart';
import '../widgets/note_location_card.dart';
import '../widgets/note_media_card_list.dart';

class NoteDetailData {
  const NoteDetailData(this.note, this.catalog);
  final HmmNote note;
  final NoteCatalog? catalog;
}

final noteDetailProvider =
    FutureProvider.family<NoteDetailData, int>((ref, id) async {
  final note = await ref.watch(hmmNoteRepositoryProvider).getNoteById(id);
  if (note == null) throw StateError('Note $id not found');
  NoteCatalog? catalog;
  final cid = note.catalogId;
  if (cid != null) {
    catalog = await ref.watch(noteCatalogRepositoryProvider).getCatalogById(cid);
  }
  return NoteDetailData(note, catalog);
});

enum _MenuAction { edit, raw, pin, flag, delete, manageIn }

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});
  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(noteDetailProvider(noteId));
    final registry = ref.watch(noteRenderRegistryProvider);
    final displayRegistry = ref.watch(noteDisplayRegistryProvider);
    final dispatch = ref.watch(editDispatchProvider);

    return AppScaffold(
      title: async.maybeWhen(
        data: (d) => catalogLabel(d.catalog?.name, l),
        orElse: () => 'Note',
      ),
      actions: [
        const HelpButton(helpId: HelpId.noteDetail),
        async.maybeWhen(
          data: (d) {
            final catalogName = d.catalog?.name;
            final canDelete = canDeleteFromNotes(d.note, catalogName);
            final place = managePlaceFor(catalogName) ?? NoteManagePlace.ownScreen;
            return PopupMenuButton<_MenuAction>(
              onSelected: (a) async {
                switch (a) {
                  case _MenuAction.edit:
                    dispatch.edit(context, catalogName, d.note);
                  case _MenuAction.raw:
                    context.push('/notes/$noteId/raw');
                  case _MenuAction.pin:
                    await _togglePin(context, ref, l, d.note);
                  case _MenuAction.flag:
                    await _chooseFlag(context, ref, l, d.note);
                  case _MenuAction.delete:
                    await _delete(context, ref, l);
                  case _MenuAction.manageIn:
                    break; // informational row: the item is disabled
                }
              },
              itemBuilder: (context) => [
                if (dispatch.canEdit(catalogName))
                  PopupMenuItem(
                      value: _MenuAction.edit,
                      child: _MenuRow(Icons.edit_outlined, l.notesEditAction)),
                PopupMenuItem(
                    value: _MenuAction.raw,
                    child: _MenuRow(Icons.code, l.notesViewRaw)),
                PopupMenuItem(
                    value: _MenuAction.pin,
                    child: _MenuRow(Icons.push_pin_outlined,
                        d.note.isPinned ? l.notesUnpin : l.notesPin)),
                PopupMenuItem(
                    value: _MenuAction.flag,
                    child: _MenuRow(Icons.flag_outlined, l.notesFlagAction)),
                if (canDelete)
                  PopupMenuItem(
                      value: _MenuAction.delete,
                      child: _MenuRow(Icons.delete_outline, l.commonDelete))
                else
                  // G7: entity notes are deleted from their own screen.
                  PopupMenuItem(
                      enabled: false,
                      value: _MenuAction.manageIn,
                      child: _MenuRow(Icons.open_in_new,
                          l.notesManageIn(managePlaceLabel(place, l)))),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (d) {
              final markdown = _safeRender(registry, d.catalog?.name, d.note);
              // Images referenced inline in the body render in place (via
              // MarkdownView); exclude them from the trailing cards so they
              // aren't shown twice.
              final inlinePaths = imageRefPathsIn(markdown).toSet();
              bool notInline(AttachmentRef r) =>
                  r is! VaultRef || !inlinePaths.contains(r.path);
              final atts = <AttachmentRef>[
                if (d.note.effectiveAttachments.primaryImage != null &&
                    notInline(d.note.effectiveAttachments.primaryImage!))
                  d.note.effectiveAttachments.primaryImage!,
                ...d.note.effectiveAttachments.images.where(notInline),
              ];
              final flag = d.note.flag;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      if (d.note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.push_pin,
                              size: 18, semanticLabel: l.notesPinnedLabel),
                        ),
                      if (flag != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.flag,
                              size: 18,
                              color: flag.color,
                              semanticLabel: l.notesFlaggedLabel(
                                  noteFlagColorLabel(flag, l))),
                        ),
                      Expanded(
                        child: Text(
                            displayRegistry.title(d.note, d.catalog?.name, l),
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (atts.isNotEmpty)
                    NoteMediaCardList(saved: atts, readOnly: true),
                  if (d.note.effectiveAttachments.files.isNotEmpty)
                    NoteFileCardList(
                        saved: d.note.effectiveAttachments.files,
                        readOnly: true),
                  if (d.note.location != null)
                    NoteLocationCard(
                        location: d.note.location!, readOnly: true),
                  const SizedBox(height: 12),
                  MarkdownView(markdown),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Delete = move to Recently Deleted, with Undo (restore). Everything the
  /// snackbar's Undo needs is captured before the first await.
  Future<void> _delete(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final mutate = ref.read(mutateNoteProvider);
    final selection = ref.read(selectedNoteIdProvider.notifier);
    final navigator = Navigator.of(context);
    final isWide =
        MediaQuery.of(context).size.width >= kNotesWideBreakpoint;
    var moved = false;
    await showUndoableAction(
      context,
      busyKey: ('deleteNote', noteId),
      run: () async {
        await mutate.delete(noteId);
        moved = true;
      },
      undo: () async {
        await mutate.restore(noteId);
      },
      done: l.notesMovedToRecentlyDeleted,
      failed: l.notesDeleteFailed,
      undone: l.notesRestored,
      undoFailed: l.notesRestoreFailed,
    );
    if (!moved) return;
    if (isWide) {
      selection.select(null);
    } else {
      unawaited(navigator.maybePop());
    }
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref,
      AppLocalizations l, HmmNote note) async {
    final messenger = ScaffoldMessenger.of(context);
    final mutate = ref.read(mutateNoteProvider);
    final container = ProviderScope.containerOf(context);
    try {
      await mutate.setPinned(noteId, !note.isPinned);
      container.invalidate(noteDetailProvider(noteId));
    } catch (e) {
      debugPrint('NoteDetailScreen: pin failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.notesPinFailed)));
    }
  }

  Future<void> _chooseFlag(BuildContext context, WidgetRef ref,
      AppLocalizations l, HmmNote note) async {
    final messenger = ScaffoldMessenger.of(context);
    final mutate = ref.read(mutateNoteProvider);
    final container = ProviderScope.containerOf(context);
    final choice = await showNoteFlagSheet(context, current: note.flag);
    if (choice == null) return; // dismissed: change nothing
    try {
      await mutate.setFlagColor(noteId, choice.color?.stored);
      container.invalidate(noteDetailProvider(noteId));
    } catch (e) {
      debugPrint('NoteDetailScreen: flag failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.notesFlagFailed)));
    }
  }

  /// Renderers must not throw, but isolate anyway: fall back to a banner +
  /// generic view rather than crashing the read screen.
  String _safeRender(
      NoteRenderRegistry registry, String? catalogName, HmmNote note) {
    try {
      return registry.rendererFor(catalogName).render(note);
    } catch (_) {
      return '> ⚠️ Couldn\'t render this note\'s format. Use **View raw content** to inspect it.';
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Flexible(child: Text(label)),
        ],
      );
}
```

Notes for the implementer:
- `showUndoableAction` shows `failed` when `mutate.delete` throws, including `EntityNoteDeleteRefused` — unreachable from this menu (the item is replaced by "Manage in …"), but safe.
- The `noteDetailProvider` invalidation after pin/flag uses the `ProviderContainer` captured before the await, never the `WidgetRef`.

- [ ] **Step 7: Run tests and analyze**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/features/notes/ test/core/help/
flutter analyze
```
Expected: `All tests passed!` — including the pre-existing `note_detail_screen_test.dart` (Edit / View raw content / Delete still present), `notes_shell_delete_test.dart` (wide delete still clears the pane), `help_registry_test.dart` (new `HelpId.noteDetail` complete in en and zh, zh summary differs) and `icon_button_guard_test.dart` (no raw `IconButton`); analyze at the 2 pre-existing infos.

- [ ] **Step 8: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/gen \
  lib/features/notes/presentation/widgets/note_flag_sheet.dart lib/features/notes/presentation/catalog_labels.dart \
  lib/features/notes/presentation/screens/note_detail_screen.dart lib/core/help/help_registry.dart \
  test/features/notes/presentation/note_detail_actions_test.dart \
  test/features/notes/presentation/widgets/note_flag_sheet_test.dart
git commit -m "$(cat <<'MSG'
feat(notes): detail menu Pin/Flag, undoable Delete, Manage in … for entity notes

Delete now moves the note to Recently Deleted with Undo instead of deleting
instantly; entity notes say where they are managed (G7). Help entry added.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 12: Docs — correct CLAUDE.md "Key Packages"

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/CLAUDE.md` (Key Packages, line 158)

**Interfaces:** none.

- [ ] **Step 1: Verify the claim is wrong**

```bash
cd /Users/fchy/Projects/hmm_console
grep -n "slidable\|share_plus" pubspec.yaml || echo "neither is a dependency"
```
Expected: `neither is a dependency`.

- [ ] **Step 2: Fix the line**

In `CLAUDE.md` replace

```
  - `flutter_slidable`: swipe actions on list items
```

with

```
- `flutter_slidable` / `share_plus`: **not pubspec dependencies yet** — the Notes list redesign adds them in later slices (swipe actions; the system share sheet). Do not import them before then.
```

- [ ] **Step 3: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add CLAUDE.md
git commit -m "$(cat <<'MSG'
docs(claude): flutter_slidable and share_plus are not dependencies yet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 13: Verification + deploy checklist (no deploy performed)

**Files:** none modified.

**Interfaces:** none.

- [ ] **Step 1: Backend — full suites and build on the feature branch**

```bash
cd /Users/fchy/Projects/hmm
git branch --show-current                                   # feat/notes-pin-flag-undelete
git status --short                                          # only " M CLAUDE.md"
dotnet build Hmm.sln 2>&1 | tail -2                         # Build succeeded, 0 Error(s)
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1               # Passed: 241 (baseline 233)
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1    # Passed: 469 (baseline 440)
dotnet test src/Hmm.Core.Dal.EF.Tests 2>&1 | tail -1        # Passed: 75 (baseline 68)
git log --oneline main..HEAD                                # 4 commits (Tasks 1-4)
```

- [ ] **Step 2: Client — full suite and analyzer**

```bash
cd /Users/fchy/Projects/hmm_console
git branch --show-current     # feat/notes-list-redesign
flutter analyze               # exactly the 2 pre-existing infos
flutter test 2>&1 | tail -1   # All tests passed! — count > 2314 (baseline)
git log --oneline 126f53a..HEAD   # 8 commits (Tasks 5-12)
```

- [ ] **Step 3: Local end-to-end smoke against the test backend (optional, recommended)**

```bash
cd /Users/fchy/Projects/hmm/docker && ./test-env.sh
```
Then run the app on the iOS simulator in Cloud (API) mode: pin a note and flag it from the detail ⋯ menu, sync, and confirm with `GET /v1/notes?pinned=true` that it is pinned server-side; delete it, tap Undo, sync, and confirm the server row is live (`GET /v1/notes/by-uuid/{uuid}`). In Cloud Storage mode confirm the OneDrive note blob contains `isPinned` / `flagColor`.

- [ ] **Step 4: Record the deploy checklist (for the human; do NOT execute here)**

**Order is mandatory: server first, then client.** A client release that writes `isPinned`/`flagColor`/tags or calls `/restore`, `/purge`, `/tags` before the server has them would sync against an API that silently drops pins (old `PUT`) and cannot restore or purge.

1. Merge `hmm` branch `feat/notes-pin-flag-undelete` to `main` after review (never stage `hmm/CLAUDE.md`).
2. Back up the production PostgreSQL database on the VPS (use the `hmm-deployer` agent's pre-deploy backup).
3. Deploy the `hmm` API to the VPS. On startup `AutomobileAppStartupFilter` runs `Database.Migrate()` and logs **"PostgreSQL migrations applied"** — confirm that line, and that `20261018000000_AddNotePinAndFlagColumns` is in `__EFMigrationsHistory`.
4. Smoke-test production with a real token: `GET /v1/notes?pinned=true` → 200; `GET /v1/notes/by-uuid/{uuid}` body has `isPinned`, `flagColor`, `tagNames`; `POST /v1/notes/{id}/restore` on a deleted note → 200; `PUT /v1/notes/{id}/tags {"names":[]}` → 200; `DELETE /v1/notes/{id}/purge` on a live note → 409.
5. Only then merge `hmm_console` `feat/notes-list-redesign` (slice 1) and build the client with the production dart-defines (`scripts/deploy-prod-ios-device.sh` — a plain `flutter build` points at localhost).
6. After the client release, watch one sync cycle per mode for `recordType: 'purge'` errors and for "The server cannot restore deleted notes yet" (means step 3 did not land).
