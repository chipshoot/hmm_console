# Notes Redesign — Slice 1: Data, Flags & Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every note a pin and a coloured flag that survive all three data modes **without ever being a note edit** (G14: a per-user note-state table), make delete recoverable (server undelete + client restore with Undo) and finite (real 30-day purge with vault release), make tags sync in cloudApi mode, and stop Notes from deleting entity notes — without any new list UI (that is slice 2+).

**Architecture:** Server first (`hmm`, branch `feat/notes-pin-flag-undelete`): a new `noteuserstates` table (`NoteUserStateDao`, PK `(AuthorId, NoteId)`, FK to the note with cascade delete) behind `INoteUserStateRepository` (newer-`LastModifiedDate`-wins upsert), `GET /v1/notes/states` + `PUT /v1/notes/{id}/state` (caller-only, 404 for a note the caller does not own), `POST /v1/notes/{id}/restore`, `DELETE /v1/notes/{id}/purge`, and a set-replace `GET|PUT /v1/notes/{id}/tags` backed by a new `INoteTagMembershipRepository` (the existing `applyTag` path cannot persist on EF — see Task 4). Note DTOs gain **no** pin/flag fields. Client (`hmm_console`, branch `feat/notes-list-redesign`): Drift v8→v9 creates a `NoteStates` table keyed by note uuid (no note column changes), `NoteState` + `LocalNoteStateRepository` (`setPinned`/`setFlagColor` never touch the note row), repository `restoreNote`, a `NoteStateSyncService` merge (per entry, newer wins, tie keeps local, purged notes dropped) run by the orchestrator against OneDrive `note-states.json` or the API state endpoints (a 404 keeps local state and sets a "server too old" flag), `ApiSyncProvider` wiring (states, restore, tags, purge), a `NotePurgeService` + `NotePurgeScheduler` that run outside sync through a new `SyncController.runExclusive`, the G7 delete guard, and the note-detail menu (Pin, Flag…, undoable Delete, "Manage in …", Help).

**Tech Stack:** Flutter 3 / Dart 3, Riverpod, Drift (SQLite), Dio + http_mock_adapter, flutter_test; .NET 10, ASP.NET Core, EF Core (PostgreSQL in prod, SQLite in-memory in `Hmm.Core.Dal.EF.Tests`), AutoMapper, Newtonsoft.Json, xUnit v2 + Moq.

**Spec:** docs/superpowers/specs/2026-10-18-notes-list-redesign-design.md (section "Note state: pins and flags (separate table — G14)" is authoritative for everything pin/flag).

## Global Constraints

