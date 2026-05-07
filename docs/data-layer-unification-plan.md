# Data-Layer Unification Plan

> Make the Flutter client (hmm_console) share one contract for `Author` and `HmmNote` CRUD across all three operating modes (`local`, `cloudStorage`, `cloudApi`), aligned with the Hmm.ServiceApi server-side shape.

Drafted 2026-05-06. Owners: Chaoyang. Lives next to the rest of the design docs.

---

## 1. North star

The local SQLite DB is the **single source of truth on the device** for all three modes. Reads always come from local. Writes commit to local first, then a configurable `ISyncProvider` propagates changes to the chosen remote (OneDrive blob or Hmm REST API). Every record carries `authorId` matching the IdP-issued JWT `sub` claim — same shape as the API.

This is the "offline-first with pluggable sync" pattern (Linear Sync Engine, Apple CloudKit, Notion). It's the only architecture that lets you switch modes without losing data, and it falls out naturally from the API's existing shape.

## 2. Why this shape (mapping API ⇄ client)

The API design implies the client architecture. The job is to mirror, not invent.

| API contract | Client implication |
|---|---|
| `Author.AccountName = JWT sub`; `CurrentUserAuthorProvider` auto-provisions on first hit | Local `Authors.accountName = JWT sub`, auto-provisioned on first sign-in |
| `HmmNote.AuthorId` + `CatalogId` are FK, **immutable after create** (PUT/PATCH only allow Subject/Content/Description) | Local `Notes.authorId` + `catalogId` are immutable after create. `updateNote` rejects changes to either. |
| `IsDeleted` flag — DELETE is soft-delete | Local `Notes.deletedAt` already does this — keep |
| `Version` rowversion for optimistic concurrency | Local `Notes.version` blob already exists — feed into update calls |
| API has **no implicit user-scoping** in the controller — client must pass `AuthorId` | Client filters `where authorId == currentAuthorId` on every read; sets it on every create |
| Pagination via `PageList<T>` (offset-based: pageIndex, pageSize, totalCount, totalPages, hasPrev, hasNext) | Client `PageList<T>` mirrors the same envelope. The existing `PaginatedResponse<T>` becomes a thin alias or gets renamed. |
| Non-note entities (Automobile, GasLog, GasStation) stored as serialized HmmNote content, scoped by Author + Catalog | Already true on the client. Same scoping rules apply. |
| Tags M:N via join table; M:N is **not synced** by the existing manifest | Tags need an explicit sync story for the API mode (none exists today) — see Phase 5 |
| Manager pattern: domain → validator → manager → repo, returning `ProcessingResult<T>` | Client equivalent: UseCase → Repository, throwing typed exceptions on failure (Dart idiom) |

## 3. Three modes, one code path

```
                ┌─────────────────────────────────────────────────────────┐
                │  ViewModels  /  UseCases                                 │
                └─────────────────────────────────────────────────────────┘
                                       ↓
                ┌─────────────────────────────────────────────────────────┐
                │  Repository interfaces (single set, mirrors API shape)   │
                │  INoteRepository / IAuthorRepository / IGasLogRepository │
                │  /  IAutomobileRepository  /  IGasStationRepository      │
                │  /  INoteCatalogRepository /  ITagRepository             │
                └─────────────────────────────────────────────────────────┘
                                       ↓
                ┌─────────────────────────────────────────────────────────┐
                │  ONE implementation per repo, backed by Drift            │
                │  (the *current* `local_*_repository.dart` files,         │
                │   AuthorId-aware, no mode branching)                     │
                └─────────────────────────────────────────────────────────┘
                                       ↓
                ┌─────────────────────────────────────────────────────────┐
                │  Local SQLite (canonical state, soft-delete,             │
                │  version, uuid for cross-device identity)                │
                └─────────────────────────────────────────────────────────┘
                                       ↓ (orchestrator, async, opt-in)
                ┌─────────────────────────────────────────────────────────┐
                │  ISyncProvider (selected by DataMode)                    │
                │  ├─ NoneSync   (local mode — no-op)                      │
                │  ├─ OneDriveSync (cloudStorage — manifest+blobs, real)   │
                │  └─ ApiSync   (cloudApi — REST to /v1/notes etc, NEW)    │
                └─────────────────────────────────────────────────────────┘
```

The current `repository_providers.dart` `_useLocal(mode)` branching goes away. Mode only changes which `ISyncProvider` is active.

## 4. Phases

Ordered so each is independently shippable and testable. Phases 1–3 unblock the iPhone today; Phase 4 is the architectural refactor; Phase 5 is opportunistic cleanup.

> **Phase 0** (login required): mostly already done — router redirects unauthenticated users to `/auth`, no "guest" UI exists. Only chore left was prose: dropped "no account needed" from `DataMode.local` description in `lib/core/data/data_mode.dart:21`.

### Phase 1 — Author bootstrap from JWT (~45 min)

The first patch that makes "create vehicle" work for a real signed-in user.

**New file: `lib/core/auth/current_author_account_name_provider.dart`**
- Riverpod `Provider<String>` reading `currentUserProvider.uid` (the JWT `sub`).
- Throws `StateError` if unauthenticated. The router's auth gate guarantees no feature screen reaches this provider in an unauthenticated state, so a throw is louder than a silent fallback.
- A second provider, `currentAuthorProvider`, gives the materialized `Author` row (resolves via `IAuthorRepository.getOrCreateDefaultAuthor`).

**Edit `lib/features/auth/states/login_state.dart`**
- After successful login, call `_authorRepo.getOrCreateDefaultAuthor(user.uid)`. Optionally enrich:
  - `description = user.displayName`
  - `avatarUrl = user.photoUrl`
- This keeps the local `Authors` table in lockstep with what the API's `CurrentUserAuthorProvider.CreateUserAuthorAsync` would produce server-side.

**Edit `lib/features/auth/states/logout_state.dart` (or equivalent)**
- Decision: **do not** wipe the Author row or any owned data on logout. Re-sign-in is instant and lossless. A separate "Clear local data" toggle in Settings is the right place for explicit wipe (Phase 5, optional).

### Phase 2 — AuthorId-scoped local reads/writes (~2 hr)

Stops the "No author found" exception and prevents cross-author data leakage.