- **Pin and flag are note state, never a note edit (G14).** Nothing in this plan adds a pin or flag column, DTO field or blob key to a note. Setting a pin or flag never changes the note's `version`, `lastModifiedDate` or sync cursor position and never re-pushes the note; it writes only the state row (and asks for a debounced sync of states).
- Drift `schemaVersion` 8 → 9 creates the `note_states` table (`NoteStates`: `noteUuid` TEXT primary key, `isPinned` bool default false, `flagColor` int?, `lastModifiedDate`) and touches no other table. No row = unpinned and unflagged.
- Server table `noteuserstates` (`authorid`, `noteid`, `ispinned` default false, `flagcolor` nullable, `lastmodifieddate`), PK `(authorid, noteid)`, FK `noteid → notes.id` ON DELETE CASCADE. Lower-case naming follows the existing tables (`notes`, `authorsettings`); the spec's "NoteUserStates" is this table.
- `isPinned`: `bool`, default `false`. `flagColor`: `int?`, `null` = unflagged; 0 red, 1 orange, 2 yellow, 3 green, 4 blue, 5 purple, 6 grey; any other int is stored verbatim everywhere and shown as grey (`NoteFlagColor.fromStored`).
- Unpin / unflag **write** a row (`isPinned = false` / `flagColor = null`); only a purge (or the sync merge dropping a purged note's entry) removes a state row. Soft delete and restore leave state rows alone.
- State last-writer-wins is per entry by `lastModifiedDate`: newer wins, a tie keeps what the receiver has (client merge: local; server PUT: stored). A local state write stamps at least the next whole second after the row's previous stamp (`restoreStamp`), because Drift stores whole seconds.
- The pulled note body's `tags` key: present ⇒ set-replace, absent ⇒ keep local membership (an older client or a server that predates note tags).
- Entity notes are never deleted from Notes (G7): only `General` (or a legacy row with no catalog) passes `canDeleteFromNotes`. Pin and flag work on every note.
- Recently Deleted = ordinary notes only (G11) — the list itself is slice 5; slice 1 only makes delete reversible.
- Purge after 30 days applies to ALL soft-deleted notes (G11), runs at most once a day, never while a sync runs (`SyncController.runExclusive`), and removes the note's state row in every mode.
- Logs carry ids and error types only (`${e.runtimeType}`), never note content, names or vault paths.
- Icon buttons: `HmmIconButton` only (no raw `IconButton`; `test/core/help/icon_button_guard_test.dart` must stay green).
- Hide/move actions use `showUndoableAction`; permanent deletes keep a confirmation dialog (none in slice 1 UI).
- Every new string in `lib/l10n/app_en.arb` AND `lib/l10n/app_zh.arb` (parity), then `flutter gen-l10n`.
- Platform branching via `Theme.of(context).platform` (iOS/macOS → Cupertino, else Material).
- `flutter analyze` stays at exactly the 2 pre-existing infos (`lib/features/onboarding/presentation/screens/onboarding_screen.dart` prefer_const_constructors_in_immutables, `lib/main.dart` use_null_aware_elements).
- `flutter test` baseline recorded 2026-10-18 on `feat/notes-list-redesign` @126f53a: **2314 passed, 0 failed**. The count may only grow.
- Backend baselines recorded 2026-10-18 on `hmm` main @0734684: `Hmm.Core.Tests` **233 passed**, `Hmm.ServiceApi.Core.Tests` **440 passed**, `Hmm.Core.Dal.EF.Tests` **68 passed**, 0 failed. Counts may only grow.
- Backend work only in `/Users/fchy/Projects/hmm` on branch `feat/notes-pin-flag-undelete` (created from `main` in Task 1); never commit on `main`; never stage `/Users/fchy/Projects/hmm/CLAUDE.md` (unrelated uncommitted change) — always `git add <explicit paths>`.
- The server (Tasks 1–4) is deployed to the VPS before any client release that uses note states, restore, purge or note tags.
- Every commit message ends with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No `git push`, no merge, no deploy anywhere in this plan.

## Review Focus

1. **A pin on device A and a text edit on device B must both survive.** The pin lives only in the state row, so it never bumps the note and never re-pushes it; B's newer note blob applies to A's note row while A's state row is untouched, and the merged state document carries A's pin back to B. Owning tests: Task 5 `setPinned and setFlagColor never touch the note row`, Task 6 `a pin on this device and a text edit on another both survive` + `a remote pin applies without touching the local note row`.
2. **Unpin propagates.** Unpin writes a row with `isPinned = false` and a newer stamp — never a deletion — so the merge sees a newer entry and peers unpin. A pin then unpin inside one second still gets a strictly later stamp. Owning tests: Task 5 `unpin writes a row with false, never deletes it` + `a second write in the same second still gets a later stamp`, Task 6 `a newer local unpin beats an older remote pin` + `a newer remote unpin is applied as a false row`.
3. **An old server (404 on `GET /v1/notes/states`) keeps local state.** The API provider maps 404/405 to `NoteStatesUnsupportedException`; the orchestrator then writes and pushes nothing, keeps every local row, records no sync error and sets `SyncMetaRepository.getNoteStatesUnsupported` (the later "Pins and flags need the latest server" banner reads it); the next sync against a new server pushes every local state because the server has none. Owning tests: Task 6 `an old server keeps local state and sets the unsupported flag`, Task 7 `a server without the states endpoint is reported as unsupported`.
4. **A state for a purged note resurrects nothing.** Purge deletes the local state row in every mode; the merge treats a content-free tombstone (or a note unknown locally and not live in the remote manifest) as "no note", so a peer's stale entry is neither applied nor pushed back, and the note row stays a tombstone. Owning tests: Task 6 `a state for a purged note is dropped and never revives the note`, Task 8 `purge removes the note's state row` (local and cloudStorage) + `calls the server purge, then deletes the row and its state`.
5. **Another user's note cannot be pinned via PUT.** `PUT /v1/notes/{id}/state` resolves the caller from the token and 404s (same as a missing note) unless the caller owns the note; `GET /v1/notes/states` only ever queries the caller's `AuthorId`. Owning tests: Task 2 `PutState_on_another_authors_note_is_NotFound_and_saves_nothing`, `GetStates_returns_only_the_callers_rows`; Task 1 `Each_author_has_their_own_state_for_the_same_note`.
6. **Restore on a OneDrive device against a tombstone with an equal timestamp.** Drift stores `DateTime` at 1-second resolution, so a restore in the same second as its delete would tie and last-writer-wins would keep the tombstone on peers. `restoreNote` stamps at least the next whole second. Owning tests: Task 5 `restoreStamp` cases and Task 6 `a restore made in the same second as its delete still wins on peers` + `equal timestamps keep the local tombstone (documented tie)`.
7. **Purge never deletes a note that was restored seconds earlier.** Every purge write is guarded by `deletedAt = <value read>`; the server purge refuses a live note (409 → `NoteLiveOnServerException`); OneDrive blob deletion is deferred into the next sync and skipped when the pull revived the note. Owning tests: Task 8 `a restore that lands during the purge wins`, `keeps the row when the server says the note is live`, `a note restored on another device is revived, never purged remotely`.
8. **An entity note reached via the detail screen cannot be deleted generically.** `MutateNote.delete` refuses (throws `EntityNoteDeleteRefused`) and the menu shows "Manage in …" instead of Delete. Owning tests: Task 10 `delete refuses an entity note and leaves it live`, Task 11 `an entity note shows Manage in Automobile instead of Delete`.
9. **A server still running the old build (no `tagNames`) must not make the client drop tags.** The provider omits `tags` from the pulled body when the server sent no `tagNames`, and the orchestrator keeps local membership for an absent key. Owning tests: Task 7 `an old server (no tagNames) yields a body without a tags key` + Task 6 `an absent tags key keeps membership; a present empty list clears it`.

---

### Task 1: Server — `NoteUserStates` table, migration and newer-wins repository

Pins and flags are the user's own state about a note (G14), so they get their own table instead of note columns: a pin can then never overwrite a concurrent text edit under whole-note last-writer-wins, never moves the note in the Last-modified sort, and is already per user for Sharing (Project 3). The table mirrors the existing `authorsettings` satellite: hand-written migration, a `LastModifiedDate` monotonicity guard instead of a row-version token, no `Description` column (the DAO does not derive from `Entity`, like `NoteTagRefDao`).

**Files:**
- Create: `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/DbEntity/NoteUserStateDao.cs`
- Create: `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/DomainEntity/NoteUserState.cs`
- Create: `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/Repositories/INoteUserStateRepository.cs`
- Create: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Repositories/NoteUserStateEfRepository.cs`
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/HmmDataContext.cs` (`ForeignKeyNames` / `IndexNames` constants; `DbSet` after `AuthorSettings`; model configuration at the end of `OnModelCreating`)
- Create: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Migrations/20261018000000_AddNoteUserStatesTable.cs`
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs` (new entity after `NoteTagRefDao`, ~line 357; new relationship block after the `NoteTagRefDao` relationships, ~line 461)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF.Tests/NoteUserStateRepositoryTests.cs` (create)

**Interfaces:**
- Consumes: `DbTestFixtureBase` (`DbContext`, `NoteRepository`, `CatalogRepository`, `ContactRepository`, `AuthorRepository`), `IHmmDataContext.CommitAsync`.
- Produces (C#):
  - `NoteUserStateDao { int AuthorId (authorid); int NoteId (noteid); HmmNoteDao? Note; bool IsPinned (ispinned); int? FlagColor (flagcolor); DateTime LastModifiedDate (lastmodifieddate) }` — table `noteuserstates`, PK `(AuthorId, NoteId)`, FK `fk_noteuserstates_notes` (cascade), FK `fk_noteuserstates_authors` (no action), index `ix_noteuserstates_noteid`.
  - `NoteUserState { int AuthorId; int NoteId; string? NoteUuid; bool IsPinned; int? FlagColor; DateTime LastModifiedDate }` (domain, `Hmm.Core.Map.DomainEntity`; `NoteUuid` is a read-only projection of the note's uuid).
  - `namespace Hmm.Core.Map.Repositories; public interface INoteUserStateRepository { Task<IReadOnlyList<NoteUserState>> GetForAuthorAsync(int authorId); Task<NoteUserState> SaveIfNewerAsync(NoteUserState incoming); }` — `SaveIfNewerAsync` inserts the first row, replaces a row only when `incoming.LastModifiedDate` is strictly newer (equal or older keeps stored), commits, and returns the stored row; a non-UTC stamp is normalised to UTC (an `Unspecified` kind is taken as UTC).

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

- [ ] **Step 2: Write the failing repository tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF.Tests/NoteUserStateRepositoryTests.cs`:

```csharp
using Hmm.Core.Dal.EF.Repositories;
using Hmm.Core.Map.DbEntity;
using Hmm.Core.Map.DomainEntity;
using Hmm.Utility.TestHelp;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Threading.Tasks;
using Xunit;

namespace Hmm.Core.Dal.EF.Tests
{
    /// <summary>
    /// Notes redesign G14: pins and flags live in their own per-user table
    /// and are never a note edit. Real EF context (SQLite in-memory).
    /// </summary>
    public class NoteUserStateRepositoryTests : DbTestFixtureBase, IAsyncLifetime
    {
        private static readonly DateTime T1 = new(2026, 10, 18, 9, 0, 0, DateTimeKind.Utc);
        private static readonly DateTime T2 = T1.AddMinutes(5);

        private AuthorDao _author = null!;
        private AuthorDao _otherAuthor = null!;
        private NoteCatalogDao _catalog = null!;
        private NoteUserStateEfRepository _states = null!;

        private DbContext Ef => (DbContext)DbContext;

        // Each call is a fresh request scope in production; clear the tracker
        // so nothing is served from memory instead of the database.
        private void NewRequestScope() => Ef.ChangeTracker.Clear();

        private async Task<HmmNoteDao> AddNoteAsync(string uuid)
        {
            var note = new HmmNoteDao
            {
                Author = _author, Catalog = _catalog, Subject = "stateful", Content = "c", Uuid = uuid,
            };
            await NoteRepository.AddAsync(note);
            await DbContext.CommitAsync();
            NewRequestScope();
            return note;
        }

        private Task<NoteUserState> Save(int authorId, int noteId, bool pinned, int? flag, DateTime at)
        {
            NewRequestScope();
            return _states.SaveIfNewerAsync(new NoteUserState
            {
                AuthorId = authorId, NoteId = noteId, IsPinned = pinned, FlagColor = flag, LastModifiedDate = at,
            });
        }

        [Fact]
        public async Task Save_inserts_the_first_state_and_returns_it_with_the_note_uuid()
        {
            var note = await AddNoteAsync("u-first");

            var saved = await Save(_author.Id, note.Id, pinned: true, flag: 3, at: T1);

            Assert.True(saved.IsPinned);
            Assert.Equal(3, saved.FlagColor);
            Assert.Equal(T1, saved.LastModifiedDate);
            Assert.Equal("u-first", saved.NoteUuid);
            Assert.Equal(1, await DbContext.Set<NoteUserStateDao>().CountAsync());
        }

        [Fact]
        public async Task A_newer_write_replaces_the_stored_state()
        {
            var note = await AddNoteAsync("u-newer");
            await Save(_author.Id, note.Id, pinned: true, flag: 3, at: T1);

            var saved = await Save(_author.Id, note.Id, pinned: false, flag: null, at: T2);

            Assert.False(saved.IsPinned);
            Assert.Null(saved.FlagColor);
            Assert.Equal(T2, saved.LastModifiedDate);
        }

        [Fact]
        public async Task An_older_or_equal_write_keeps_the_stored_state()
        {
            var note = await AddNoteAsync("u-older");
            await Save(_author.Id, note.Id, pinned: true, flag: 3, at: T2);

            var older = await Save(_author.Id, note.Id, pinned: false, flag: 0, at: T1);
            Assert.True(older.IsPinned);
            Assert.Equal(3, older.FlagColor);
            Assert.Equal(T2, older.LastModifiedDate);

            var tie = await Save(_author.Id, note.Id, pinned: false, flag: 0, at: T2);
            Assert.True(tie.IsPinned, "a tie keeps the stored row");
            Assert.Equal(3, tie.FlagColor);
        }

        [Fact]
        public async Task Unpin_is_stored_as_a_row_with_false()
        {
            var note = await AddNoteAsync("u-unpin");
            await Save(_author.Id, note.Id, pinned: true, flag: null, at: T1);

            await Save(_author.Id, note.Id, pinned: false, flag: null, at: T2);

            NewRequestScope();
            var row = await DbContext.Set<NoteUserStateDao>().SingleAsync();
            Assert.False(row.IsPinned);
            Assert.Equal(T2, row.LastModifiedDate);
        }

        [Fact]
        public async Task An_unknown_flag_value_is_kept_verbatim()
        {
            // A newer client may use colours this server has never heard of.
            var note = await AddNoteAsync("u-flag42");

            var saved = await Save(_author.Id, note.Id, pinned: false, flag: 42, at: T1);

            Assert.Equal(42, saved.FlagColor);
        }

        [Fact]
        public async Task Each_author_has_their_own_state_for_the_same_note()
        {
            var note = await AddNoteAsync("u-shared");
            await Save(_author.Id, note.Id, pinned: true, flag: null, at: T1);
            await Save(_otherAuthor.Id, note.Id, pinned: false, flag: 5, at: T2);

            NewRequestScope();
            var mine = await _states.GetForAuthorAsync(_author.Id);
            var theirs = await _states.GetForAuthorAsync(_otherAuthor.Id);

            var m = Assert.Single(mine);
            Assert.Equal(_author.Id, m.AuthorId);
            Assert.True(m.IsPinned);
            Assert.Null(m.FlagColor);
            Assert.Equal("u-shared", m.NoteUuid);
            var t = Assert.Single(theirs);
            Assert.False(t.IsPinned);
            Assert.Equal(5, t.FlagColor);
        }

        [Fact]
        public async Task Saving_a_state_leaves_the_note_row_unchanged()
        {
            var note = await AddNoteAsync("u-untouched");
            NewRequestScope();
            var before = await DbContext.Set<HmmNoteDao>().AsNoTracking().SingleAsync(n => n.Id == note.Id);

            await Save(_author.Id, note.Id, pinned: true, flag: 1, at: T2);

            NewRequestScope();
            var after = await DbContext.Set<HmmNoteDao>().AsNoTracking().SingleAsync(n => n.Id == note.Id);
            Assert.Equal(before.LastModifiedDate, after.LastModifiedDate);
            Assert.Equal(before.Version, after.Version);
            Assert.Equal(before.Subject, after.Subject);
        }

        [Fact]
        public async Task Hard_deleting_the_note_cascades_its_states()
        {
            // The Task 3 purge removes the note through NoteRepository.DeleteAsync;
            // the state rows must go with it, for every author.
            var note = await AddNoteAsync("u-purged");
            await Save(_author.Id, note.Id, pinned: true, flag: null, at: T1);
            await Save(_otherAuthor.Id, note.Id, pinned: true, flag: 2, at: T1);
            NewRequestScope();

            await NoteRepository.DeleteAsync(new HmmNoteDao { Id = note.Id, Subject = "stateful" });
            await DbContext.CommitAsync();

            NewRequestScope();
            Assert.Equal(0, await DbContext.Set<NoteUserStateDao>().CountAsync());
        }

        public async Task InitializeAsync()
        {
            if (Ef.Database.IsSqlite())
            {
                // Production is PostgreSQL, which always enforces FKs. Make the
                // in-memory database do the same so the cascade is really tested.
                await Ef.Database.ExecuteSqlRawAsync("PRAGMA foreign_keys = ON;");
            }

            _catalog = (await CatalogRepository.AddAsync(new NoteCatalogDao
            {
                Name = "state-dal-test-catalog", Schema = "", FormatType = NoteContentFormatType.PlainText,
                IsDefault = true, Description = "note state test catalog",
            })).Value;
            var contact = (await ContactRepository.AddAsync(new ContactDao
            {
                Contact = "{ \"FirstName\": \"Note\", \"LastName\": \"State\" }", Description = "state contact", IsActivated = true,
            })).Value;
            _author = (await AuthorRepository.AddAsync(new AuthorDao
            {
                AccountName = "state-dal-test", ContactInfo = contact, Description = "state author", IsActivated = true,
            })).Value;
            _otherAuthor = (await AuthorRepository.AddAsync(new AuthorDao
            {
                AccountName = "state-dal-test-other", ContactInfo = contact, Description = "other author", IsActivated = true,
            })).Value;
            await DbContext.CommitAsync();
            NewRequestScope();
            _states = new NoteUserStateEfRepository(DbContext);
        }

        public Task DisposeAsync() => Task.CompletedTask;
    }
}
```

(No transaction here, unlike some older fixtures: SQLite ignores `PRAGMA foreign_keys` inside a transaction, and every test instance already gets its own in-memory database.)

- [ ] **Step 3: Run the tests to verify they fail**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.Core.Dal.EF.Tests --filter "FullyQualifiedName~NoteUserStateRepositoryTests" 2>&1 | tail -5
```
Expected: build FAILS with `error CS0246: The type or namespace name 'NoteUserStateEfRepository' could not be found` (and the same for `NoteUserStateDao` / `NoteUserState`).

- [ ] **Step 4: Add the DAO, the domain type and the repository interface**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/DbEntity/NoteUserStateDao.cs`:

```csharp
// Ignore Spelling: Dao

using System;
using System.ComponentModel.DataAnnotations.Schema;

namespace Hmm.Core.Map.DbEntity;

/// <summary>
/// One user's own state about one note — pin and coloured flag (Notes
/// redesign G14). Deliberately NOT columns on <see cref="HmmNoteDao"/>:
/// changing a pin or flag is not a note edit, so it never bumps the note's
/// version or LastModifiedDate and can never overwrite a concurrent text
/// edit. Key (AuthorId, NoteId); the FK to the note cascades, so a purge
/// removes every user's state with the note.
/// </summary>
/// <remarks>
/// Like <see cref="AuthorSettingsDao"/>, conflicts resolve by the
/// <see cref="LastModifiedDate"/> monotonicity guard in the repository, not a
/// row-version token. Does not derive from <c>Entity</c> (no Id, no
/// Description), like <see cref="NoteTagRefDao"/>.
/// </remarks>
public class NoteUserStateDao
{
    [Column("authorid")]
    public int AuthorId { get; set; }

    [Column("noteid")]
    public int NoteId { get; set; }

    public HmmNoteDao? Note { get; set; }

    [Column("ispinned")]
    public bool IsPinned { get; set; }

    /// <summary>
    /// null = unflagged; 0 red, 1 orange, 2 yellow, 3 green, 4 blue,
    /// 5 purple, 6 grey. Any other value (a newer client) is stored verbatim.
    /// </summary>
    [Column("flagcolor")]
    public int? FlagColor { get; set; }

    /// <summary>The client's last-writer-wins clock for this state (UTC).</summary>
    [Column("lastmodifieddate")]
    public DateTime LastModifiedDate { get; set; }
}
```

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/DomainEntity/NoteUserState.cs`:

```csharp
using System;

namespace Hmm.Core.Map.DomainEntity;

/// <summary>
/// A user's pin + flag for one note (Notes redesign G14). Not part of
/// <see cref="HmmNote"/>: note DTOs never carry it.
/// </summary>
public class NoteUserState
{
    public int AuthorId { get; set; }

    public int NoteId { get; set; }

    /// <summary>
    /// The note's cross-device uuid (read-only projection, filled on reads;
    /// null for a legacy note that has none yet). Clients key states by it.
    /// </summary>
    public string? NoteUuid { get; set; }

    public bool IsPinned { get; set; }

    /// <summary>null = unflagged; unknown values are kept verbatim.</summary>
    public int? FlagColor { get; set; }

    /// <summary>Per-state last-writer-wins clock (UTC).</summary>
    public DateTime LastModifiedDate { get; set; }
}
```

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Map/Repositories/INoteUserStateRepository.cs`:

```csharp
using System.Collections.Generic;
using System.Threading.Tasks;
using Hmm.Core.Map.DomainEntity;

namespace Hmm.Core.Map.Repositories
{
    /// <summary>
    /// Per-user note state (pins + flags, Notes redesign G14). Callers pass
    /// the signed-in author's id; the repository never decides who the
    /// caller is, and never touches the note row.
    /// </summary>
    public interface INoteUserStateRepository
    {
        /// <summary>Every state row of <paramref name="authorId"/>, ordered by note id.</summary>
        Task<IReadOnlyList<NoteUserState>> GetForAuthorAsync(int authorId);

        /// <summary>
        /// Upsert by (AuthorId, NoteId) with last-writer-wins: the first row is
        /// inserted; a stored row is replaced only when
        /// <paramref name="incoming"/>.LastModifiedDate is strictly newer
        /// (equal or older keeps the stored row). Commits. Returns the stored
        /// row after the guard — the caller's own write, or the newer one that
        /// beat it.
        /// </summary>
        Task<NoteUserState> SaveIfNewerAsync(NoteUserState incoming);
    }
}
```

- [ ] **Step 5: Add the EF implementation**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Repositories/NoteUserStateEfRepository.cs`:

```csharp
using Hmm.Core.Map.DbEntity;
using Hmm.Core.Map.DomainEntity;
using Hmm.Core.Map.Repositories;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Hmm.Core.Dal.EF.Repositories
{
    public class NoteUserStateEfRepository : INoteUserStateRepository
    {
        private readonly IHmmDataContext _dataContext;

        public NoteUserStateEfRepository(IHmmDataContext dataContext)
        {
            ArgumentNullException.ThrowIfNull(dataContext);
            _dataContext = dataContext;
        }

        public async Task<IReadOnlyList<NoteUserState>> GetForAuthorAsync(int authorId)
        {
            return await _dataContext.Set<NoteUserStateDao>()
                .AsNoTracking()
                .Where(s => s.AuthorId == authorId)
                .OrderBy(s => s.NoteId)
                .Select(s => new NoteUserState
                {
                    AuthorId = s.AuthorId,
                    NoteId = s.NoteId,
                    NoteUuid = s.Note!.Uuid,
                    IsPinned = s.IsPinned,
                    FlagColor = s.FlagColor,
                    LastModifiedDate = s.LastModifiedDate,
                })
                .ToListAsync();
        }

        public async Task<NoteUserState> SaveIfNewerAsync(NoteUserState incoming)
        {
            ArgumentNullException.ThrowIfNull(incoming);
            var stamp = ToUtc(incoming.LastModifiedDate);

            var stored = await _dataContext.Set<NoteUserStateDao>()
                .FirstOrDefaultAsync(s => s.AuthorId == incoming.AuthorId && s.NoteId == incoming.NoteId);
            if (stored == null)
            {
                stored = new NoteUserStateDao
                {
                    AuthorId = incoming.AuthorId,
                    NoteId = incoming.NoteId,
                    IsPinned = incoming.IsPinned,
                    FlagColor = incoming.FlagColor,
                    LastModifiedDate = stamp,
                };
                _dataContext.Set<NoteUserStateDao>().Add(stored);
                await _dataContext.CommitAsync();
            }
            else if (stamp > stored.LastModifiedDate)
            {
                stored.IsPinned = incoming.IsPinned;
                stored.FlagColor = incoming.FlagColor;
                stored.LastModifiedDate = stamp;
                await _dataContext.CommitAsync();
            }
            // else: a stale (or equal) write is a no-op — the stored row wins.

            var uuid = await _dataContext.Set<HmmNoteDao>()
                .AsNoTracking()
                .Where(n => n.Id == stored.NoteId)
                .Select(n => n.Uuid)
                .FirstOrDefaultAsync();

            return new NoteUserState
            {
                AuthorId = stored.AuthorId,
                NoteId = stored.NoteId,
                NoteUuid = uuid,
                IsPinned = stored.IsPinned,
                FlagColor = stored.FlagColor,
                LastModifiedDate = stored.LastModifiedDate,
            };
        }

        // Npgsql refuses a non-UTC DateTime for a timestamptz column, and the
        // comparison above must be instant-to-instant.
        private static DateTime ToUtc(DateTime value) => value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc),
        };
    }
}
```

- [ ] **Step 6: Configure the model**

In `HmmDataContext.cs`:

1. In `ForeignKeyNames`, after `FK_AuthorSettings_Authors`, add:

```csharp
        public const string FK_NoteUserStates_Notes = "fk_noteuserstates_notes";
        public const string FK_NoteUserStates_Authors = "fk_noteuserstates_authors";
```

2. In `IndexNames`, after `UQ_AuthorSettings_AuthorId`, add:

```csharp
        public const string IX_NoteUserStates_NoteId = "ix_noteuserstates_noteid";
```

3. After `public DbSet<AuthorSettingsDao> AuthorSettings { get; set; }` add:

```csharp

        public DbSet<NoteUserStateDao> NoteUserStates { get; set; }
```

4. At the end of `OnModelCreating` (after the `AuthorSettingsDao` unique index), add:

```csharp

            // ============================================================
            // NoteUserStateDao Configuration (Notes redesign G14)
            // ============================================================
            // Pins + flags: one row per (author, note), never a note edit.
            // The default `false` for ispinned lives in the migration only
            // (a model-level HasDefaultValue on a bool makes EF warn that a
            // false value would always be replaced by the default).
            modelBuilder.Entity<NoteUserStateDao>().ToTable("noteuserstates");
            modelBuilder.Entity<NoteUserStateDao>().HasKey(s => new { s.AuthorId, s.NoteId });

            // Cascade: purging a note removes every user's state for it.
            modelBuilder.Entity<NoteUserStateDao>()
                .HasOne(s => s.Note)
                .WithMany()
                .HasForeignKey(s => s.NoteId)
                .HasConstraintName(ForeignKeyNames.FK_NoteUserStates_Notes)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<NoteUserStateDao>()
                .HasOne<AuthorDao>()
                .WithMany()
                .HasForeignKey(s => s.AuthorId)
                .HasConstraintName(ForeignKeyNames.FK_NoteUserStates_Authors)
                .OnDelete(DeleteBehavior.NoAction);

            modelBuilder.Entity<NoteUserStateDao>()
                .HasIndex(s => s.NoteId)
                .HasDatabaseName(IndexNames.IX_NoteUserStates_NoteId);
```

- [ ] **Step 7: Add the hand-written migration and update the snapshot**

Create `/Users/fchy/Projects/hmm/src/Hmm.Core.Dal.EF/Migrations/20261018000000_AddNoteUserStatesTable.cs`:

```csharp
using System;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Hmm.Core.Dal.EF.Migrations
{
    [DbContext(typeof(HmmDataContext))]
    [Migration("20261018000000_AddNoteUserStatesTable")]
    /// <inheritdoc />
    public partial class AddNoteUserStatesTable : Migration
    {
        // Hand-written for the same cross-provider drift reason as the
        // earlier migrations. Notes redesign G14: per-user pin + flag in
        // their own table — no change to `notes`. Existing notes simply have
        // no row (unpinned, unflagged). No backfill.

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "noteuserstates",
                columns: table => new
                {
                    authorid = table.Column<int>(type: "integer", nullable: false),
                    noteid = table.Column<int>(type: "integer", nullable: false),
                    ispinned = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    flagcolor = table.Column<int>(type: "integer", nullable: true),
                    lastmodifieddate = table.Column<DateTime>(
                        type: "timestamp with time zone", nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_noteuserstates", x => new { x.authorid, x.noteid });
                    table.ForeignKey(
                        name: "fk_noteuserstates_authors",
                        column: x => x.authorid,
                        principalTable: "authors",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "fk_noteuserstates_notes",
                        column: x => x.noteid,
                        principalTable: "notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_noteuserstates_noteid",
                table: "noteuserstates",
                column: "noteid");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "noteuserstates");
        }
    }
}
```

In `HmmDataContextModelSnapshot.cs`, after the closing `});` of the first `modelBuilder.Entity("Hmm.Core.Map.DbEntity.NoteTagRefDao", b =>` block (the property block, ending with `b.ToTable("notetagrefs", (string)null);`), insert:

```csharp

            modelBuilder.Entity("Hmm.Core.Map.DbEntity.NoteUserStateDao", b =>
                {
                    b.Property<int>("AuthorId")
                        .HasColumnType("integer")
                        .HasColumnName("authorid");

                    b.Property<int>("NoteId")
                        .HasColumnType("integer")
                        .HasColumnName("noteid");

                    b.Property<int?>("FlagColor")
                        .HasColumnType("integer")
                        .HasColumnName("flagcolor");

                    b.Property<bool>("IsPinned")
                        .HasColumnType("boolean")
                        .HasColumnName("ispinned");

                    b.Property<DateTime>("LastModifiedDate")
                        .HasColumnType("timestamp with time zone")
                        .HasColumnName("lastmodifieddate");

                    b.HasKey("AuthorId", "NoteId");

                    b.HasIndex("NoteId")
                        .HasDatabaseName("ix_noteuserstates_noteid");

                    b.ToTable("noteuserstates", (string)null);
                });
```

and after the closing `});` of the second `NoteTagRefDao` block (the relationships, ending with `b.Navigation("Tag");`), insert:

```csharp

            modelBuilder.Entity("Hmm.Core.Map.DbEntity.NoteUserStateDao", b =>
                {
                    b.HasOne("Hmm.Core.Map.DbEntity.AuthorDao", null)
                        .WithMany()
                        .HasForeignKey("AuthorId")
                        .OnDelete(DeleteBehavior.NoAction)
                        .IsRequired()
                        .HasConstraintName("fk_noteuserstates_authors");

                    b.HasOne("Hmm.Core.Map.DbEntity.HmmNoteDao", "Note")
                        .WithMany()
                        .HasForeignKey("NoteId")
                        .OnDelete(DeleteBehavior.Cascade)
                        .IsRequired()
                        .HasConstraintName("fk_noteuserstates_notes");

                    b.Navigation("Note");
                });
```

(Startup logs `PendingModelChangesWarning` rather than failing — `Startup.cs` ~line 183 — but keep the snapshot exact anyway. The SQLite test database is built from the model by `EnsureCreated()`, so the tests exercise the model configuration; PostgreSQL runs the migration.)

- [ ] **Step 8: Run the new tests and the full suites**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.Core.Dal.EF.Tests --filter "FullyQualifiedName~NoteUserStateRepositoryTests" 2>&1 | tail -1   # Passed: 8
dotnet test src/Hmm.Core.Dal.EF.Tests 2>&1 | tail -1      # Passed: 76
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1             # Passed: 233
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1  # Passed: 440
```
If only `Hard_deleting_the_note_cascades_its_states` fails with a row left over, the FK is not configured with `DeleteBehavior.Cascade` (Step 6) — fix the model, not the test.

- [ ] **Step 9: Commit**

```bash
cd /Users/fchy/Projects/hmm
git add src/Hmm.Core.Map/DbEntity/NoteUserStateDao.cs src/Hmm.Core.Map/DomainEntity/NoteUserState.cs \
  src/Hmm.Core.Map/Repositories/INoteUserStateRepository.cs \
  src/Hmm.Core.Dal.EF/Repositories/NoteUserStateEfRepository.cs src/Hmm.Core.Dal.EF/HmmDataContext.cs \
  src/Hmm.Core.Dal.EF/Migrations/20261018000000_AddNoteUserStatesTable.cs \
  src/Hmm.Core.Dal.EF/Migrations/HmmDataContextModelSnapshot.cs \
  src/Hmm.Core.Dal.EF.Tests/NoteUserStateRepositoryTests.cs
git status --short   # CLAUDE.md must still show " M" (unstaged)
git commit -m "$(cat <<'MSG'
feat(notes): per-user note state table (pins + flags) with newer-wins upsert

New noteuserstates table, key (authorid, noteid), FK to the note with
cascade delete so a purge removes every user's state. Pin/flag are never a
note edit: the notes table and note DTOs are unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 2: Server — `GET /v1/notes/states` and `PUT /v1/notes/{id}/state` (caller-only)

Who the caller is: the existing note endpoints do not check ownership at all; the self-scoped endpoints (`ProfileSettingsController`, `NoteVaultController`, `MigrationController`) resolve the signed-in author with `ICurrentUserAuthorProvider.GetCurrentUserAuthorAsync()` (JWT subject → author row, `src/Hmm.ServiceApi/Services/CurrentUserAuthorProvider.cs`). The state endpoints do the same. This task introduces the owner check `ResolveOwnerAsync` that Tasks 3 and 4 reuse: a missing note and another author's note both answer the same 404, so ids are never probed. Soft-deleted notes are allowed (soft delete leaves state alone; a restored note comes back pinned).

Routing: `states` cannot collide with `GET /v1/notes/{id:int}` (int constraint) or `by-uuid/{uuid}`. An old server answers `GET /v1/notes/states` with 404 — the client's "server too old" signal (Task 7).

**Files:**
- Create: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteState.cs`
- Create: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteStateForUpdate.cs`
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs` (usings lines 1–17; new actions + `ResolveOwnerAsync` + `ToApiState` before the closing brace of the class, line 415)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi/Startup.cs` (usings; DI after `.AddScoped<IRepository<AuthorSettingsDao>, AuthorSettingsEfRepository>()`, line 203)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerStateTests.cs` (create)

**Interfaces:**
- Consumes: `INoteUserStateRepository`, `NoteUserState` (Task 1), `ICurrentUserAuthorProvider.GetCurrentUserAuthorAsync()`, `IHmmNoteManager.GetNoteByIdAsync(int id, bool includeDelete)`.
- Produces (C#):
  - `ApiNoteState { int NoteId; string? NoteUuid; bool IsPinned; int? FlagColor; DateTime LastModifiedDate }` — wire JSON (camelCase): `{"noteId", "noteUuid", "isPinned", "flagColor", "lastModifiedDate"}`.
  - `ApiNoteStateForUpdate { bool IsPinned; int? FlagColor; DateTime? LastModifiedDate }` — wire `{"isPinned", "flagColor", "lastModifiedDate"}`.
  - `GET /v1/notes/states` → 200 `ApiNoteState[]` (the caller's rows only) | 401.
  - `PUT /v1/notes/{id}/state` → 200 `ApiNoteState` (the stored row after newer-wins; may be a newer row that beat the request) | 400 (no body / no `lastModifiedDate`) | 401 | 404 (missing note or another author's).
  - `private async Task<(IActionResult Error, int AuthorId)> ResolveOwnerAsync(int id, ICurrentUserAuthorProvider authorProvider)` in `HmmNoteController` (reused by Tasks 3 and 4).
  - DI: `INoteUserStateRepository → NoteUserStateEfRepository` (scoped).

- [ ] **Step 1: Write the failing controller tests**

Create `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerStateTests.cs`:

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
    /// <summary>
    /// Notes redesign G14: pin + flag are the caller's own state, read and
    /// written through dedicated endpoints — never through the note.
    /// </summary>
    public class NoteControllerStateTests : CoreTestFixtureBase
    {
        private static readonly DateTime T1 = new(2026, 10, 18, 9, 0, 0, DateTimeKind.Utc);

        private readonly HmmNoteManager _noteManager;
        private readonly HmmNoteController _controller;
        private readonly Mock<ICurrentUserAuthorProvider> _authors = new();
        private readonly Mock<INoteUserStateRepository> _states = new();

        public NoteControllerStateTests()
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

        private void SignInAs(Author author) =>
            _authors.Setup(a => a.GetCurrentUserAuthorAsync()).ReturnsAsync(ProcessingResult<Author>.Ok(author));

        private async Task<(Author Owner, HmmNote Note)> CreateOwnedNoteAsync(bool deleted = false)
        {
            var owner = await GetTestAuthor();
            var created = await _noteManager.CreateAsync(new HmmNote
            {
                Author = owner, Catalog = await GetTestCatalog(), Subject = "stateful", Content = "c",
            });
            if (deleted) Assert.True(await _noteManager.DeleteAsync(created.Value.Id));
            SignInAs(owner);
            return (owner, created.Value);
        }

        private static ApiNoteStateForUpdate Body(bool pinned, int? flag, DateTime? at) =>
            new() { IsPinned = pinned, FlagColor = flag, LastModifiedDate = at };

        [Fact]
        public async Task GetStates_returns_only_the_callers_rows()
        {
            var (owner, _) = await CreateOwnedNoteAsync();
            _states.Setup(s => s.GetForAuthorAsync(owner.Id)).ReturnsAsync(new List<NoteUserState>
            {
                new() { AuthorId = owner.Id, NoteId = 3, NoteUuid = "u3", IsPinned = true, FlagColor = 42, LastModifiedDate = T1 },
            });

            var result = await _controller.GetStates(_states.Object, _authors.Object);

            var ok = Assert.IsType<OkObjectResult>(result);
            var state = Assert.Single(Assert.IsAssignableFrom<IEnumerable<ApiNoteState>>(ok.Value));
            Assert.Equal(3, state.NoteId);
            Assert.Equal("u3", state.NoteUuid);
            Assert.True(state.IsPinned);
            Assert.Equal(42, state.FlagColor);
            Assert.Equal(T1, state.LastModifiedDate);
            _states.Verify(s => s.GetForAuthorAsync(It.Is<int>(id => id != owner.Id)), Times.Never);
        }

        [Fact]
        public async Task GetStates_without_a_signed_in_author_is_Unauthorized()
        {
            _authors.Setup(a => a.GetCurrentUserAuthorAsync())
                .ReturnsAsync(ProcessingResult<Author>.Fail("no user", ErrorCategory.Unauthorized));

            var result = await _controller.GetStates(_states.Object, _authors.Object);

            Assert.IsType<UnauthorizedResult>(result);
        }

        [Fact]
        public async Task PutState_saves_for_the_caller_and_returns_the_stored_row()
        {
            var (owner, note) = await CreateOwnedNoteAsync();
            _states.Setup(s => s.SaveIfNewerAsync(It.IsAny<NoteUserState>()))
                .ReturnsAsync((NoteUserState s) => new NoteUserState
                {
                    AuthorId = s.AuthorId, NoteId = s.NoteId, NoteUuid = "u", IsPinned = s.IsPinned,
                    FlagColor = s.FlagColor, LastModifiedDate = s.LastModifiedDate,
                });

            var result = await _controller.PutState(note.Id, Body(true, 4, T1), _states.Object, _authors.Object);

            var ok = Assert.IsType<OkObjectResult>(result);
            var stored = Assert.IsType<ApiNoteState>(ok.Value);
            Assert.True(stored.IsPinned);
            Assert.Equal(4, stored.FlagColor);
            _states.Verify(s => s.SaveIfNewerAsync(It.Is<NoteUserState>(x =>
                x.AuthorId == owner.Id && x.NoteId == note.Id && x.IsPinned && x.FlagColor == 4
                && x.LastModifiedDate == T1)), Times.Once);
        }

        [Fact]
        public async Task PutState_returns_the_newer_stored_row_when_the_request_lost()
        {
            var (owner, note) = await CreateOwnedNoteAsync();
            _states.Setup(s => s.SaveIfNewerAsync(It.IsAny<NoteUserState>()))
                .ReturnsAsync(new NoteUserState
                {
                    AuthorId = owner.Id, NoteId = note.Id, IsPinned = true, FlagColor = null,
                    LastModifiedDate = T1.AddHours(1),
                });

            var result = await _controller.PutState(note.Id, Body(false, null, T1), _states.Object, _authors.Object);

            var stored = Assert.IsType<ApiNoteState>(Assert.IsType<OkObjectResult>(result).Value);
            Assert.True(stored.IsPinned, "the client learns it lost and keeps the newer state");
            Assert.Equal(T1.AddHours(1), stored.LastModifiedDate);
        }

        [Fact]
        public async Task PutState_on_another_authors_note_is_NotFound_and_saves_nothing()
        {
            var (_, note) = await CreateOwnedNoteAsync();
            SignInAs(new Author { Id = 999, AccountName = "intruder" });

            var result = await _controller.PutState(note.Id, Body(true, 0, T1), _states.Object, _authors.Object);

            Assert.IsType<NotFoundObjectResult>(result);
            _states.Verify(s => s.SaveIfNewerAsync(It.IsAny<NoteUserState>()), Times.Never);
        }

        [Fact]
        public async Task PutState_on_an_unknown_note_is_NotFound()
        {
            SignInAs(await GetTestAuthor());

            var result = await _controller.PutState(9999, Body(true, null, T1), _states.Object, _authors.Object);

            Assert.IsType<NotFoundObjectResult>(result);
            _states.Verify(s => s.SaveIfNewerAsync(It.IsAny<NoteUserState>()), Times.Never);
        }

        [Fact]
        public async Task PutState_without_lastModifiedDate_is_BadRequest()
        {
            var (_, note) = await CreateOwnedNoteAsync();

            var result = await _controller.PutState(note.Id, Body(true, null, null), _states.Object, _authors.Object);

            Assert.IsType<BadRequestObjectResult>(result);
            _states.Verify(s => s.SaveIfNewerAsync(It.IsAny<NoteUserState>()), Times.Never);
        }

        [Fact]
        public async Task PutState_on_a_soft_deleted_note_is_allowed()
        {
            // Soft delete leaves state alone: a restored note comes back pinned.
            var (_, note) = await CreateOwnedNoteAsync(deleted: true);
            _states.Setup(s => s.SaveIfNewerAsync(It.IsAny<NoteUserState>()))
                .ReturnsAsync((NoteUserState s) => s);

            var result = await _controller.PutState(note.Id, Body(true, null, T1), _states.Object, _authors.Object);

            Assert.IsType<OkObjectResult>(result);
        }

        [Fact]
        public async Task PutState_without_a_signed_in_author_is_Unauthorized()
        {
            var (_, note) = await CreateOwnedNoteAsync();
            _authors.Setup(a => a.GetCurrentUserAuthorAsync())
                .ReturnsAsync(ProcessingResult<Author>.Fail("no user", ErrorCategory.Unauthorized));

            var result = await _controller.PutState(note.Id, Body(true, null, T1), _states.Object, _authors.Object);

            Assert.IsType<UnauthorizedResult>(result);
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~NoteControllerStateTests" 2>&1 | tail -5
```
Expected: build FAILS with `error CS0246: The type or namespace name 'ApiNoteStateForUpdate' could not be found` and `'HmmNoteController' does not contain a definition for 'GetStates'`.

- [ ] **Step 3: Add the DTOs**

Create `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteState.cs`:

```csharp
using System;

namespace Hmm.ServiceApi.DtoEntity.HmmNote
{
    /// <summary>
    /// The caller's pin + flag for one note (Notes redesign G14). Clients
    /// key it by <see cref="NoteUuid"/>; <see cref="NoteId"/> is the server
    /// id for PUT /v1/notes/{id}/state.
    /// </summary>
    public class ApiNoteState
    {
        public int NoteId { get; set; }

        /// <summary>Null only for a legacy note that has no uuid yet.</summary>
        public string? NoteUuid { get; set; }

        public bool IsPinned { get; set; }

        /// <summary>null = unflagged; 0 red … 6 grey; unknown values verbatim.</summary>
        public int? FlagColor { get; set; }

        /// <summary>The state's last-writer-wins clock (UTC).</summary>
        public DateTime LastModifiedDate { get; set; }
    }
}
```

Create `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteStateForUpdate.cs`:

```csharp
using System;

namespace Hmm.ServiceApi.DtoEntity.HmmNote
{
    /// <summary>
    /// Body of PUT /v1/notes/{id}/state. A full replacement of the caller's
    /// state for the note, applied only if <see cref="LastModifiedDate"/> is
    /// newer than the stored one.
    /// </summary>
    public class ApiNoteStateForUpdate
    {
        public bool IsPinned { get; set; }

        public int? FlagColor { get; set; }

        /// <summary>Required. The client's stamp for this state (UTC).</summary>
        public DateTime? LastModifiedDate { get; set; }
    }
}
```

- [ ] **Step 4: Add the controller actions and the owner check**

In `HmmNoteController.cs` add `using Hmm.Core.Map.Repositories;` and `using System.Collections.Generic;` to the usings. Before the final closing brace of the class add:

```csharp

        /// <summary>
        /// The caller's pin/flag states (Notes redesign G14). Self-scoped:
        /// the author comes from the token, never from the request.
        /// </summary>
        [HttpGet("states", Name = "GetNoteStates")]
        [ProducesResponseType(typeof(ApiNoteState[]), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
        public async Task<IActionResult> GetStates(
            [FromServices] INoteUserStateRepository states,
            [FromServices] ICurrentUserAuthorProvider authorProvider)
        {
            try
            {
                var authorResult = await authorProvider.GetCurrentUserAuthorAsync();
                if (!authorResult.Success || authorResult.Value == null)
                {
                    return Unauthorized();
                }

                var rows = await states.GetForAuthorAsync(authorResult.Value.Id);
                return Ok(rows.Select(ToApiState).ToList());
            }
            catch (Exception ex)
            {
                _logger.LogError("Unexpected {ErrorType} while reading note states. TraceId: {TraceId}",
                    ex.GetType().Name, HttpContext.TraceIdentifier);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ProblemDetailsHelper.InternalServerError("An unexpected error occurred while reading note states.", HttpContext));
            }
        }

        /// <summary>
        /// Set the caller's pin/flag for note <paramref name="id"/>. Newer
        /// lastModifiedDate wins (a tie keeps the stored row); the stored row
        /// is returned either way. The note itself is never modified.
        /// Owner-only: another author's note (or a missing one) is a 404.
        /// </summary>
        [HttpPut("{id:int}/state", Name = "SetNoteState")]
        [ProducesResponseType(typeof(ApiNoteState), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
        [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
        public async Task<IActionResult> PutState(
            int id,
            [FromBody] ApiNoteStateForUpdate body,
            [FromServices] INoteUserStateRepository states,
            [FromServices] ICurrentUserAuthorProvider authorProvider)
        {
            if (body?.LastModifiedDate == null)
            {
                return BadRequest(ProblemDetailsHelper.BadRequest("lastModifiedDate is required", HttpContext));
            }

            try
            {
                var (error, authorId) = await ResolveOwnerAsync(id, authorProvider);
                if (error != null) return error;

                var stored = await states.SaveIfNewerAsync(new NoteUserState
                {
                    AuthorId = authorId,
                    NoteId = id,
                    IsPinned = body.IsPinned,
                    FlagColor = body.FlagColor,
                    LastModifiedDate = body.LastModifiedDate.Value,
                });
                return Ok(ToApiState(stored));
            }
            catch (Exception ex)
            {
                _logger.LogError("Unexpected {ErrorType} while saving the state of note {NoteId}. TraceId: {TraceId}",
                    ex.GetType().Name, id, HttpContext.TraceIdentifier);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    ProblemDetailsHelper.InternalServerError("An unexpected error occurred while saving the note state.", HttpContext));
            }
        }

        private static ApiNoteState ToApiState(NoteUserState s) => new()
        {
            NoteId = s.NoteId,
            NoteUuid = s.NoteUuid,
            IsPinned = s.IsPinned,
            FlagColor = s.FlagColor,
            LastModifiedDate = s.LastModifiedDate,
        };

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

- [ ] **Step 5: Register the repository**

In `Startup.cs` add `using Hmm.Core.Map.Repositories;` to the usings and, after `.AddScoped<IRepository<AuthorSettingsDao>, AuthorSettingsEfRepository>()`, add:

```csharp
                .AddScoped<INoteUserStateRepository, NoteUserStateEfRepository>()
```

- [ ] **Step 6: Run tests**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~NoteControllerStateTests" 2>&1 | tail -1   # Passed: 9
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1   # Passed: 449
dotnet build Hmm.sln 2>&1 | tail -3                        # Build succeeded, 0 Error(s)
```

- [ ] **Step 7: Commit**

```bash
cd /Users/fchy/Projects/hmm
git add src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteState.cs src/Hmm.ServiceApi.DtoEntity/HmmNote/ApiNoteStateForUpdate.cs \
  src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs src/Hmm.ServiceApi/Startup.cs \
  src/Hmm.ServiceApi.Core.Tests/NoteControllerStateTests.cs
git status --short   # CLAUDE.md still unstaged
git commit -m "$(cat <<'MSG'
feat(notes): GET /v1/notes/states and PUT /v1/notes/{id}/state

Self-scoped (author from the token), owner-only PUT (another author's note
is a 404, like a missing one), newer lastModifiedDate wins and the stored
row is returned. Adds ResolveOwnerAsync for the restore/purge/tags actions.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 3: Server — undelete (`POST /v1/notes/{id}/restore`) and purge (`DELETE /v1/notes/{id}/purge`)

Why `/purge` and not `?permanent=true`: an old server ignores an unknown query parameter and would silently *soft*-delete, so a client would hard-delete locally believing the row is gone. A distinct route 404s on an old server instead.

**Files:**
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core/IHmmNoteManager.cs` (after `DeleteAsync`, line 48)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Core/DefaultManager/HmmNoteManager.cs` (after `DeleteAsync`, line 243)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi/Areas/HmmNoteService/Controllers/HmmNoteController.cs` (usings; `Put` lines 211–222; `Delete` lines 378–389; new actions before the closing brace of the class)
- Modify: `/Users/fchy/Projects/hmm/src/Hmm.Utility.TestHelp/CoreTestFixtureBase.cs` (`GetNoteRepository`, add a `DeleteAsync` setup before `return mockNotes.Object;`, ~line 615)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.Core.Tests/HmmNoteManagerRestorePurgeTests.cs` (create)
- Test: `/Users/fchy/Projects/hmm/src/Hmm.ServiceApi.Core.Tests/NoteControllerRestorePurgeTests.cs` (create)

**Interfaces:**
- Consumes: `ResolveOwnerAsync` (Task 2), `ICurrentUserAuthorProvider.GetCurrentUserAuthorAsync()`, `IVaultBlobStore.ListAsync/DeleteAsync(int authorId, string path, CancellationToken)`, `IVersionRepository<HmmNoteDao>.DeleteAsync(HmmNoteDao)`; the `noteuserstates` cascade (Task 1) removes the purged note's states.
- Produces (C#):
  - `Task<ProcessingResult<HmmNote>> IHmmNoteManager.RestoreAsync(int noteId)` — clears `IsDeleted`; idempotent for a live note; NotFound passes through.
  - `Task<ProcessingResult<Unit>> IHmmNoteManager.PurgeAsync(int noteId)` — removes a soft-deleted row (tag refs cascade); `Conflict` for a live note; `NotFound` for a missing one.
  - `POST /v1/notes/{id}/restore` → 200 `ApiNote` | 401 | 404 (missing or another author's).
  - `DELETE /v1/notes/{id}/purge` → 204 | 401 | 404 | 409 (live note). Best-effort removes `attachments/note-{id}/*` from the owner's vault.
  - `PUT /v1/notes/{id}` on a soft-deleted note → 409 (was 500). `DELETE /v1/notes/{id}` on an already-deleted note → 204 (was 500).

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
```

- [ ] **Step 7: Run tests**

```bash
cd /Users/fchy/Projects/hmm
dotnet test src/Hmm.Core.Tests --filter "FullyQualifiedName~HmmNoteManagerRestorePurgeTests" 2>&1 | tail -1          # Passed: 6
dotnet test src/Hmm.ServiceApi.Core.Tests --filter "FullyQualifiedName~NoteControllerRestorePurgeTests" 2>&1 | tail -1 # Passed: 10
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1             # Passed: 239
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1  # Passed: 459
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

In `ApiNote.cs`, after `public string? LocationLabel { get; set; }` add:

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

(`using Hmm.Core.Map.Repositories;` is already in `Startup.cs` from Task 2).

- [ ] **Step 7: Controller endpoints and the `applyTag` rewire**

In `HmmNoteController.cs` (`using Hmm.Core.Map.Repositories;` and `using System.Collections.Generic;` are already present from Task 2) replace the whole `ApplyTag` action (lines 254–296, doc comment included) with:

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
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1             # Passed: 239
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1  # Passed: 466
dotnet test src/Hmm.Core.Dal.EF.Tests 2>&1 | tail -1      # Passed: 81
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

### Task 5: Client — Drift v9 `NoteStates` table, `NoteState`, `LocalNoteStateRepository`, repository `restoreNote`

Verified facts this task relies on: every note row has a uuid (`Notes.uuid` has `clientDefault(generateUuid)`, the v2→v3 migration back-filled old rows, `idx_notes_uuid` is unique, and pulled tombstones are inserted with their uuid), and sync identifies notes by that uuid. In `local` / `cloudStorage` the device has exactly one owner (`SyncOrchestrator._adoptOrphanedNotes`), so the client state table needs no author column: one row per note uuid. Tags track no pending-push flag — every sync merges and pushes the whole tag document — and note states follow the same model (Task 6 recomputes "local wins" from timestamps each sync), so `NoteStates` needs no dirty column either.

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/local/database.dart` (new `NoteStates` table after `NoteTagRefs`, line 105; `@DriftDatabase(tables: …)` line 108; `schemaVersion` line 114; `onUpgrade` after the `from < 8` block, line 250)
- Regenerate: `/Users/fchy/Projects/hmm_console/lib/core/data/local/database.g.dart`
- Create: `/Users/fchy/Projects/hmm_console/lib/core/notes/note_flag.dart`
- Create: `/Users/fchy/Projects/hmm_console/lib/core/notes/note_state.dart`
- Create: `/Users/fchy/Projects/hmm_console/lib/core/data/local/local_note_state_repository.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/repository_providers.dart` (imports; new provider after `tagRepositoryProvider`, line 51)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/local/local_hmm_note_repository.dart` (interface after `setParentNote`; new method after `setParentNote`, line 239; top-level `restoreStamp` at the end of the file)
- Modify: `/Users/fchy/Projects/hmm_console/test/features/notes/states/mutate_note_state_test.dart` (`_FakeNoteRepo`, lines 17–64)
- Modify: `/Users/fchy/Projects/hmm_console/test/core/data/local/tags_schema_v6_test.dart` (line 13)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/local/note_states_schema_v9_migration_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/local/local_note_state_repository_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/local/local_hmm_note_repository_restore_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/notes/note_flag_test.dart` (create)

**Interfaces:**
- Produces (Dart):
  - Drift: `@DataClassName('NoteStateRow') class NoteStates` — `noteUuid` (TEXT, primary key, SQL `note_uuid`), `isPinned` (`BoolColumn`, default false), `flagColor` (`IntColumn` nullable), `lastModifiedDate` (`DateTimeColumn`, required); SQL table `note_states`; `NoteStatesCompanion`; `db.noteStates`; `HmmDatabase.schemaVersion == 9`.
  - `enum NoteFlagColor { red, orange, yellow, green, blue, purple, grey }` with `Color color`, `int get stored`, `static NoteFlagColor? fromStored(int? value)`.
  - `class NoteState { const NoteState({required String noteUuid, bool isPinned = false, int? flagColor, required DateTime lastModifiedDate}); factory NoteState.none(String noteUuid); NoteFlagColor? get flag; }` — `NoteState.none` is unpinned, unflagged, stamped at the epoch.
  - `abstract interface class INoteStateRepository { Future<NoteState> getState(String noteUuid); Future<Map<String, NoteState>> getAllStates(); Future<NoteState> setPinned(String noteUuid, bool pinned); Future<NoteState> setFlagColor(String noteUuid, int? flagColor); }`
  - `class LocalNoteStateRepository implements INoteStateRepository { LocalNoteStateRepository(HmmDatabase db, {void Function()? onLocalWrite}); Future<void> putState(NoteState state); Future<void> deleteState(String noteUuid); }` — `putState` / `deleteState` are for sync and purge: they write verbatim and do not call `onLocalWrite`.
  - `final localNoteStateRepositoryProvider = Provider<LocalNoteStateRepository>`, `final noteStateRepositoryProvider = Provider<INoteStateRepository>` (local + cloudStorage; throws `UnimplementedError` for cloudApi exactly like `hmmNoteRepositoryProvider`).
  - `IHmmNoteRepository.restoreNote(int id) → Future<HmmNote>`.
  - `DateTime restoreStamp(DateTime previous, DateTime now)` (top-level, `local_hmm_note_repository.dart`) — at least the next whole second after `previous`; also used for note-state stamps.

- [ ] **Step 1: Write the failing migration test**

Create `/Users/fchy/Projects/hmm_console/test/core/data/local/note_states_schema_v9_migration_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';

/// The v8 `notes` table exactly as Drift created it (DateTime columns are
/// unix seconds). Only `notes` is needed: the v8 → v9 step creates
/// `note_states` and touches nothing else.
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
  test('v8 → v9 creates an empty note_states table and leaves notes untouched',
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
    expect(row.lastModifiedDate!.toUtc(),
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true));
    expect(await db.select(db.noteStates).get(), isEmpty,
        reason: 'no row = unpinned and unflagged; nothing is backfilled');

    final noteColumns = await db.customSelect('PRAGMA table_info(notes)').get();
    expect(noteColumns.map((c) => c.read<String>('name')),
        isNot(anyOf(contains('is_pinned'), contains('flag_color'))),
        reason: 'pin and flag are never note columns (G14)');
  });

  test('a fresh v9 database stores a state row keyed by note uuid', () async {
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.noteStates).insert(NoteStatesCompanion.insert(
          noteUuid: 'u1',
          flagColor: const Value(42),
          lastModifiedDate: DateTime.utc(2026, 10, 18, 9),
        ));
    final row = await db.select(db.noteStates).getSingle();
    expect(row.noteUuid, 'u1');
    expect(row.isPinned, isFalse, reason: 'isPinned defaults to false');
    expect(row.flagColor, 42, reason: 'unknown colours are stored verbatim');
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/local/note_states_schema_v9_migration_test.dart
```
Expected: compile error `The getter 'noteStates' isn't defined for the type 'HmmDatabase'`.

- [ ] **Step 3: Add the table and the migration step**

In `database.dart`, after the `NoteTagRefs` class add:

```dart

/// v9: the user's own state about a note — pin + coloured flag (Notes
/// redesign G14). Deliberately NOT columns on [Notes]: a pin or flag change
/// is not a note edit, never bumps the note's version / lastModifiedDate and
/// never re-pushes the note. One row per note uuid (this device has one
/// owner). No row = unpinned and unflagged. Unpin / unflag write a row
/// (false / null) so the change propagates; only purge removes rows.
@DataClassName('NoteStateRow')
class NoteStates extends Table {
  TextColumn get noteUuid => text()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  // null = unflagged; 0 red, 1 orange, 2 yellow, 3 green, 4 blue, 5 purple,
  // 6 grey. Any other int (a newer client) is stored verbatim and shown grey.
  IntColumn get flagColor => integer().nullable()();
  // Per-state last-writer-wins clock for sync.
  DateTimeColumn get lastModifiedDate => dateTime()();

  @override
  Set<Column> get primaryKey => {noteUuid};
}
```

Change `tables: [Authors, NoteCatalogs, Notes, Tags, NoteTagRefs],` to `tables: [Authors, NoteCatalogs, Notes, Tags, NoteTagRefs, NoteStates],` and `int get schemaVersion => 8;` to `int get schemaVersion => 9;`.

After the `if (from < 8) { ... }` block inside `onUpgrade`, add:

```dart
      if (from < 9) {
        // v9: per-note state (pin + flag) in its own table. Notes are
        // untouched; no backfill — a note without a row is unpinned.
        await m.createTable(noteStates);
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
    // v7 added Notes.noteDate, v8 Notes location, v9 the NoteStates table;
    // the tag sync columns from v6 are unchanged.
    expect(db.schemaVersion, 9);
```

- [ ] **Step 4: Run the migration test**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/local/note_states_schema_v9_migration_test.dart test/core/data/local/tags_schema_v6_test.dart
```
Expected: `All tests passed!` (3 tests).

- [ ] **Step 5: Write the failing flag, state-repository and restore tests**

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

Create `/Users/fchy/Projects/hmm_console/test/core/data/local/local_note_state_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/notes/note_flag.dart';
import 'package:hmm_console/core/notes/note_state.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository notes;
  late LocalNoteStateRepository states;
  var noteWrites = 0;
  var stateWrites = 0;

  setUp(() async {
    noteWrites = 0;
    stateWrites = 0;
    db = HmmDatabase(NativeDatabase.memory());
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();
    notes = LocalHmmNoteRepository(db, () async => author,
        onLocalWrite: () => noteWrites++);
    states = LocalNoteStateRepository(db, onLocalWrite: () => stateWrites++);
  });

  tearDown(() => db.close());

  test('a note without a row is unpinned and unflagged', () async {
    final s = await states.getState('nobody');
    expect(s.noteUuid, 'nobody');
    expect(s.isPinned, isFalse);
    expect(s.flagColor, isNull);
    expect(s.flag, isNull);
    expect(await states.getAllStates(), isEmpty);
  });

  test('setPinned and setFlagColor never touch the note row', () async {
    final created = await notes.createNote(
        const HmmNoteCreate(subject: 'keep me', catalogId: 1, content: 'body'));
    final before = (await notes.getNoteById(created.id))!;
    noteWrites = 0;

    await states.setPinned(created.uuid, true);
    await states.setFlagColor(created.uuid, 3);

    final after = (await notes.getNoteById(created.id))!;
    expect(after.version, before.version, reason: 'not a note edit (G14)');
    expect(after.lastModifiedDate, before.lastModifiedDate);
    expect(after.subject, 'keep me');
    expect(after.content, 'body');
    expect(noteWrites, 0, reason: 'the note is not marked for sync');
    expect(stateWrites, 2, reason: 'each state write asks for a sync');
  });

  test('a pin change keeps the flag and a flag change keeps the pin', () async {
    await states.setFlagColor('n1', 5);
    final pinned = await states.setPinned('n1', true);
    expect(pinned.flagColor, 5);
    final flagged = await states.setFlagColor('n1', 1);
    expect(flagged.isPinned, isTrue);
    expect(flagged.flag, NoteFlagColor.orange);
  });

  test('unpin writes a row with false, never deletes it', () async {
    await states.setPinned('n1', true);
    await states.setPinned('n1', false);
    await states.setFlagColor('n1', 2);
    await states.setFlagColor('n1', null);

    final rows = await db.select(db.noteStates).get();
    expect(rows, hasLength(1));
    expect(rows.single.isPinned, isFalse);
    expect(rows.single.flagColor, isNull);
  });

  test('an unknown flag value is kept verbatim and shows as grey', () async {
    final s = await states.setFlagColor('n1', 42);
    expect(s.flagColor, 42);
    expect(s.flag, NoteFlagColor.grey);
  });

  test('a second write in the same second still gets a later stamp', () async {
    final first = await states.setPinned('n1', true);
    final second = await states.setPinned('n1', false); // same wall-clock second
    expect(second.lastModifiedDate.isAfter(first.lastModifiedDate), isTrue,
        reason: 'Drift keeps whole seconds; a tie would lose the unpin on peers');
  });

  test('putState and deleteState write verbatim without asking for a sync',
      () async {
    final at = DateTime.utc(2026, 10, 18, 9);
    await states.putState(
        NoteState(noteUuid: 'n1', isPinned: true, flagColor: 4, lastModifiedDate: at));
    final s = await states.getState('n1');
    expect(s.isPinned, isTrue);
    expect(s.flagColor, 4);
    expect(s.lastModifiedDate.toUtc(), at);

    await states.deleteState('n1');
    expect(await states.getAllStates(), isEmpty);
    expect(stateWrites, 0);
  });
}
```

Create `/Users/fchy/Projects/hmm_console/test/core/data/local/local_hmm_note_repository_restore_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';

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

  test('delete and restore leave the note state alone', () async {
    final created =
        await repo.createNote(const HmmNoteCreate(subject: 's', catalogId: 1));
    final states = LocalNoteStateRepository(db);
    await states.setPinned(created.uuid, true);

    await repo.deleteNote(created.id);
    expect((await states.getState(created.uuid)).isPinned, isTrue);
    await repo.restoreNote(created.id);
    expect((await states.getState(created.uuid)).isPinned, isTrue,
        reason: 'a restored note comes back pinned');
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
flutter test test/core/notes/note_flag_test.dart test/core/data/local/local_note_state_repository_test.dart test/core/data/local/local_hmm_note_repository_restore_test.dart
```
Expected: compile errors `Target of URI doesn't exist: 'package:hmm_console/core/notes/note_flag.dart'` (and `…/local_note_state_repository.dart`), `The method 'restoreNote' isn't defined for the type 'LocalHmmNoteRepository'`.

- [ ] **Step 7: Add `NoteFlagColor` and `NoteState`**

Create `/Users/fchy/Projects/hmm_console/lib/core/notes/note_flag.dart`:

```dart
import 'dart:ui' show Color;

/// The seven note flag colours (Apple Mail palette). Persisted as
/// `NoteStates.flagColor`: null = unflagged, otherwise the enum index.
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

  /// The int stored in `NoteStates.flagColor` for this colour.
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

Create `/Users/fchy/Projects/hmm_console/lib/core/notes/note_state.dart`:

```dart
import 'note_flag.dart';

/// The user's own state about one note — pin + coloured flag (Notes
/// redesign G14). Not part of `HmmNote`: changing it is not a note edit.
class NoteState {
  const NoteState({
    required this.noteUuid,
    this.isPinned = false,
    this.flagColor,
    required this.lastModifiedDate,
  });

  /// No stored row: unpinned, unflagged, older than any real write.
  factory NoteState.none(String noteUuid) => NoteState(
        noteUuid: noteUuid,
        lastModifiedDate: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  /// The note's cross-device uuid (`Notes.uuid`).
  final String noteUuid;

  final bool isPinned;

  /// Raw stored flag: null = unflagged; 0–6 = [NoteFlagColor] index; any
  /// other int came from a newer client and is preserved verbatim.
  final int? flagColor;

  /// Per-state last-writer-wins clock.
  final DateTime lastModifiedDate;

  /// Display flag ([NoteFlagColor.grey] for an unknown stored value).
  NoteFlagColor? get flag => NoteFlagColor.fromStored(flagColor);
}
```

- [ ] **Step 8: Add the state repository and its providers**

Create `/Users/fchy/Projects/hmm_console/lib/core/data/local/local_note_state_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notes/note_state.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_orchestrator.dart';
import 'database.dart';
import 'local_hmm_note_repository.dart' show restoreStamp;

/// Pin + flag per note (Notes redesign G14), keyed by note uuid. Writes go
/// to `NoteStates` only — never to the note row — so they cannot overwrite
/// a concurrent text edit made on another device.
abstract interface class INoteStateRepository {
  /// The stored state, or [NoteState.none] when the note has no row.
  Future<NoteState> getState(String noteUuid);

  /// Every stored state, by note uuid.
  Future<Map<String, NoteState>> getAllStates();

  /// Pin or unpin. Unpin writes `isPinned = false` (never deletes) so the
  /// change propagates. Keeps the flag.
  Future<NoteState> setPinned(String noteUuid, bool pinned);

  /// Set a colour (0–6; any other int is stored verbatim) or clear it with
  /// null (a row with a null flag). Keeps the pin.
  Future<NoteState> setFlagColor(String noteUuid, int? flagColor);
}

class LocalNoteStateRepository implements INoteStateRepository {
  LocalNoteStateRepository(this._db, {void Function()? onLocalWrite})
      : _onLocalWrite = onLocalWrite;

  final HmmDatabase _db;

  /// Asks for a debounced sync (of states — the note cursor is untouched).
  final void Function()? _onLocalWrite;

  @override
  Future<NoteState> getState(String noteUuid) async {
    final row = await _read(noteUuid);
    return row == null ? NoteState.none(noteUuid) : _fromRow(row);
  }

  @override
  Future<Map<String, NoteState>> getAllStates() async {
    final rows = await _db.select(_db.noteStates).get();
    return {for (final r in rows) r.noteUuid: _fromRow(r)};
  }

  @override
  Future<NoteState> setPinned(String noteUuid, bool pinned) async {
    final current = await _read(noteUuid);
    return _writeLocal(NoteState(
      noteUuid: noteUuid,
      isPinned: pinned,
      flagColor: current?.flagColor,
      lastModifiedDate: _stamp(current),
    ));
  }

  @override
  Future<NoteState> setFlagColor(String noteUuid, int? flagColor) async {
    final current = await _read(noteUuid);
    return _writeLocal(NoteState(
      noteUuid: noteUuid,
      isPinned: current?.isPinned ?? false,
      flagColor: flagColor,
      lastModifiedDate: _stamp(current),
    ));
  }

  /// Sync only: store [state] exactly as received (its own stamp). Does not
  /// ask for another sync.
  Future<void> putState(NoteState state) async {
    await _db.into(_db.noteStates).insertOnConflictUpdate(_companion(state));
  }

  /// Purge / sync only: remove the row of a note that no longer exists.
  Future<void> deleteState(String noteUuid) async {
    await (_db.delete(_db.noteStates)
          ..where((s) => s.noteUuid.equals(noteUuid)))
        .go();
  }

  Future<NoteState> _writeLocal(NoteState state) async {
    await putState(state);
    _onLocalWrite?.call();
    return getState(state.noteUuid);
  }

  /// Drift keeps whole seconds: a second write inside the same second must
  /// still be strictly newer, or peers would keep the first value on a tie.
  DateTime _stamp(NoteStateRow? current) {
    final now = DateTime.now().toUtc();
    return current == null ? now : restoreStamp(current.lastModifiedDate, now);
  }

  Future<NoteStateRow?> _read(String noteUuid) => (_db.select(_db.noteStates)
        ..where((s) => s.noteUuid.equals(noteUuid)))
      .getSingleOrNull();

  static NoteStatesCompanion _companion(NoteState s) =>
      NoteStatesCompanion.insert(
        noteUuid: s.noteUuid,
        isPinned: Value(s.isPinned),
        flagColor: Value(s.flagColor),
        lastModifiedDate: s.lastModifiedDate.toUtc(),
      );

  static NoteState _fromRow(NoteStateRow r) => NoteState(
        noteUuid: r.noteUuid,
        isPinned: r.isPinned,
        flagColor: r.flagColor,
        lastModifiedDate: r.lastModifiedDate.toUtc(),
      );
}

final localNoteStateRepositoryProvider =
    Provider<LocalNoteStateRepository>((ref) {
  return LocalNoteStateRepository(
    ref.watch(hmmDatabaseProvider),
    // Same debounced auto-sync gate as LocalHmmNoteRepository: read (not
    // watch) both providers since this closure runs later, at write time.
    onLocalWrite: () {
      if (ref.read(syncOrchestratorProvider).isActive) {
        ref.read(syncControllerProvider).notifyLocalChange();
      }
    },
  );
});
```

In `repository_providers.dart` add `import 'local/local_note_state_repository.dart';` to the imports and, after `tagRepositoryProvider`, add:

```dart

final noteStateRepositoryProvider = Provider<INoteStateRepository>((ref) {
  final mode = ref.watch(dataModeProvider);
  if (_useLocal(mode)) return ref.watch(localNoteStateRepositoryProvider);
  throw UnimplementedError('API note state repository not yet implemented');
});
```

- [ ] **Step 9: Add `restoreNote` and `restoreStamp`**

In `local_hmm_note_repository.dart`, add to `IHmmNoteRepository` after `Future<HmmNote> setParentNote(int id, int? parentNoteId);`:

```dart

  /// Undo a soft delete: clears deletedAt and stamps lastModifiedDate
  /// strictly later than the tombstone (see [restoreStamp]) so the restore
  /// wins last-writer-wins on other devices. A live note is returned
  /// unchanged. Throws [StateError] when the note does not exist. The
  /// note's state (pin/flag) is untouched.
  Future<HmmNote> restoreNote(int id);
```

After the `setParentNote` method add:

```dart

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

/// The lastModifiedDate a restore (or a note-state write) stamps. Drift
/// stores DateTime as whole unix seconds, so "later than the previous value"
/// must be at least the next whole second — a write in the same second
/// would otherwise tie, and last-writer-wins keeps the old value on every
/// other device.
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

- [ ] **Step 10: Keep the test fake compiling**

In `test/features/notes/states/mutate_note_state_test.dart`, add to `_FakeNoteRepo` after `getUnattachedNotes`:

```dart
  @override
  Future<HmmNote> restoreNote(int id) async => stored;
```

(All other `IHmmNoteRepository` fakes under `test/` already use `noSuchMethod`.)

- [ ] **Step 11: Run tests and analyze**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/notes/note_flag_test.dart test/core/data/local/
flutter test test/features/notes/
flutter analyze
```
Expected: all pass; analyze reports only the 2 pre-existing infos.

- [ ] **Step 12: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/core/data/local/database.dart lib/core/data/local/database.g.dart \
  lib/core/notes/note_flag.dart lib/core/notes/note_state.dart \
  lib/core/data/local/local_note_state_repository.dart lib/core/data/repository_providers.dart \
  lib/core/data/local/local_hmm_note_repository.dart \
  test/features/notes/states/mutate_note_state_test.dart test/core/data/local/tags_schema_v6_test.dart \
  test/core/data/local/note_states_schema_v9_migration_test.dart \
  test/core/data/local/local_note_state_repository_test.dart \
  test/core/data/local/local_hmm_note_repository_restore_test.dart test/core/notes/note_flag_test.dart
git commit -m "$(cat <<'MSG'
feat(notes): schema v9 NoteStates table for pins/flags; restoreNote

Pin and flag live in their own table keyed by note uuid and never touch
the note row (G14). State writes and restore stamp the next whole second
so they cannot tie under Drift's 1-second DateTime resolution.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 6: Client — note-state sync (`NoteStateSyncService`, OneDrive `note-states.json`); tags keep on an absent key; restore propagation pinned by tests

The state document mirrors `tags.json` exactly: the orchestrator pulls one document, merges it per entry with `NoteStateSyncService` (newer `lastModified` wins, a tie keeps local), and pushes the whole merged document back every sync (`TagSyncService` / `_syncTags` do the same; neither tracks a dirty flag). Per-row remotes (the API, Task 7) receive only the `localWins` set. It runs after the note pull (pulled notes exist locally, restores are applied) and after the note push (the API has every note a state can point at), and never writes a note row.

Purged notes: in cloudStorage a purge keeps a content-free tombstone row in the manifest (Task 8), so "absent from the manifest" alone would never drop a purged note's state — and peers that have not purged yet keep pushing their entry. The merge therefore treats as "no note" any uuid that is neither a local note other than a content-free tombstone (`subject == kTombstoneSubject`, no content, no attachments, deleted) nor a live entry of the remote manifest. Entries for such uuids are not applied, are dropped from the pushed document, and a local row for one is deleted. A peer's stale entry may bounce until that peer purges too; it is never applied, so nothing resurrects. A live remote-manifest entry counts as a note even when its pull failed this run, so a failed pull never drops a pin.

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/sync_models.dart` (`kTombstoneSubject` after `library;`; `SyncPhase.noteStates` after `pushNotes`, line 92)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/cloud_sync_provider.dart` (`NoteStatesUnsupportedException`; `pullNoteStates` / `pushNoteStates` after `pushTags`)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/sync_meta_repository.dart` (unsupported flag)
- Create: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/note_state_sync_service.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/onedrive_graph_client.dart` (after `putTags`, line 226)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/onedrive_sync_provider.dart` (after `pushTags`, line 60)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/api_sync_provider.dart` (no-op stubs after `pushTags`; replaced in Task 7)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/sync_orchestrator.dart` (imports; tombstone insert in `_maybePullNote`, line 384; new step 3b after the note push, line 298; `metadataClean`, line 326; tag-membership tail of `_applyPulledNote`, lines 497–502; new `_syncNoteStates` after `_syncTags`)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/note_state_sync_service_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_note_states_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/onedrive_note_states_graph_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_restore_test.dart` (create)

**Interfaces:**
- Consumes: `LocalNoteStateRepository.getAllStates/putState/deleteState`, `NoteState` (Task 5), `LocalHmmNoteRepository.restoreNote` (Task 5), `SyncOrchestrator({provider, db, meta, vaultStore})`, `noopVaultStore` / `FakeOneDriveAuth` (`test/core/data/sync/onedrive_test_fakes.dart`).
- Produces (Dart):
  - `const String kTombstoneSubject = '(deleted)';` (`sync_models.dart`; Task 8 reuses it).
  - `SyncPhase.noteStates`.
  - `class NoteStatesUnsupportedException implements Exception` (`cloud_sync_provider.dart`).
  - `CloudSyncProvider.pullNoteStates() → Future<Map<String, dynamic>?>` (default null) and `CloudSyncProvider.pushNoteStates(Map<String, dynamic> doc, {required Set<String> changed}) → Future<void>` (default no-op).
  - Document shape: `{'version': 1, 'device_id': String, 'generated_at': ISO, 'states': [{'noteUuid': String, 'isPinned': bool, 'flagColor': int?, 'lastModified': ISO-8601 UTC}]}` (`device_id` / `generated_at` are diagnostics, as in `tags.json`).
  - `class NoteStateMerge { final Map<String, dynamic> document; final Set<String> localWins; }`, `class NoteStateSyncService { NoteStateSyncService(LocalNoteStateRepository repo); Future<NoteStateMerge> merge(Map<String, dynamic>? remoteDoc, {required Set<String> knownNoteUuids, required String deviceId, required DateTime now}); }`
  - `SyncMetaRepository.getNoteStatesUnsupported(String providerId) → Future<bool>`, `setNoteStatesUnsupported(String providerId, bool value) → Future<void>` — key `sync_note_states_unsupported:<providerId>`; the later "Pins and flags need the latest server" banner reads it (no UI in slice 1).
  - `OneDriveGraphClient.getNoteStates() / putNoteStates(Map<String, dynamic>)` at `users/{sub}/note-states.json`.
  - Sync errors with `recordType: 'noteStates'` are non-fatal (the note cursor still advances; the merge recomputes next sync).
  - Pulled note body: `tags` present ⇒ set-replace, absent ⇒ keep (was: clear).

- [ ] **Step 1: Write the failing merge tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/note_state_sync_service_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/data/sync/note_state_sync_service.dart';
import 'package:hmm_console/core/notes/note_state.dart';

void main() {
  late HmmDatabase db;
  late LocalNoteStateRepository repo;
  late NoteStateSyncService service;
  final t1 = DateTime.utc(2026, 10, 1, 9);
  final t2 = t1.add(const Duration(hours: 1));
  final now = DateTime.utc(2026, 10, 2);

  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalNoteStateRepository(db);
    service = NoteStateSyncService(repo);
  });

  tearDown(() => db.close());

  Map<String, dynamic> doc(List<Map<String, dynamic>> states) =>
      {'version': 1, 'states': states};

  Map<String, dynamic> entry(String uuid,
          {bool pinned = false, int? flag, required DateTime at}) =>
      {'noteUuid': uuid, 'isPinned': pinned, 'flagColor': flag, 'lastModified': at.toIso8601String()};

  Future<NoteStateMerge> merge(Map<String, dynamic>? remote,
          {Set<String> known = const {'n1', 'n2'}}) =>
      service.merge(remote, knownNoteUuids: known, deviceId: 'dev-a', now: now);

  Map<String, dynamic>? pushed(NoteStateMerge m, String uuid) =>
      (m.document['states'] as List)
          .cast<Map<String, dynamic>>()
          .where((s) => s['noteUuid'] == uuid)
          .firstOrNull;

  test('a newer remote state is applied and the merged document carries it',
      () async {
    final m = await merge(doc([entry('n1', pinned: true, flag: 2, at: t2)]));

    final s = await repo.getState('n1');
    expect(s.isPinned, isTrue);
    expect(s.flagColor, 2);
    expect(m.localWins, isEmpty);
    expect(pushed(m, 'n1')!['isPinned'], isTrue);
    expect(m.document['version'], 1);
    expect(m.document['device_id'], 'dev-a');
  });

  test('a newer local unpin beats an older remote pin', () async {
    await repo.putState(NoteState(noteUuid: 'n1', isPinned: false, lastModifiedDate: t2));

    final m = await merge(doc([entry('n1', pinned: true, at: t1)]));

    expect((await repo.getState('n1')).isPinned, isFalse);
    expect(m.localWins, {'n1'});
    expect(pushed(m, 'n1')!['isPinned'], isFalse,
        reason: 'unpin travels as a row with false, not as a missing row');
  });

  test('a newer remote unpin is applied as a false row', () async {
    await repo.putState(NoteState(noteUuid: 'n1', isPinned: true, flagColor: 4, lastModifiedDate: t1));

    await merge(doc([entry('n1', pinned: false, flag: null, at: t2)]));

    final rows = await db.select(db.noteStates).get();
    expect(rows, hasLength(1));
    expect(rows.single.isPinned, isFalse);
    expect(rows.single.flagColor, isNull);
  });

  test('a tie keeps local and is not a local win', () async {
    await repo.putState(NoteState(noteUuid: 'n1', isPinned: true, lastModifiedDate: t1));

    final m = await merge(doc([entry('n1', pinned: false, at: t1)]));

    expect((await repo.getState('n1')).isPinned, isTrue);
    expect(m.localWins, isEmpty);
  });

  test('a local state absent remotely is a local win', () async {
    await repo.putState(NoteState(noteUuid: 'n2', flagColor: 0, lastModifiedDate: t1));

    final m = await merge(null);

    expect(m.localWins, {'n2'});
    expect(pushed(m, 'n2')!['flagColor'], 0);
  });

  test('an entry for a note that no longer exists is ignored and not pushed back',
      () async {
    final m = await merge(doc([entry('gone', pinned: true, at: t2)]));

    expect(await repo.getAllStates(), isEmpty);
    expect(pushed(m, 'gone'), isNull);
  });

  test('a local state for a note that no longer exists is dropped', () async {
    await repo.putState(NoteState(noteUuid: 'gone', isPinned: true, lastModifiedDate: t2));

    final m = await merge(null);

    expect(await repo.getAllStates(), isEmpty);
    expect(m.localWins, isEmpty);
  });

  test('an unknown flag colour is kept; malformed entries are skipped', () async {
    final m = await merge(doc([
      entry('n1', flag: 42, at: t2),
      {'isPinned': true, 'lastModified': t2.toIso8601String()}, // no uuid
      {'noteUuid': 'n2', 'isPinned': true, 'lastModified': 'not a date'},
      {'noteUuid': 'n2', 'isPinned': true, 'flagColor': 'red', 'lastModified': t2.toIso8601String()},
    ]));

    expect((await repo.getState('n1')).flagColor, 42);
    final n2 = await repo.getState('n2');
    expect(n2.isPinned, isTrue, reason: 'a non-numeric flag reads as unflagged');
    expect(n2.flagColor, isNull);
    expect(pushed(m, 'n1')!['flagColor'], 42);
  });
}
```

- [ ] **Step 2: Write the failing orchestrator, graph and tag tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_note_states_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late _FakeProvider provider;
  late SyncMetaRepository meta;
  late SyncOrchestrator orchestrator;
  late LocalNoteStateRepository states;

  final t0 = DateTime.utc(2026, 10, 1, 9);
  final t1 = t0.add(const Duration(hours: 1));
  final t2 = t0.add(const Duration(hours: 2));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    provider = _FakeProvider();
    meta = SyncMetaRepository();
    orchestrator = SyncOrchestrator(
        provider: provider, db: db, meta: meta, vaultStore: noopVaultStore);
    states = LocalNoteStateRepository(db);
  });

  tearDown(() => db.close());

  Future<int> insertNote(String uuid,
          {String subject = 'mine', required DateTime modified, DateTime? deletedAt, String? content = 'body'}) =>
      db.into(db.notes).insert(NotesCompanion.insert(
            uuid: Value(uuid),
            subject: subject,
            content: Value(content),
            authorId: 1,
            createDate: Value(t0),
            lastModifiedDate: Value(modified),
            deletedAt: Value(deletedAt),
          ));

  Future<Note> row(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

  SyncManifest manifest(List<ManifestEntry> notes) => SyncManifest(
      version: 1, generatedAt: t2, deviceId: 'other', notes: notes, attachments: const []);

  Map<String, dynamic>? pushedState(String uuid) =>
      (provider.pushedStates!['states'] as List)
          .cast<Map<String, dynamic>>()
          .where((s) => s['noteUuid'] == uuid)
          .firstOrNull;

  test('a pin on this device and a text edit on another both survive', () async {
    final id = await insertNote('n1', modified: t0);
    // This device already synced the note; then it only pinned it.
    await meta.setLastPushedAt('fake', t0.add(const Duration(minutes: 1)));
    await states.setPinned('n1', true);
    // The other device edited the text later and never pinned.
    provider.remoteManifest = manifest([ManifestEntry(id: 'n1', updatedAt: t2, deleted: false)]);
    provider.remoteBodies['n1'] = {
      'uuid': 'n1', 'subject': 'edited on B', 'content': 'new body',
      'lastModifiedDate': t2.toIso8601String(), 'tags': const <String>[],
    };
    provider.remoteStates = {'version': 1, 'states': const []};

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    final r = await row(id);
    expect(r.subject, 'edited on B', reason: 'the text edit applied');
    expect((await states.getState('n1')).isPinned, isTrue, reason: 'the pin survived');
    expect(provider.pushedBodies.containsKey('n1'), isFalse,
        reason: 'pinning never re-pushes the note, so it cannot overwrite the edit');
    expect(pushedState('n1')!['isPinned'], isTrue);
    expect(provider.pushedChanged, {'n1'});
  });

  test('a remote pin applies without touching the local note row', () async {
    final id = await insertNote('n1', modified: t2);
    await meta.setLastPushedAt('fake', t2.add(const Duration(minutes: 1)));
    final before = await row(id);
    provider.remoteManifest = manifest([ManifestEntry(id: 'n1', updatedAt: t2, deleted: false)]);
    provider.remoteStates = {
      'version': 1,
      'states': [
        {'noteUuid': 'n1', 'isPinned': true, 'flagColor': 3, 'lastModified': t1.toIso8601String()},
      ],
    };

    await orchestrator.syncNow();

    final s = await states.getState('n1');
    expect(s.isPinned, isTrue);
    expect(s.flagColor, 3);
    final after = await row(id);
    expect(after.lastModifiedDate, before.lastModifiedDate);
    expect(after.version, before.version);
    expect(provider.pushedBodies, isEmpty);
  });

  test('an old server keeps local state and sets the unsupported flag', () async {
    await insertNote('n1', modified: t0);
    await states.putState(NoteState(noteUuid: 'n1', isPinned: true, lastModifiedDate: t1));
    provider.remoteManifest = manifest([ManifestEntry(id: 'n1', updatedAt: t0, deleted: false)]);
    provider.unsupported = true;

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: 'an old server is not a sync failure');
    expect((await states.getState('n1')).isPinned, isTrue);
    expect(provider.pushCalls, 0);
    expect(await meta.getNoteStatesUnsupported('fake'), isTrue);

    // The server is upgraded: it has no states yet, so every local one goes up.
    provider.unsupported = false;
    provider.remoteStates = null;
    await orchestrator.syncNow();

    expect(await meta.getNoteStatesUnsupported('fake'), isFalse);
    expect(provider.pushedChanged, {'n1'});
  });

  test('a state for a purged note is dropped and never revives the note', () async {
    // Purged on this device: a content-free tombstone (Task 8) plus a stale
    // state row; a peer that has not purged yet still pushes a newer pin.
    final id = await insertNote('n1',
        subject: kTombstoneSubject, content: null, modified: t0, deletedAt: t0);
    await states.putState(NoteState(noteUuid: 'n1', isPinned: true, lastModifiedDate: t0));
    provider.remoteManifest = manifest([ManifestEntry(id: 'n1', updatedAt: t0, deleted: true)]);
    provider.remoteStates = {
      'version': 1,
      'states': [
        {'noteUuid': 'n1', 'isPinned': true, 'flagColor': null, 'lastModified': t2.toIso8601String()},
      ],
    };

    final result = await orchestrator.syncNow();

    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
    expect(await states.getAllStates(), isEmpty);
    expect(pushedState('n1'), isNull);
    final r = await row(id);
    expect(r.deletedAt, isNotNull);
    expect(r.subject, kTombstoneSubject);
  });

  test('a failed state pull is a non-fatal error and advances the cursor', () async {
    await insertNote('n1', modified: t0);
    provider.remoteManifest = manifest([ManifestEntry(id: 'n1', updatedAt: t0, deleted: false)]);
    provider.failPull = true;

    final result = await orchestrator.syncNow();

    expect(result.errors.map((e) => e.recordType), ['noteStates']);
    expect(await meta.getLastPushedAt('fake'), isNotNull);
  });

  test('an absent tags key keeps membership; a present empty list clears it',
      () async {
    final id = await insertNote('n1', modified: t0);
    final tags = LocalTagRepository(db);
    await tags.setTagsForNote(id, ['work']);

    provider.remoteManifest = manifest([ManifestEntry(id: 'n1', updatedAt: t1, deleted: false)]);
    provider.remoteBodies['n1'] = {
      'uuid': 'n1', 'subject': 'mine', 'lastModifiedDate': t1.toIso8601String(),
    }; // no 'tags' key: an older client, or a server without note tags
    await orchestrator.syncNow();
    expect(await tags.tagNamesForNote(id), ['work']);

    provider.remoteManifest = manifest([ManifestEntry(id: 'n1', updatedAt: t2, deleted: false)]);
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
  final Map<String, Map<String, dynamic>> remoteBodies = {};
  final Map<String, Map<String, dynamic>> pushedBodies = {};
  Map<String, dynamic>? remoteStates;
  Map<String, dynamic>? pushedStates;
  Set<String>? pushedChanged;
  int pushCalls = 0;
  bool unsupported = false;
  bool failPull = false;

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
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async => pushedBodies[id] = body;

  @override
  Future<Map<String, dynamic>?> pullNoteStates() async {
    if (unsupported) throw const NoteStatesUnsupportedException();
    if (failPull) throw StateError('offline');
    return remoteStates;
  }

  @override
  Future<void> pushNoteStates(Map<String, dynamic> doc, {required Set<String> changed}) async {
    pushCalls++;
    pushedStates = doc;
    pushedChanged = changed;
  }
}
```

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/onedrive_note_states_graph_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'onedrive_test_fakes.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  const path = '/me/drive/special/approot:/users/SUB-1/note-states.json:/content';

  setUp(() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
  });

  OneDriveGraphClient client() =>
      OneDriveGraphClient(FakeOneDriveAuth(), () async => 'SUB-1', dio: dio);

  test('getNoteStates returns the decoded body on 200', () async {
    adapter.onGet(path, (s) => s.reply(200, {
          'version': 1,
          'states': [
            {'noteUuid': 'n1', 'isPinned': true, 'flagColor': null, 'lastModified': '2026-10-01T09:00:00.000Z'},
          ],
        }));

    final doc = await client().getNoteStates();

    expect((doc!['states'] as List).single['noteUuid'], 'n1');
  });

  test('getNoteStates returns null when note-states.json is absent (404)', () async {
    adapter.onGet(path, (s) => s.reply(404, null));

    expect(await client().getNoteStates(), isNull);
  });

  test('putNoteStates PUTs the document to the user-scoped note-states.json', () async {
    Map<String, dynamic>? captured;
    adapter.onPut(path, (s) => s.reply(200, {'ok': true}), data: Matchers.any);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (o.method == 'PUT' && o.path == path && o.data is Map) {
        captured = o.data as Map<String, dynamic>;
      }
      h.next(o);
    }));

    await client().putNoteStates({'version': 1, 'states': const []});

    expect(captured!['version'], 1);
  });
}
```

- [ ] **Step 3: Write the restore-propagation tests**

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

- [ ] **Step 4: Run to verify failure**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/sync/note_state_sync_service_test.dart test/core/data/sync/sync_orchestrator_note_states_test.dart \
  test/core/data/sync/onedrive_note_states_graph_test.dart test/core/data/sync/sync_orchestrator_restore_test.dart
```
Expected: compile errors `Target of URI doesn't exist: 'package:hmm_console/core/data/sync/note_state_sync_service.dart'`, `Undefined name 'kTombstoneSubject'`, `The method 'getNoteStates' isn't defined for the type 'OneDriveGraphClient'`. Run the restore file alone (`flutter test test/core/data/sync/sync_orchestrator_restore_test.dart`): it already PASSES — it pins existing last-writer-wins behaviour plus Task 5's `restoreStamp`. If any restore test fails here, stop and investigate before changing the orchestrator.

- [ ] **Step 5: Shared constants, provider contract and the unsupported flag**

In `sync_models.dart`, after the `library;` line add:

```dart

/// Subject of a content-free tombstone row: one pulled for a note this device
/// never had, or a cloudStorage note purged after 30 days. The row keeps its
/// uuid and deletedAt so the manifest keeps propagating the delete. Such a
/// row carries no note state (see `NoteStateSyncService`).
const String kTombstoneSubject = '(deleted)';
```

and in `enum SyncPhase` add `noteStates,` after `pushNotes,`.

In `cloud_sync_provider.dart`, add before `abstract class CloudSyncProvider`:

```dart
/// Thrown by [CloudSyncProvider.pullNoteStates] when the remote cannot store
/// note state at all (an Hmm API older than the notes redesign). The caller
/// keeps every local state and pushes nothing.
class NoteStatesUnsupportedException implements Exception {
  const NoteStatesUnsupportedException();

  @override
  String toString() => 'NoteStatesUnsupportedException';
}
```

and inside the class, after `pushTags`:

```dart

  // ---- Note states (pins + flags, Notes redesign G14) ----

  /// Fetch the note-state document `{version: 1, states: [{noteUuid,
  /// isPinned, flagColor, lastModified}]}`, or null when the remote has none
  /// yet. Throws [NoteStatesUnsupportedException] when the remote cannot
  /// store note state. Default: null.
  Future<Map<String, dynamic>?> pullNoteStates() async => null;

  /// Push note states. [doc] is the full merged document; [changed] holds the
  /// note uuids whose local state beat the remote one. A whole-document
  /// store (OneDrive) writes [doc]; a per-row store (the Hmm API) sends only
  /// [changed]. Default: no-op.
  Future<void> pushNoteStates(Map<String, dynamic> doc,
      {required Set<String> changed}) async {}
```

In `sync_meta_repository.dart`, after `clear`, add:

```dart

  static String _noteStatesUnsupportedKey(String providerId) =>
      'sync_note_states_unsupported:$providerId';

  /// True after the last sync found a remote without note-state support (an
  /// old Hmm API). Read by the "Pins and flags need the latest server" banner.
  Future<bool> getNoteStatesUnsupported(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_noteStatesUnsupportedKey(providerId)) ?? false;
  }

  Future<void> setNoteStatesUnsupported(String providerId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_noteStatesUnsupportedKey(providerId), value);
  }
```

- [ ] **Step 6: The merge service**

Create `/Users/fchy/Projects/hmm_console/lib/core/data/sync/note_state_sync_service.dart`:

```dart
import '../../notes/note_state.dart';
import '../local/local_note_state_repository.dart';

/// Result of [NoteStateSyncService.merge].
class NoteStateMerge {
  const NoteStateMerge({required this.document, required this.localWins});

  /// Every surviving state at its winning version — the document to push.
  final Map<String, dynamic> document;

  /// Note uuids whose local state is strictly newer than the remote one, or
  /// absent remotely: what a per-row remote must receive.
  final Set<String> localWins;
}

/// Merges note states (pins + flags, Notes redesign G14) per entry, the
/// same way [TagSyncService] merges tag definitions: newer `lastModified`
/// wins, a tie keeps local. Entries for notes that no longer exist
/// ([knownNoteUuids] excludes them — purged notes, content-free tombstones)
/// are neither applied nor pushed, and their local rows are dropped.
class NoteStateSyncService {
  NoteStateSyncService(this._repo);

  final LocalNoteStateRepository _repo;

  Future<NoteStateMerge> merge(
    Map<String, dynamic>? remoteDoc, {
    required Set<String> knownNoteUuids,
    required String deviceId,
    required DateTime now,
  }) async {
    // 1. Drop local states whose note no longer exists anywhere.
    final local = await _repo.getAllStates();
    for (final uuid in local.keys.toList()) {
      if (!knownNoteUuids.contains(uuid)) {
        await _repo.deleteState(uuid);
        local.remove(uuid);
      }
    }

    // 2. Parse remote entries defensively; ignore unknown notes.
    final remote = <String, NoteState>{};
    for (final raw in (remoteDoc?['states'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final s = _parse(raw.cast<String, dynamic>());
      if (s != null && knownNoteUuids.contains(s.noteUuid)) {
        remote[s.noteUuid] = s;
      }
    }

    // 3. Remote-newer wins; a tie keeps local.
    for (final r in remote.values) {
      final l = local[r.noteUuid];
      if (l == null || r.lastModifiedDate.isAfter(l.lastModifiedDate)) {
        await _repo.putState(r);
      }
    }

    // 4. What the remote is missing or holds older.
    final localWins = <String>{
      for (final l in local.values)
        if (remote[l.noteUuid] == null ||
            l.lastModifiedDate.isAfter(remote[l.noteUuid]!.lastModifiedDate))
          l.noteUuid,
    };

    final merged = await _repo.getAllStates();
    final uuids = merged.keys.toList()..sort();
    return NoteStateMerge(
      document: {
        'version': 1,
        'device_id': deviceId,
        'generated_at': now.toUtc().toIso8601String(),
        'states': [
          for (final uuid in uuids)
            {
              'noteUuid': uuid,
              'isPinned': merged[uuid]!.isPinned,
              'flagColor': merged[uuid]!.flagColor,
              'lastModified':
                  merged[uuid]!.lastModifiedDate.toUtc().toIso8601String(),
            },
        ],
      },
      localWins: localWins,
    );
  }

  static NoteState? _parse(Map<String, dynamic> j) {
    final uuid = j['noteUuid'];
    final at = DateTime.tryParse(j['lastModified'] as String? ?? '');
    if (uuid is! String || uuid.isEmpty || at == null) return null;
    final flag = j['flagColor'];
    return NoteState(
      noteUuid: uuid,
      isPinned: j['isPinned'] is bool ? j['isPinned'] as bool : false,
      // Any int is kept verbatim (a newer client's colour shows grey).
      flagColor: flag is num ? flag.toInt() : null,
      lastModifiedDate: at.toUtc(),
    );
  }
}
```

- [ ] **Step 7: OneDrive transport (and the API stubs)**

In `onedrive_graph_client.dart`, after `putTags`, add:

```dart

  /// Fetch the user's note-state document from `users/{sub}/note-states.json`
  /// (pins + flags), or null when the file doesn't exist yet.
  Future<Map<String, dynamic>?> getNoteStates() async {
    final path = await _userPath('note-states.json', action: 'content');
    final resp = await _dio.get<Map<String, dynamic>>(path);
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data;
  }

  /// Push the user's note-state document to `users/{sub}/note-states.json`.
  Future<void> putNoteStates(Map<String, dynamic> body) async {
    final path = await _userPath('note-states.json', action: 'content');
    final resp = await _dio.put(
      path,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }
```

In `onedrive_sync_provider.dart`, after `pushTags`, add:

```dart

  @override
  Future<Map<String, dynamic>?> pullNoteStates() => _graph.getNoteStates();

  /// One whole document, like tags.json: [changed] is not needed here.
  @override
  Future<void> pushNoteStates(Map<String, dynamic> doc,
          {required Set<String> changed}) =>
      _graph.putNoteStates(doc);
```

In `api_sync_provider.dart` (it `implements` the contract, so it does not inherit the defaults), after `pushTags`, add the stubs Task 7 replaces:

```dart

  // ---- Note states ---- (wired to the API in Task 7)

  @override
  Future<Map<String, dynamic>?> pullNoteStates() async => null;

  @override
  Future<void> pushNoteStates(Map<String, dynamic> doc,
      {required Set<String> changed}) async {}
```

- [ ] **Step 8: Orchestrator — state sync, tombstone constant, non-fatal errors, tags on an absent key**

In `sync_orchestrator.dart`:

1. Add the imports `import '../local/local_note_state_repository.dart';` and `import 'note_state_sync_service.dart';`.
2. In `_maybePullNote`'s tombstone insert, replace `subject: '(deleted)',` with `subject: kTombstoneSubject,`.
3. Immediately after `timer.stop(SyncPhase.pushNotes);` add:

```dart

    // -------- 3b. Note states (pins + flags, G14) --------
    // After the note pull (pulled notes exist locally, restores applied) and
    // the note push (the API has every note a state can point at). Never
    // writes a note row, so a pin can never overwrite a text edit.
    try {
      await timer.run(
          SyncPhase.noteStates, () => _syncNoteStates(p, remote, errors));
    } catch (e) {
      errors.add(SyncError(
        recordType: 'noteStates',
        recordId: 'note-states',
        message: 'Note state sync threw: $e',
      ));
    }
```

4. Replace

```dart
    final metadataClean =
        errors.every((e) => e.recordType == 'attachment');
```

with

```dart
    // Attachment bytes and note states are re-derived on the next sync, so
    // their errors must not hold the note cursor back.
    const nonBlocking = {'attachment', 'noteStates'};
    final metadataClean =
        errors.every((e) => nonBlocking.contains(e.recordType));
```

5. Replace the tag-membership tail of `_applyPulledNote`

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

6. Add after `_syncTags`:

```dart

  // ==================== NOTE STATES sync (G14) ====================

  Future<void> _syncNoteStates(
    CloudSyncProvider p,
    SyncManifest? remote,
    List<SyncError> errors,
  ) async {
    Map<String, dynamic>? remoteDoc;
    try {
      remoteDoc = await p.pullNoteStates();
    } on NoteStatesUnsupportedException {
      // Old server: keep every local state untouched and push nothing; the
      // UI reads the flag ("Pins and flags need the latest server").
      await _meta.setNoteStatesUnsupported(p.providerId, true);
      return;
    } catch (e) {
      errors.add(SyncError(
        recordType: 'noteStates',
        recordId: 'note-states',
        message: 'Failed to pull note states: $e',
      ));
      return;
    }
    await _meta.setNoteStatesUnsupported(p.providerId, false);

    final merge = await NoteStateSyncService(LocalNoteStateRepository(_db))
        .merge(
      remoteDoc,
      knownNoteUuids: await _stateBearingNoteUuids(remote),
      deviceId: await _meta.getOrCreateDeviceId(),
      now: DateTime.now(),
    );
    try {
      await p.pushNoteStates(merge.document, changed: merge.localWins);
    } catch (e) {
      errors.add(SyncError(
        recordType: 'noteStates',
        recordId: 'note-states',
        message: 'Failed to push note states: $e',
      ));
    }
  }

  /// Note uuids a state may belong to: every local note except a content-
  /// free tombstone (a purged note, or a delete this device only ever saw as
  /// a tombstone), plus every live note of the remote manifest (its pull may
  /// have failed this run — a failed pull must not drop a pin).
  Future<Set<String>> _stateBearingNoteUuids(SyncManifest? remote) async {
    final rows = await _db.select(_db.notes).get();
    return {
      for (final n in rows)
        if (n.uuid != null && !_isContentFreeTombstone(n)) n.uuid!,
      for (final e in remote?.notes ?? const <ManifestEntry>[])
        if (!e.deleted) e.id,
    };
  }

  static bool _isContentFreeTombstone(Note n) =>
      n.deletedAt != null &&
      n.subject == kTombstoneSubject &&
      n.content == null &&
      n.attachments == null;
```

- [ ] **Step 9: Run tests**

```bash
cd /Users/fchy/Projects/hmm_console
flutter test test/core/data/sync/
flutter analyze
```
Expected: `All tests passed!` (including the existing `sync_orchestrator_tags_test.dart`, `sync_orchestrator_timing_test.dart` — every `SyncPhase` value, the new one included, is reported — and `onedrive_tags_graph_test.dart`); analyze at the 2 pre-existing infos.

- [ ] **Step 10: Commit**

```bash
cd /Users/fchy/Projects/hmm_console
git add lib/core/data/sync/sync_models.dart lib/core/data/sync/cloud_sync_provider.dart \
  lib/core/data/sync/sync_meta_repository.dart lib/core/data/sync/note_state_sync_service.dart \
  lib/core/data/sync/onedrive_graph_client.dart lib/core/data/sync/onedrive_sync_provider.dart \
  lib/core/data/sync/api_sync_provider.dart lib/core/data/sync/sync_orchestrator.dart \
  test/core/data/sync/note_state_sync_service_test.dart test/core/data/sync/sync_orchestrator_note_states_test.dart \
  test/core/data/sync/onedrive_note_states_graph_test.dart test/core/data/sync/sync_orchestrator_restore_test.dart
git commit -m "$(cat <<'MSG'
feat(sync): per-entry note-state sync (pins/flags) via note-states.json

Merged like tags.json: newer lastModified wins, a tie keeps local, purged
notes' entries are dropped, the note row is never written. A remote without
note-state support keeps local state and sets a flag for the UI. A pulled
note body without a tags key now keeps local membership. Restore
propagation and the equal-timestamp tie are pinned by tests.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 7: Client — `ApiSyncProvider` syncs note states, restores via the undelete endpoint, syncs tags

Note: there is no cloudApi note *repository* in the app today — `hmmNoteRepositoryProvider` throws `UnimplementedError` for `DataMode.cloudApi` (`lib/core/data/repository_providers.dart:38`). Notes reach the API only through `SyncOrchestrator` + `ApiSyncProvider` over the local Drift store, so that is where slice 1 wires the cloudApi side.

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/api_sync_provider.dart` (imports line 19–28; fields after line 61; `pushNoteBody` 173–224; `_createNote` 289–304; `_updateNote` 306–315; `_orchestratorBodyFromApiNote` 369–384; `pullTags`/`pushTags` 414–424; the Task 6 note-state stubs after `pushTags`)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/api_sync_provider_slice1_test.dart` (create)

**Interfaces:**
- Consumes (server, Tasks 1–4): `GET /notes/states` → `[{noteId, noteUuid, isPinned, flagColor, lastModifiedDate}]`, `PUT /notes/{id}/state {isPinned, flagColor, lastModifiedDate}`, `ApiNote.tagNames`, `POST /notes/{id}/restore`, `PUT /notes/{id}/tags {"names": [...]}`, `GET|POST /tags`, `DELETE /tags/{id}`; `NoteStatesUnsupportedException`, `pullNoteStates` / `pushNoteStates(doc, changed:)` (Task 6).
- Produces: `pullNoteStates` maps the server rows to the Task 6 document (rows without a `noteUuid` are skipped) and throws `NoteStatesUnsupportedException` on 404/405; `pushNoteStates` PUTs only the `changed` uuids (server id from the GET, else the by-uuid probe; a note the server does not have yet is skipped and retried next sync; other failures are counted and thrown once as `ApiSyncProviderException`); note bodies carry no pin/flag; pulled body key `tags` only when the server sent `tagNames`; push: restore-then-PUT for a server tombstone being revived; no DELETE for an already-deleted server note; tag definitions doc `{'version': 1, 'tags': [{name, description, is_activated, last_modified (epoch), deleted: false}]}`.

- [ ] **Step 1: Write the failing tests**

Create `/Users/fchy/Projects/hmm_console/test/core/data/sync/api_sync_provider_slice1_test.dart`:

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
    test('tag names come through when the server sends them', () async {
      existing('abc', {
        'id': 7, 'subject': 's', 'content': 'c', 'catalogName': 'General',
        'lastModifiedDate': '2026-10-18T10:00:00Z', 'isDeleted': false,
        'tagNames': ['work'],
      });

      final body = (await provider.pullNoteBody('abc'))!;

      expect(body['tags'], ['work']);
      expect(body.containsKey('isPinned'), isFalse, reason: 'pin/flag are note state, never note body');
      expect(body.containsKey('flagColor'), isFalse);
    });

    test('an empty tagNames list stays a present key (clears on apply)', () async {
      existing('abc', {'id': 7, 'subject': 's', 'tagNames': []});

      final body = (await provider.pullNoteBody('abc'))!;

      expect(body.containsKey('tags'), isTrue);
      expect(body['tags'], isEmpty);
    });

    test('an old server (no tagNames) yields a body without a tags key', () async {
      existing('abc', {'id': 7, 'subject': 's', 'content': 'c', 'isDeleted': false});

      final body = (await provider.pullNoteBody('abc'))!;

      expect(body.containsKey('tags'), isFalse);
    });
  });

  group('push', () {
    test('create sends no pin/flag and pushes tags to the new id', () async {
      adapter.onGet('/notes/by-uuid/new', (s) => s.reply(404, {'detail': 'nf'}));
      adapter.onGet('/authors', (s) => s.reply(200, {'value': [{'id': 3}]}));
      adapter.onGet('/notecatalogs', (s) => s.reply(200, {'value': [{'id': 1, 'name': 'General'}]}));
      adapter.onPost('/notes', (s) => s.reply(201, {'id': 99, 'uuid': 'new'}), data: Matchers.any);
      adapter.onPut('/notes/99/tags', (s) => s.reply(200, ['work']), data: Matchers.any);

      await provider.pushNoteBody('new', {
        'subject': 's', 'content': 'c', 'catalogName': 'General',
        'tags': ['work'],
      });

      final create = sent['POST /notes'] as Map<String, dynamic>;
      expect(create.containsKey('isPinned'), isFalse);
      expect(create.containsKey('flagColor'), isFalse);
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

    test('an update without a tags key makes no tags call', () async {
      existing('u', {'id': 42});
      adapter.onPut('/notes/42', (s) => s.reply(204, null), data: Matchers.any);

      await provider.pushNoteBody('u', {'subject': 's', 'content': 'c'});

      expect(writes, ['PUT /notes/42']);
      final payload = sent['PUT /notes/42'] as Map<String, dynamic>;
      expect(payload.containsKey('isPinned'), isFalse);
    });

    test('an old server without the tags endpoint does not fail the push', () async {
      existing('u', {'id': 42});
      adapter.onPut('/notes/42', (s) => s.reply(204, null), data: Matchers.any);
      adapter.onPut('/notes/42/tags', (s) => s.reply(404, {'detail': 'nf'}), data: Matchers.any);

      await provider.pushNoteBody('u', {'subject': 's', 'content': 'c', 'tags': ['a']});

      expect(writes, ['PUT /notes/42', 'PUT /notes/42/tags']);
    });
  });

  group('note states', () {
    test('pullNoteStates maps the caller\'s rows to the state document', () async {
      adapter.onGet('/notes/states', (s) => s.reply(200, [
            {'noteId': 7, 'noteUuid': 'abc', 'isPinned': true, 'flagColor': 42,
             'lastModifiedDate': '2026-10-18T10:00:00Z'},
            {'noteId': 8, 'noteUuid': null, 'isPinned': true, 'flagColor': null,
             'lastModifiedDate': '2026-10-18T10:00:00Z'},
          ]));

      final doc = (await provider.pullNoteStates())!;

      final state = (doc['states'] as List).single as Map<String, dynamic>;
      expect(state['noteUuid'], 'abc');
      expect(state['isPinned'], isTrue);
      expect(state['flagColor'], 42, reason: 'unknown colours are kept');
      expect(DateTime.parse(state['lastModified'] as String), DateTime.utc(2026, 10, 18, 10));
    });

    test('a server without the states endpoint is reported as unsupported', () async {
      adapter.onGet('/notes/states', (s) => s.reply(404, {'detail': 'nf'}));

      await expectLater(provider.pullNoteStates(), throwsA(isA<NoteStatesUnsupportedException>()));
    });

    test('pushNoteStates PUTs only the changed states, by server id', () async {
      adapter.onGet('/notes/states', (s) => s.reply(200, [
            {'noteId': 7, 'noteUuid': 'abc', 'isPinned': false, 'flagColor': null,
             'lastModifiedDate': '2026-10-18T09:00:00Z'},
          ]));
      adapter.onPut('/notes/7/state', (s) => s.reply(200, {}), data: Matchers.any);
      await provider.pullNoteStates();

      await provider.pushNoteStates({
        'states': [
          {'noteUuid': 'abc', 'isPinned': false, 'flagColor': null, 'lastModified': '2026-10-18T10:00:00.000Z'},
          {'noteUuid': 'same', 'isPinned': true, 'flagColor': 1, 'lastModified': '2026-10-18T08:00:00.000Z'},
        ],
      }, changed: {'abc'});

      expect(writes, ['PUT /notes/7/state']);
      expect(sent['PUT /notes/7/state'],
          {'isPinned': false, 'flagColor': null, 'lastModifiedDate': '2026-10-18T10:00:00.000Z'},
          reason: 'unpin is sent as false, never as a delete');
    });

    test('a note unknown to the GET is resolved by uuid; one the server lacks is skipped', () async {
      adapter.onGet('/notes/states', (s) => s.reply(200, []));
      adapter.onGet('/notes/by-uuid/new', (s) => s.reply(200, {'id': 9, 'uuid': 'new'}));
      adapter.onGet('/notes/by-uuid/unsynced', (s) => s.reply(404, {'detail': 'nf'}));
      adapter.onPut('/notes/9/state', (s) => s.reply(200, {}), data: Matchers.any);
      await provider.pullNoteStates();

      await provider.pushNoteStates({
        'states': [
          {'noteUuid': 'new', 'isPinned': true, 'flagColor': 0, 'lastModified': '2026-10-18T10:00:00.000Z'},
          {'noteUuid': 'unsynced', 'isPinned': true, 'flagColor': null, 'lastModified': '2026-10-18T10:00:00.000Z'},
        ],
      }, changed: {'new', 'unsynced'});

      expect(writes, ['PUT /notes/9/state']);
    });

    test('a failed PUT is reported once, after the others were tried', () async {
      adapter.onGet('/notes/states', (s) => s.reply(200, [
            {'noteId': 7, 'noteUuid': 'a', 'isPinned': false, 'lastModifiedDate': '2026-10-18T09:00:00Z'},
            {'noteId': 8, 'noteUuid': 'b', 'isPinned': false, 'lastModifiedDate': '2026-10-18T09:00:00Z'},
          ]));
      adapter.onPut('/notes/7/state', (s) => s.reply(500, {'detail': 'boom'}), data: Matchers.any);
      adapter.onPut('/notes/8/state', (s) => s.reply(200, {}), data: Matchers.any);
      await provider.pullNoteStates();

      await expectLater(
        provider.pushNoteStates({
          'states': [
            {'noteUuid': 'a', 'isPinned': true, 'lastModified': '2026-10-18T10:00:00.000Z'},
            {'noteUuid': 'b', 'isPinned': true, 'lastModified': '2026-10-18T10:00:00.000Z'},
          ],
        }, changed: {'a', 'b'}),
        throwsA(isA<ApiSyncProviderException>()),
      );
      expect(writes, ['PUT /notes/7/state', 'PUT /notes/8/state']);
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
Expected: FAIL — e.g. `tag names come through when the server sends them` (`Expected: ['work'] Actual: <null>`), `pullNoteStates maps the caller's rows` (`Null check operator used on a null value` — the Task 6 stub returns null), `a restored note is undeleted` (`Expected: ['POST /notes/8/restore', 'PUT /notes/8'] Actual: ['PUT /notes/8']`), `pullTags maps server tags` (`Null check operator used on a null value`).

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
    };
    await _dio.put<void>('/notes/$existingId', data: payload);
  }

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
      // Only what the server actually sent: an older server has no
      // tagNames, and an absent `tags` key makes the orchestrator keep the
      // local membership instead of wiping it. Pin/flag never ride the note
      // body (G14) — see pullNoteStates.
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

Replace the Task 6 note-state stubs (`// ---- Note states ---- (wired to the API in Task 7)` and its two methods) with:

```dart
  // ---- Note states (pins + flags, G14) ----
  //
  // GET /v1/notes/states returns the caller's rows; PUT
  // /v1/notes/{id}/state upserts one (the server keeps the newer
  // lastModifiedDate). The orchestrator merges, then hands us the uuids
  // whose local state won.

  /// note uuid → server note id, filled by [pullNoteStates] and used by
  /// [pushNoteStates] in the same sync run.
  final Map<String, int> _serverNoteIdByUuid = {};

  @override
  Future<Map<String, dynamic>?> pullNoteStates() async {
    _serverNoteIdByUuid.clear();
    final Response<dynamic> resp;
    try {
      resp = await _dio.get<dynamic>('/notes/states');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405) {
        // A server older than the notes redesign: keep local state.
        throw const NoteStatesUnsupportedException();
      }
      rethrow;
    }
    final states = <Map<String, dynamic>>[];
    for (final raw in _unwrapValueList(resp.data)) {
      if (raw is! Map) continue;
      final uuid = raw['noteUuid'] as String?;
      final id = raw['noteId'] as int?;
      final at = DateTime.tryParse(raw['lastModifiedDate'] as String? ?? '');
      if (uuid == null || uuid.isEmpty || at == null) continue;
      if (id != null) _serverNoteIdByUuid[uuid] = id;
      states.add({
        'noteUuid': uuid,
        'isPinned': (raw['isPinned'] as bool?) ?? false,
        'flagColor': (raw['flagColor'] as num?)?.toInt(),
        'lastModified': at.toUtc().toIso8601String(),
      });
    }
    return {'version': 1, 'states': states};
  }

  @override
  Future<void> pushNoteStates(Map<String, dynamic> doc,
      {required Set<String> changed}) async {
    if (changed.isEmpty) return;
    final byUuid = <String, Map>{
      for (final raw in (doc['states'] as List?) ?? const [])
        if (raw is Map && raw['noteUuid'] is String) raw['noteUuid'] as String: raw,
    };
    var failed = 0;
    for (final uuid in changed) {
      final s = byUuid[uuid];
      if (s == null) continue;
      try {
        final id = _serverNoteIdByUuid[uuid] ?? await _serverIdForUuid(uuid);
        if (id == null) continue; // not on the server yet; retried next sync
        await _dio.put<dynamic>('/notes/$id/state', data: {
          'isPinned': (s['isPinned'] as bool?) ?? false,
          'flagColor': s['flagColor'],
          'lastModifiedDate': s['lastModified'],
        });
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) continue; // note gone meanwhile
        failed++;
      }
    }
    if (failed > 0) {
      throw ApiSyncProviderException(
          '$failed note state(s) failed to push; retrying next sync.');
    }
  }

  Future<int?> _serverIdForUuid(String uuid) async {
    try {
      final probe = await _dio.get<Map<String, dynamic>>(
        '/notes/by-uuid/$uuid',
        queryParameters: {'includeDeleted': true},
      );
      final id = probe.data?['id'] as int?;
      if (id != null) _serverNoteIdByUuid[uuid] = id;
      return id;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
```

Also update the file header comment's wire mapping (lines 5–12) by adding after the `pushManifest` line:

```dart
//   restore        POST /v1/notes/{id}/restore before the PUT when the
//                  server row is soft-deleted but the pushed body is live
//   tags           GET|POST /v1/tags, DELETE /v1/tags/{id} (definitions);
//                  PUT /v1/notes/{id}/tags (membership, set-replace)
//   note states    GET /v1/notes/states, PUT /v1/notes/{id}/state
//                  (pins + flags; 404 on the GET = server too old)
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
feat(sync): cloudApi syncs note states and tags, restores through the undelete endpoint

A revived server tombstone is restored before the PUT (which 500'd), a
tombstone already deleted on the server is no longer re-DELETEd, pins and
flags travel through the note-state endpoints (an old server keeps local
state), and an old server's missing tagNames no longer wipes local tags.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

### Task 8: Client — real purge (`NotePurgeService`), provider `purgeNote`, deferred OneDrive purge

Safe behaviour per mode (G6/G9/G11):

| Mode | Local row | Remote | Why |
|------|-----------|--------|-----|
| `local` | hard-deleted (+ tag refs and the note's state row, children detached) | — | nothing else holds it |
| `cloudStorage` | **scrubbed to a content-free tombstone** (`subject = '(deleted)'`, content/attachments/location/catalog/parent cleared, `uuid`/`deletedAt`/`lastModifiedDate` kept; the note's `NoteStates` row deleted — the Task 6 merge then drops the entry from `note-states.json`) | blob (+ released vault files) deleted **inside the next sync, after the pull** | `_buildManifest` is built from local rows; a hard-deleted row would vanish from the manifest and a device that never saw the delete would re-push its live copy (`_collectMissingFromRemote`). The kept tombstone keeps propagating the delete. Deferring the blob deletion lets the pull first revive a note restored on another device. `lastModifiedDate` is NOT bumped, so peers' 30-day clocks are not reset and a newer restore elsewhere still wins. |
| `cloudApi` | hard-deleted (+ its state row) **after** `DELETE /notes/{id}/purge` succeeds (or 404) | server row removed by the purge endpoint (409 if live) | the server is the manifest; the 409 guard means a restore that reached the server first is never destroyed |

Every local write is guarded by `deletedAt = <value just read>`, so a restore that lands between the candidate query and the write wins.

**Files:**
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/cloud_sync_provider.dart` (add `purgeNote`, `NoteLiveOnServerException`)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/onedrive_sync_provider.dart` (after `listAttachmentPaths`, line 75)
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/api_sync_provider.dart` (after `listAttachmentPaths`, end of class)
- Create: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/pending_remote_purge_store.dart`
- Create: `/Users/fchy/Projects/hmm_console/lib/core/data/local/note_purge_service.dart`
- Modify: `/Users/fchy/Projects/hmm_console/lib/core/data/sync/sync_orchestrator.dart` (constructor 39–55; call site before `timer.stop(SyncPhase.pullNotes)` line 271; the `nonBlocking` set from Task 6; new `_flushRemotePurges`)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/local/note_purge_service_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/sync_orchestrator_remote_purge_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/api_sync_provider_purge_test.dart` (create)
- Test: `/Users/fchy/Projects/hmm_console/test/core/data/sync/onedrive_sync_provider_purge_test.dart` (create)

**Interfaces:**
- Consumes: `kTombstoneSubject` (Task 6), the `NoteStates` table (Task 5; server rows cascade with the note, Task 1), `collectReferencedVaultPaths(HmmDatabase)` (`lib/core/data/vault/vault_gc.dart`), `IVaultStore.delete`, `baseVaultStoreProvider`, `OneDriveGraphClient.deleteNoteBlob/deleteAttachment`, server `DELETE /notes/{id}/purge` (Task 3).
- Produces (Dart):
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

  Future<void> addState(String uuid) => db.into(db.noteStates).insert(
      NoteStatesCompanion.insert(
          noteUuid: uuid, isPinned: const Value(true), lastModifiedDate: old));

  Future<List<String>> stateUuids() async =>
      (await db.select(db.noteStates).get()).map((s) => s.noteUuid).toList()..sort();

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

    test('purge removes the note\'s state row', () async {
      await insert('gone', deletedAt: old);
      await insert('keeper');
      await addState('gone');
      await addState('keeper');

      await service(DataMode.local).purgeExpired(now);

      expect(await stateUuids(), ['keeper']);
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

    test('purge removes the note\'s state row', () async {
      await insert('gone', deletedAt: old);
      await addState('gone');

      await service(DataMode.cloudStorage).purgeExpired(now);

      expect(await stateUuids(), isEmpty,
          reason: 'the stub keeps no pin/flag; the merge drops the remote entry');
      expect((await byUuid('gone'))!.subject, kTombstoneSubject);
    });

    test('an already scrubbed tombstone is not processed again', () async {
      await insert('gone', deletedAt: old);
      final s = service(DataMode.cloudStorage);

      expect(await s.purgeExpired(now), 1);
      expect(await s.purgeExpired(now.add(const Duration(days: 1))), 0);
    });
  });

  group('cloudApi mode', () {
    test('calls the server purge, then deletes the row and its state', () async {
      await insert('gone', deletedAt: old);
      await addState('gone');

      expect(await service(DataMode.cloudApi).purgeExpired(now), 1);

      expect(provider.purged, ['gone']);
      expect(await byUuid('gone'), isNull);
      expect(await stateUuids(), isEmpty,
          reason: 'the server cascades its rows; the client drops its own');
      expect(vault.deleted, isEmpty, reason: 'the server releases cloudApi vault bytes');
    });

    test('keeps the row when the server says the note is live', () async {
      final id = await insert('gone', deletedAt: old);
      await addState('gone');
      provider.liveOnServer = true;

      expect(await service(DataMode.cloudApi).purgeNow(id), PurgeOutcome.keptLiveOnServer);
      expect(await byUuid('gone'), isNotNull);
      expect(await stateUuids(), ['gone'], reason: 'a live note keeps its pin');
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
        DataMode.local => await _hardDelete(row.id, row.uuid, deletedAt),
        DataMode.cloudStorage =>
          await _scrubToTombstone(row.id, row.uuid, deletedAt),
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
    return _hardDelete(row.id, uuid, deletedAt);
  }

  Future<bool> _hardDelete(int id, String? uuid, DateTime deletedAt) =>
      _db.transaction(() async {
        final gone = await (_db.delete(_db.notes)
              ..where((n) => n.id.equals(id) & n.deletedAt.equals(deletedAt)))
            .go();
        if (gone == 0) return false; // restored meanwhile
        await (_db.delete(_db.noteTagRefs)..where((r) => r.noteId.equals(id)))
            .go();
        await _deleteState(uuid);
        await _detachChildren(id);
        return true;
      });

  /// cloudStorage: keep a content-free tombstone so the manifest keeps
  /// propagating the delete. lastModifiedDate is deliberately NOT bumped:
  /// peers keep their own 30-day clock, and a newer restore elsewhere still
  /// wins the pull and refills this row.
  Future<bool> _scrubToTombstone(int id, String? uuid, DateTime deletedAt) =>
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
        ));
        if (changed == 0) return false; // restored meanwhile
        await (_db.delete(_db.noteTagRefs)..where((r) => r.noteId.equals(id)))
            .go();
        await _deleteState(uuid);
        await _detachChildren(id);
        return true;
      });

  /// A purged note's pin/flag goes with it (G14). The note row never held
  /// them; the sync merge drops the remote entry once the note is gone.
  Future<void> _deleteState(String? uuid) async {
    if (uuid == null) return;
    await (_db.delete(_db.noteStates)..where((s) => s.noteUuid.equals(uuid)))
        .go();
  }

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
3. Immediately before `timer.stop(SyncPhase.pullNotes);` (after the `if (remote != null) { ... }` block) add:

```dart

    // Deferred remote purges (cloudStorage, see NotePurgeService). Runs only
    // after the pull above had its chance to revive a note restored on
    // another device.
    await _flushRemotePurges(p, remote, errors);
```

4. Replace

```dart
    const nonBlocking = {'attachment', 'noteStates'};
```

with

```dart
    // A failed remote purge is retried from the pending store next sync, so
    // it must not hold the note cursor back either.
    const nonBlocking = {'attachment', 'noteStates', 'purge'};
```

5. Add the method after `_syncNoteStates` (Task 6):

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
git add lib/core/data/sync/cloud_sync_provider.dart \
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
note). Every mode drops the note's state row (pins/flags). Guarded writes
mean a restore that lands meanwhile always wins.

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
- Consumes: `contactCatalogName` (`lib/core/data/local/local_contact_repository.dart:20`), `cheatsheetCatalogName` (`lib/core/data/local/local_cheatsheet_repository.dart:17`), `kGeneralCatalogName` + `CatalogPalette.domainKeyFor` (`lib/core/notes/catalog_palette.dart`), `IHmmNoteRepository.restoreNote`, `INoteStateRepository.setPinned/setFlagColor`, `noteStateRepositoryProvider`, `NoteState`, `LocalNoteStateRepository` (Task 5).
- Produces (Dart):
  - `bool canDeleteFromNotes(HmmNote note, String? catalogName)`
  - `enum NoteManagePlace { contacts, cheatsheets, automobile, ownScreen }`, `NoteManagePlace? managePlaceFor(String? catalogName)`
  - `class EntityNoteDeleteRefused implements Exception { final NoteManagePlace place; }`
  - `MutateNote.delete(int id)` now throws `EntityNoteDeleteRefused` for entity notes; `MutateNote.restore(int id) → Future<HmmNote>`, `setPinned(int id, bool pinned) → Future<NoteState>`, `setFlagColor(int id, int? flagColor) → Future<NoteState>` — both resolve the note's uuid and write only its state row (never the note; a missing note throws `StateError`).

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
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
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
      noteStateRepositoryProvider.overrideWithValue(LocalNoteStateRepository(db)),
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

  test('pin and flag write the state row, never the note', () async {
    final id = await noteIn('General');
    final before = (await notes.getNoteById(id))!;
    final mutate = container.read(mutateNoteProvider);

    final state = await mutate.setPinned(id, true);
    await mutate.setFlagColor(id, 4);

    expect(state.noteUuid, before.uuid);
    final after = (await notes.getNoteById(id))!;
    expect(after.version, before.version);
    expect(after.lastModifiedDate, before.lastModifiedDate);
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

In `mutate_note_state.dart` add `import '../../../core/notes/note_state.dart';` and `import 'note_delete_policy.dart';` and replace

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

  /// Pin or unpin (G14: writes the note's state row only — not a note
  /// edit, so it never bumps the note or re-pushes it).
  Future<NoteState> setPinned(int id, bool pinned) async =>
      ref.read(noteStateRepositoryProvider)
          .setPinned(await _uuidOf(id), pinned);

  /// [flagColor] null clears the flag. Same state-only semantics as
  /// [setPinned].
  Future<NoteState> setFlagColor(int id, int? flagColor) async =>
      ref.read(noteStateRepositoryProvider)
          .setFlagColor(await _uuidOf(id), flagColor);

  Future<String> _uuidOf(int id) async {
    final note = await ref.read(hmmNoteRepositoryProvider).getNoteById(id);
    if (note == null) throw StateError('Note $id not found');
    return note.uuid;
  }

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
- Consumes: `MutateNote.delete/restore/setPinned/setFlagColor`, `canDeleteFromNotes`, `managePlaceFor` (Task 10), `NoteFlagColor` (Task 5), `showUndoableAction`, `HelpButton`, `NoteState.isPinned/flag` + `noteStateRepositoryProvider` (Task 5).
- Changes `NoteDetailData` to `NoteDetailData(HmmNote note, NoteCatalog? catalog, [NoteState? state])` — `state` defaults to `NoteState.none(note.uuid)`, so the existing tests that build `NoteDetailData(note, catalog)` (`note_detail_screen_test.dart`, `note_detail_media_test.dart`, `raw_content_screen_test.dart`, `notes_shell_delete_test.dart`, `note_display_widgets_test.dart`) compile unchanged. The constructor is no longer `const`; none of those tests uses `const`.
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
import 'package:hmm_console/core/notes/note_state.dart';
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
  Future<NoteState> setPinned(int id, bool pinned) async {
    calls.add('pin $id $pinned');
    return NoteState(noteUuid: 'u$id', isPinned: pinned, lastModifiedDate: DateTime.utc(2026));
  }

  @override
  Future<NoteState> setFlagColor(int id, int? flagColor) async {
    calls.add('flag $id $flagColor');
    return NoteState(noteUuid: 'u$id', flagColor: flagColor, lastModifiedDate: DateTime.utc(2026));
  }
}

NoteCatalog _catalog(String name) =>
    NoteCatalog(id: 1, name: name, schema: '{}', formatType: 3, isDefault: false);

Future<_RecordingMutate> _pump(WidgetTester tester,
    {String catalog = 'General', bool pinned = false, int? flag}) async {
  final mutate = _RecordingMutate();
  final note = HmmNote(
      id: 5, uuid: 'u5', subject: 'My note', authorId: 1, catalogId: 1,
      content: 'Hello body', createDate: DateTime(2026, 1, 1));
  final state = NoteState(
      noteUuid: 'u5', isPinned: pinned, flagColor: flag, lastModifiedDate: DateTime.utc(2026));
  // A fresh key per pump: a second pump in one test gets a new scope with
  // its own overrides instead of updating the old one.
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      mutateNoteProvider.overrideWithValue(mutate),
      noteDetailProvider(5).overrideWith((ref) async => NoteDetailData(note, _catalog(catalog), state)),
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
import '../../../../core/notes/note_state.dart';
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
  /// [state] (pin/flag, G14) defaults to "no row": unpinned, unflagged.
  NoteDetailData(this.note, this.catalog, [NoteState? state])
      : state = state ?? NoteState.none(note.uuid);
  final HmmNote note;
  final NoteCatalog? catalog;
  final NoteState state;
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
  final state =
      await ref.watch(noteStateRepositoryProvider).getState(note.uuid);
  return NoteDetailData(note, catalog, state);
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
                    await _togglePin(context, ref, l, d.state);
                  case _MenuAction.flag:
                    await _chooseFlag(context, ref, l, d.state);
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
                        d.state.isPinned ? l.notesUnpin : l.notesPin)),
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
              final flag = d.state.flag;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      if (d.state.isPinned)
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
      AppLocalizations l, NoteState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final mutate = ref.read(mutateNoteProvider);
    final container = ProviderScope.containerOf(context);
    try {
      await mutate.setPinned(noteId, !state.isPinned);
      container.invalidate(noteDetailProvider(noteId));
    } catch (e) {
      debugPrint('NoteDetailScreen: pin failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.notesPinFailed)));
    }
  }

  Future<void> _chooseFlag(BuildContext context, WidgetRef ref,
      AppLocalizations l, NoteState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final mutate = ref.read(mutateNoteProvider);
    final container = ProviderScope.containerOf(context);
    final choice = await showNoteFlagSheet(context, current: state.flag);
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
- The `noteDetailProvider` invalidation after pin/flag uses the `ProviderContainer` captured before the await, never the `WidgetRef`; it re-reads the state row (the note row did not change).
- Pin and flag read `d.state`, never the note: `HmmNote` has no pin/flag fields (G14).

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
dotnet test src/Hmm.Core.Tests 2>&1 | tail -1               # Passed: 239 (baseline 233)
dotnet test src/Hmm.ServiceApi.Core.Tests 2>&1 | tail -1    # Passed: 466 (baseline 440)
dotnet test src/Hmm.Core.Dal.EF.Tests 2>&1 | tail -1        # Passed: 81 (baseline 68)
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
Then run the app on the iOS simulator in Cloud (API) mode: pin a note and flag it from the detail ⋯ menu, sync, and confirm with `GET /v1/notes/states` that the caller's row has `isPinned: true` and the flag, and that `GET /v1/notes/by-uuid/{uuid}` shows an unchanged `lastModifiedDate` (pinning is not a note edit); delete it, tap Undo, sync, and confirm the server row is live (`GET /v1/notes/by-uuid/{uuid}`). In Cloud Storage mode confirm `users/{sub}/note-states.json` on OneDrive has the note's entry (`noteUuid`, `isPinned`, `flagColor`, `lastModified`) and that the note blob has no pin/flag keys; unpin and confirm the entry stays with `isPinned: false`.

- [ ] **Step 4: Record the deploy checklist (for the human; do NOT execute here)**

**Order is mandatory: server first, then client.** A client release that calls `/notes/states`, `/restore`, `/purge` or `/tags` before the server has them would find pins and flags unsupported (the client keeps them locally and shows nothing server-side) and could not restore or purge.

1. Merge `hmm` branch `feat/notes-pin-flag-undelete` to `main` after review (never stage `hmm/CLAUDE.md`).
2. Back up the production PostgreSQL database on the VPS (use the `hmm-deployer` agent's pre-deploy backup).
3. Deploy the `hmm` API to the VPS. On startup `AutomobileAppStartupFilter` runs `Database.Migrate()` and logs **"PostgreSQL migrations applied"** — confirm that line, and that `20261018000000_AddNoteUserStatesTable` is in `__EFMigrationsHistory` (table `noteuserstates` exists).
4. Smoke-test production with a real token: `GET /v1/notes/states` → 200 (array); `PUT /v1/notes/{id}/state {"isPinned":true,"flagColor":null,"lastModifiedDate":"<now, UTC>"}` on an own note → 200 echoing the row, then the same body with `isPinned:false` and a later stamp → 200 with `isPinned:false`; `GET /v1/notes/by-uuid/{uuid}` body has `tagNames` and no pin/flag fields; `POST /v1/notes/{id}/restore` on a deleted note → 200; `PUT /v1/notes/{id}/tags {"names":[]}` → 200; `DELETE /v1/notes/{id}/purge` on a live note → 409.
5. Only then merge `hmm_console` `feat/notes-list-redesign` (slice 1) and build the client with the production dart-defines (`scripts/deploy-prod-ios-device.sh` — a plain `flutter build` points at localhost).
6. After the client release, watch one sync cycle per mode for `recordType: 'purge'` errors and for "The server cannot restore deleted notes yet" or `SyncMetaRepository.getNoteStatesUnsupported('hmm_api') == true` (either means step 3 did not land).