**Edit `lib/core/data/local/local_note_repository.dart`**
- Inject `Ref` (or `currentAuthorProvider`) into the repo.
- `getNotes(...)` adds `..where((n) => n.authorId.equals(currentAuthor.id))` to the Drift query.
- `getNoteById(id)` adds the same filter (so author A can never read author B's note even by guessing the int id).
- `createNote(...)` always sets `authorId = currentAuthor.id`. Don't accept it as a parameter from callers — single source of truth.
- `updateNote(...)` rejects any companion that tries to change `authorId` or `catalogId`. Match the API's PUT/PATCH contract: only `subject`, `content`, `description` are mutable.
- `deleteNote(...)` stays soft (`deletedAt = now()`).

**Edit `lib/core/data/local/local_automobile_repository.dart`, `local_gas_log_repository.dart`, `local_gas_station_repository.dart`**
- Replace the broken `final authors = await _authorRepo.getAuthors(); if (authors.isEmpty) throw Exception('No author found');` pattern at:
  - `local_automobile_repository.dart:53`
  - `local_gas_log_repository.dart:63`
  - `local_gas_station_repository.dart:46`
- With:
  ```dart
  final author = await ref.read(currentAuthorProvider.future);
  // ...uses author.id
  ```
- All `getXxx` queries scope through the underlying `INoteRepository.getNotes()` call, which is now AuthorId-filtered. So no further changes needed in these three files for reads — the catalog filter (`'Hmm.AutomobileMan.GasLog'` etc.) already narrows correctly within the author's notes.

**Add invariant test**
- `test/core/data/local/author_isolation_test.dart`: seed two authors, write a note under each, query as author A, assert author B's note is absent.

### Phase 3 — Align repository contract to API shape (~3 hr)

Pure refactor. Sets up Phase 4 by making the contract shareable across backends.

**New file: `lib/core/data/page_list.dart`**
```dart
class PageList<T> {
  final List<T> items;
  final int currentPage;     // 1-based, matches API
  final int pageSize;
  final int totalCount;
  final int totalPages;
  bool get hasPrevPage => currentPage > 1;
  bool get hasNextPage => currentPage < totalPages;
}
```
- The existing `PaginatedResponse<T>` becomes a deprecated alias, then gets removed once callers migrate.

**Edit interface signatures in `lib/core/data/local/local_*_repository.dart`** to mirror the API verbatim where practical:

```dart
abstract interface class INoteRepository {
  Future<PageList<Note>> getNotes({
    int? catalogId,
    int? parentNoteId,
    int pageIndex = 1,
    int pageSize = 25,
    bool includeDeleted = false,
  });
  Future<Note> getNoteById(int id);
  Future<Note?> getNoteByUuid(String uuid);              // for sync layer
  Future<Note> createNote(NoteCreate input);             // input has subject, content, catalogId, optional parentNoteId
  Future<Note> updateNote(int id, NoteUpdate patch);     // patch has subject?, content?, description? — NOT authorId/catalogId
  Future<void> deleteNote(int id);                       // soft-delete
  Future<void> applyTag(int noteId, String tagName);     // matches API /v1/notes/{id}/applyTag
  Future<void> removeTag(int noteId, String tagName);
}

abstract interface class IAuthorRepository {
  Future<Author?> getCurrentAuthor();
  Future<Author> getOrCreateDefaultAuthor(String accountName);
  Future<Author> updateAuthor(int id, AuthorUpdate patch);  // bio, displayName, avatarUrl etc.
  Future<void> deactivateAuthor(int id);                    // sets isActivated=false
}
```

**New domain entities `lib/features/notes/data/models/`**: `Note`, `NoteCreate`, `NoteUpdate`, `Author`, `AuthorUpdate`. Today the repos return Drift rows directly — Phase 3 introduces domain types so feature code is DB-agnostic.

**Mappers**: `lib/core/data/mappers/note_mapper.dart`, `author_mapper.dart`. Drift row → domain entity, NoteCreate → NotesCompanion.

**Wire `IGasLogRepository`, `IAutomobileRepository`, `IGasStationRepository`** to use `PageList<T>` consistently. They already use `PaginatedResponse` — bookkeeping rename.

**Edit existing API repos** under `lib/core/data/api/` (`_GasLogApiRepository`, `_AutomobileApiRepository`, `_GasStationApiRepository`) so their methods also return `PageList<T>` and accept the same parameters as the local impls. The interfaces should be byte-identical between local and API.

By the end of Phase 3:
- Single set of repository interfaces, shared across all backends.
- Single Drift-backed implementation, AuthorId-aware.
- ViewModels never know which backend is which.
- The (still-direct) API repos in `cloudApi` mode satisfy the same interface — switching modes doesn't change the call sites.

### Phase 4 — Make `cloudApi` mode use local-first storage (~1 day)

Today, `cloudApi` mode bypasses the local DB and hits the REST API directly. That breaks offline access and creates the data-divergence problem the unification is meant to prevent. Phase 4 routes all three modes through local first.

**Delete** `lib/core/data/api/_gas_log_api_repository.dart`, `_automobile_api_repository.dart`, `_gas_station_api_repository.dart`. Their REST-call logic moves into the new `ApiSyncProvider`.

**Edit `lib/core/data/repository_providers.dart`** — drop the `_useLocal(mode)` branching entirely. Every repo always returns the local Drift-backed impl. `dataModeProvider` only affects which `ISyncProvider` is wired.

**Extend `lib/core/data/sync/cloud_sync_provider.dart`** — current `CloudSyncProvider` is shaped for blob storage (manifest + per-note JSON + per-attachment bytes). For the API, that's awkward — the API exposes typed CRUD, not blobs. Two options:

| Option | Pros | Cons |
|---|---|---|
| **A. Add typed methods** to `CloudSyncProvider` (`pullNotesPaged`, `pushNote`, `deleteNoteRemote`, etc.) | Clean abstraction, API and OneDrive each implement what they support naturally | OneDrive impl needs to bridge typed → manifest internally; small adapter overhead |
| **B. Keep blob shape**, have `ApiSyncProvider` translate manifest entries to/from REST calls | Less code today | Friction at every boundary; API has soft-delete tombstones, page cursors, version stamps that don't fit the blob model |

**Pick A.** The API has a richer contract worth modeling at the abstraction layer.

**New `lib/core/data/sync/api_sync_provider.dart`** — implements typed `ISyncProvider` methods using the existing `ApiClient` (Dio). Endpoints used:
- `GET /v1/notes?pageIndex=&pageSize=&includeDeleted=true` (pull-since-cursor)
- `GET /v1/notes/{id}`
- `POST /v1/notes`
- `PUT /v1/notes/{id}` (or `PATCH` for partials)
- `DELETE /v1/notes/{id}` (server soft-deletes)
- `PUT /v1/notes/{id}/applyTag`
- Author auto-provisioning happens server-side on first request (handled by `CurrentUserAuthorProvider`); client doesn't need to call anything explicit.

Authentication is automatic via the existing `AuthInterceptor` adding the IdP-issued bearer token.

**Edit `lib/core/data/sync/sync_orchestrator.dart`** — make it provider-agnostic. The pull/push algorithm is the same (manifest-driven for OneDrive, paginated-since-cursor for API). Differences are mediated through the typed `ISyncProvider` methods.

**Drift schema migration v4**: add `Notes.lastSyncedAt` (DateTime?). Needed for the API's "give me changes since X" pagination. OneDrive doesn't need it — harmless there. Migration steps:
- Bump `schemaVersion` in `database.dart`.
- `MigrationStrategy.onUpgrade` adds the column with default `null`.
- First sync after upgrade does a full pull to populate; subsequent syncs use the cursor.

**End state**: turning on `cloudApi` mode starts pushing local changes to `https://api.homemademessage.com/v1/notes` and pulling remote changes back. Switching between modes preserves all local data.

### Phase 5 — Opportunistic gaps from the API survey (~half day, optional)

Not blocking. File and cherry-pick when the relevant feature actually needs them.

- **API has no implicit user-scoping** — `HmmNoteController` returns whatever notes the caller asks for, with no `WHERE AuthorId = currentUserAuthor.Id` clause. Fine for our single-tenant case but a security hole the moment any third party gets a token. **Server-side TODO**: add author-scoping to the controller (`HmmNoteController.cs` should call `_currentUserAuthorProvider.GetCurrentUserAuthorAsync()` and filter every query/return path). Same fix needed in `AutomobileController`, `TagController`, etc.
- **Tags not in OneDrive manifest** — tags are stored client-side but never sync via OneDrive. Either add to manifest (every note's manifest entry grows) or accept "tags are device-local in cloudStorage mode" and document it.
- **`hmm.mobile` ROPC** — agreed earlier this is fine for now. Real fix is `authorization_code + PKCE`, ~1 day, separate plan.
- **DP-key backup** — `/var/lib/hmm-idp/dp-keys` should be in the VPS backup story. Currently `pg_dump HmmIdp` is the only documented backup; add a tar of the dp-keys dir alongside.
- **"Clear local data" UX** in Settings — explicit wipe button for shared-device scenarios. Calls `_db.delete(_db.notes).go()` etc. Useful when a user permanently signs out from a household device.
- **Anonymous-merge UX** — already moot since we're removing offline-anonymous mode. Keep this row deleted from the plan.

## 5. Recommended ship order (given iPhone testing is live)

| Order | Scope | Why |
|---|---|---|
| 1. **Now** | Phases 1 + 2 | Unblocks iPhone "create vehicle". No architectural risk. |
| 2. **Same session** | Phase 3 | Pure refactor. Sets up Phase 4. |
| 3. **Next session** | Phase 4 | Big one. Test in dev first against fresh DB; the migration changes data flow. |
| 4. **As needed** | Phase 5 | Cherry-pick by feature pressure. |

## 6. Risks & trade-offs

- **Phase 4 is a real refactor** — ~1 day, touches 6-8 files. If `cloudApi` mode isn't actually used today (it isn't, beyond gas_log experiments), defer indefinitely and Phases 1-3 are sufficient.
- **Migration v4 in Phase 4** adds `lastSyncedAt` to Notes. Drift handles migrations declaratively but you'll need to bump schema version and add a `MigrationStrategy` step. Test the upgrade path on a real device DB before shipping.
- **Tags-in-manifest** for Phase 5 OneDrive change is non-trivial — manifests today are flat lists of note/attachment UUIDs. Adding tag membership means every note's manifest entry grows. Easier to skip until anyone actually relies on tag sync.
- **Single-tenant assumption** — this whole plan assumes "one user per device" most of the time. If you ever support family sharing, the AuthorId-filter pattern still works — just `getOrCreateDefaultAuthor(activeAccountName)` becomes more dynamic. Nothing structural to change.
- **API author-scoping (Phase 5 row 1)** is a real security gap. Don't open the API to third parties before fixing it.

## 7. Glossary (matches both sides)

- **Author**: user identity on the data model side. Local `Authors.accountName` and API `Author.AccountName` both equal the IdP JWT `sub` claim.
- **HmmNote / Note**: single canonical record type that wraps domain entities. AuthorId + CatalogId define ownership.
- **NoteCatalog**: classifies notes (e.g. `'Hmm.AutomobileMan.GasLog'`). Required FK on every Note.
- **ProcessingResult<T>** (server) ↔ thrown typed exceptions (client): both convey success/failure. Client uses `AppException` hierarchy in `lib/core/exceptions/app_exceptions.dart`.
- **PageList<T>**: shared pagination envelope across server and client.
- **uuid**: stable cross-device identifier on `Notes` and `Attachments`. Int `id` is local-only.
- **DataMode**: `local` | `cloudStorage` | `cloudApi`. Selects which `ISyncProvider` is active. Does **not** change the read/write code path.

---

*Update this doc whenever a phase completes — note what shipped, what changed, and what was deferred. Old plan revisions stay in git history.*
