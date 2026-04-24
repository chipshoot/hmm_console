# Progress Log

## Session: 2026-04-20

### Task: Client-Side Data Storage Modes (Local / Cloud Storage / Cloud API)

**Branch:** `feature/client-side-data`
**Phase:** 1 — Scope & Design Decisions (in_progress)

#### Done
- Planning files initialized (`task_plan.md`, `findings.md`, `progress.md`)
- Confirmed mode model = **three modes** (Local / CloudStorage / CloudApi)
- Captured current state of `lib/core/data/` (untracked scaffolding on branch)
- Identified that gas_log currently uses Hive, not the new SQLite store — migration is non-trivial

#### Environment
- iOS simulator (iPhone 15 Pro Max) running current branch build in background task `buu8ia2r1`
- DevTools at http://127.0.0.1:54154/0PGcHxyxnSM=/devtools/

#### Decisions captured
- Q1: three-mode enum (Local / CloudStorage / CloudApi)
- Q2: scope is all data-backed features (gas_log, message_management, future)
- Q3: CloudStorage v1 provider = OneDrive only (iCloud/Drive/Dropbox deferred)
- Q4: OneDrive layout = per-entity JSON blobs + manifest.json
- Q5: Conflict resolution = LWW via `updated_at` only (no version field, no ETag CAS)
- Q6: gas_log local store = migrate Hive → SQLite
- Q7 (user-initiated): Data model is note-centric — gas_log is a NoteCatalog; planned catalogs include todo, memo, book_note, health_info. Client mirrors backend `/notes` + `/notecatalogs`.
- Q8 (user-initiated): Automobile is a first-class domain with children (gas_log, maintenance, insurance, accident, photos). Modeled as Path C — everything is a note with `parent_note_id` hierarchy + typed Dart views + separate `attachments` table for binaries.

#### Architectural shift
- This task is no longer just "storage modes" — it's the foundation for a generic Note/NoteCatalog model that every feature screen sits on
- Plan has a dedicated Phase 3 for note-centric SQLite schema ahead of the DataMode rework
- Phase 6 migrates gas_log + automobile onto NoteRepository; other catalogs (maintenance, insurance, accident, todo, memo, book_note, health_info) are post-branch

#### Pending user input
- Azure AD app registration — instructions written to `docs/cloud_storage_setup.md` §1; user to register app and provide client ID

#### Artifacts added
- `docs/cloud_storage_setup.md` — full OneDrive (Azure AD / Entra ID) setup walkthrough with platform-specific redirect URIs, plus reference sections for iCloud, Google Drive, and Dropbox for future providers

#### Next
- User review of updated plan. If approved, Phase 1 closes and work begins on Phase 2 (OneDrive prototype) and Phase 3 (schema design) in parallel.

---

## Session: 2026-04-21

### Phase 1 — CLOSED
- Sync contract written: `docs/sync_contract.md`
- All design decisions captured in `docs/findings.md`

### Phase 3 — in progress
Discovered Path C is already ~70% implemented on this branch (LocalNoteRepository + typed repos + DataMode routing).

**Schema v1 → v2 migration shipped:**
- `notes.parent_note_id` (nullable self-FK) + index
- `notes.deleted_at` tombstone timestamp + backfill from old `is_deleted` flag
- Indexes on `notes.last_modified_date`, `notes.catalog_id`, `notes.parent_note_id`
- New `attachments` table (id, noteId, filename, mimeType, size, localPath, remotePath, timestamps, deletedAt) + indexes
- `LocalNoteRepository` updated to use `deletedAt.isNull()` and set tombstone on delete
- Old `isDeleted` column left as vestigial on upgraded DBs (SQLite can't drop columns cheaply); new inserts don't populate it

**Verification:**
- `flutter analyze` — No issues found
- `flutter test` — 289 passed, 0 failed

**Files changed:**
- `lib/core/data/local/database.dart`
- `lib/core/data/local/database.g.dart` (regenerated)
- `lib/core/data/local/local_note_repository.dart`

### Subject-hack cleanup — DONE
- `INoteRepository.getNotesBySubjectPrefix` removed
- `INoteRepository.getNotes` gained optional `catalogId` / `parentNoteId` filters
- `LocalAutomobileRepository.getAutomobiles()` → filters by `catalog_id`; subjects are human-readable (`"2020 Toyota Camry"`)
- `LocalGasLogRepository.getGasLogs(autoId)` → filters by `catalog_id` + `parent_note_id`; creates gas logs with `parent_note_id = autoId`; subject = `"Fill-up 2026-04-21 @ Shell"`
- `LocalGasStationRepository.getGasStations()` → filters by `catalog_id`; subject = station name
- Second `updateNote` call to stuff the real id into the subject is gone

**Verification:** `flutter analyze` clean, 289 tests pass

**Caveat:** existing v1 notes created before this refactor don't have `parent_note_id` populated. If there's real data from beta testing, a one-time backfill (parse old subject prefix → populate parent_note_id) would be needed. Not added — leave for when/if a beta user hits it.

### Next
- `AttachmentRepository` (or wait until sync engine needs it?)
- DataMode enum upgrade 2 → 3 modes (small, isolated change)
- Sync engine scaffolding (Phase 4)

## Session: 2026-04-23

### Bug fixes for multi-device sync — DONE

**Bug 1 — initial-sync re-upload wastefulness.** `SyncOrchestrator.syncNow()` now snapshots local deltas *before* the pull phase (step 0), so on a fresh device install we don't re-upload the thousands of rows we just pulled.

**Bug 2 & 3 — cross-device record identity.** Schema v2→v3 with `notes.uuid` + `attachments.uuid`:
- New `lib/core/util/uuid.dart` — RFC 4122 v4 via `Random.secure()`; no external dep.
- Drift schema: nullable at column level (allows ADD COLUMN during migration) but `clientDefault(generateUuid)` means every fresh insert is populated.
- Unique indexes via `@TableIndex(..., unique: true)`.
- Migration: ADD COLUMN on notes + attachments, per-row UPDATE to backfill a fresh UUID, then CREATE UNIQUE INDEX.

**Sync layer rewrite** (`SyncOrchestrator`):
- `ManifestEntry.id` / `NoteBlob.id` / `AttachmentBlob.id` now carry UUIDs instead of device-local int ids.
- Note body schema changed: dropped `id` / `catalogId` / `parentNoteId` / `authorId`; added `uuid` / `catalogName` / `parentNoteUuid`.
- Catalog resolution: look up by unique `name`, getOrCreate if missing. No catalog sync needed.
- Parent-note resolution: two-pass. Pass 1 inserts/updates with `parentNoteId = null`; pass 2 walks the collected `(childId, parentUuid)` queue and resolves to local ids. If a parent can't be resolved, next sync retries.
- Attachment `noteUuid` resolves to local `noteId` at apply time (attachments are always processed after notes, so parent is present).
- `_collectChangedNotes` batches catalog-name + parent-uuid lookups.
- `_buildManifest` uses UUIDs everywhere; attachments whose parent has no uuid are skipped.
- OneDrive file paths now use UUIDs: `/notes/<uuid>.json`, `/attachments/<uuid><ext>`.

**Verification:** `flutter analyze` clean, 289/289 tests pass.

**Status of 1e:** deferred. The prior OneDrive OAuth round-trip succeeded but was against the pre-UUID sync layer. Once you're ready to smoke-test again, we rebuild and retry.

## Session: 2026-04-22

### Phase 4 steps 1c + 1d — Full sync algorithm — DONE (2026-04-22)

**Provider contract refactored** (`CloudSyncProvider`): dropped the monolithic `sync(SyncRequest)`; replaced with I/O primitives:
- `pullManifest()` / `pushManifest(SyncManifest)`
- `pullNoteBody(id)` / `pushNoteBody(id, body)`
- `pullAttachmentBytes({id, filename})` / `pushAttachmentBytes({id, filename, mimeType, bytes})`

`SyncRequest` value type removed — no longer needed.

**`OneDriveSyncProvider`** now delegates every primitive to `OneDriveGraphClient`.

**`ApiSyncProvider`** stub mirrors the new contract; every primitive throws `UnsupportedError('…not yet implemented')`.

**`SyncMetaRepository`** gained `getOrCreateDeviceId()` (persists a random id to SharedPreferences for manifest telemetry only).

**`SyncOrchestrator.syncNow()`** now implements the full algorithm per `docs/sync_contract.md` §4–§6:
1. Pull remote manifest (404 → empty).
2. For each remote note entry, LWW-check against local and apply body (or tombstone) if remote is newer. Deleted entries land as tombstones without fetching a body.
3. Same for remote attachment entries — pulls bytes, writes to `<appDocs>/attachments/<id><ext>`, upserts row.
4. Collect local notes/attachments where `lastModifiedDate > cursor` and push each. Tombstoned attachments are counted but not uploaded (manifest carries the delete).
5. Rebuild a full manifest from current local state and push it.
6. Advance cursor only if zero errors.

Per-record errors are collected into `SyncResult.errors` so one bad record doesn't abort the rest of the pass.

**Verification:** `flutter analyze` clean, 289/289 tests pass.

**Known gaps:**
- No retry on 401 — user must tap Sync again after re-signing in (refresh handled inside `OneDriveAuth.getAccessToken`, so a typical token expiry self-heals on the next call).
- Attachments >4 MiB are blocked by `OneDriveGraphClient`'s simple-upload guard (resumable upload session deferred per sync contract §10).
- GC (`/attachments/<id><ext>` and manifest tombstone cleanup after 30 days) not implemented.

Next: step **1e** — smoke test the real OAuth flow + end-to-end sync against a live OneDrive account.

### Phase 4 step 1b — OneDrive Graph HTTP client — DONE

New: `lib/core/data/sync/onedrive_graph_client.dart`
- `OneDriveGraphClient(OneDriveAuth, {Dio?})` — Dio instance scoped to `https://graph.microsoft.com/v1.0`
- Request interceptor attaches a fresh bearer via `OneDriveAuth.getAccessToken()`; rejects with a typed `OneDriveGraphException(401)` if the user is not signed in
- `validateStatus: (_) => true` so the client branches on status codes explicitly (vs Dio's default exception-on-non-2xx)
- Endpoints scoped to `/me/drive/special/approot`:
  - `getManifest()` / `putManifest(SyncManifest)` — 404 surfaces as `null` on read
  - `getNoteBlob(id)` / `putNoteBlob(id, body)` / `deleteNoteBlob(id)` (404 tolerated on delete)
  - `getAttachment({id, filename})` / `putAttachment(…)` / `deleteAttachment({id, filename})`
- `putAttachment` guards against the 4 MiB simple-upload cap with a typed exception (resumable upload session deferred — see `docs/sync_contract.md` §10)
- JSON codec for `SyncManifest` + `ManifestEntry` matches the shape in `docs/sync_contract.md` §3.1
- `oneDriveGraphClientProvider` Riverpod provider

**Verification:** `flutter analyze` clean, 289/289 tests pass.

**Still to wire (step 1c):** `OneDriveSyncProvider.sync()` uses the Graph client to push locally-changed notes/attachments, pull manifest entries newer than local, rewrite the manifest, and return a real `SyncResult`.

### Phase 4 step 1a — OneDrive OAuth — DONE

**Dep added:** `flutter_appauth ^12.0.0` (flutter_secure_storage was already a dep).

**Code:**
- `lib/core/data/sync/onedrive_config.dart` — client ID via `--dart-define=ONEDRIVE_CLIENT_ID`, discovery URL (`/common/v2.0/...`), redirect `com.homemademessage.hmm://auth`, scopes (`Files.ReadWrite.AppFolder`, `User.Read`, `offline_access`)
- `lib/core/data/sync/onedrive_auth.dart` — real implementation using `FlutterAppAuth.authorizeAndExchangeCode` + `.token` for refresh. Tokens in `flutter_secure_storage` under keys `onedrive_access_token` / `onedrive_refresh_token` / `onedrive_token_expiry`. `getAccessToken()` auto-refreshes when expiry is within 60 s. `FlutterAppAuthUserCancelledException` → `OneDriveAuthException('Sign-in was cancelled.')`. `FlutterAppAuthPlatformException` on refresh → signs out and returns null.
- New `oneDriveAuthStateProvider` (`FutureProvider<bool>` over `hasToken()`) drives UI button state.
- `OneDriveSyncProvider` exposes `auth` getter (for the upcoming Graph client).
- `settings_screen.dart` — when `CloudStorage` mode is picked: shows OneDrive provider dropdown, then either Sign in / Sign out button (or an error text if `ONEDRIVE_CLIENT_ID` is unset).

**Native wiring:**
- `ios/Runner/Info.plist` — added `CFBundleURLTypes` entry for scheme `com.homemademessage.hmm`.
- `android/app/build.gradle.kts` — added `manifestPlaceholders["appAuthRedirectScheme"] = "com.homemademessage.hmm"` in `defaultConfig`.

**Verification:** `flutter analyze` clean, 289/289 tests pass.

**Known limitations pending steps 1b–1e:**
- "Sync now" button still returns `SyncResult.failed` with the "not yet implemented" message.
- OAuth can't actually succeed at runtime until the user finishes Azure AD app registration and rebuilds with `--dart-define=ONEDRIVE_CLIENT_ID=<id>` (see `docs/cloud_storage_setup.md` §1). Until then the sign-in button surfaces a clear error message.

### AttachmentRepository — DONE (2026-04-21)

- `lib/core/data/local/local_attachment_repository.dart` — `IAttachmentRepository` + `LocalAttachmentRepository`
  - `createAttachment({noteId, filename, mimeType, bytes})`: inserts row first, then writes bytes to `<appDocs>/attachments/<id><ext>`, then stamps `localPath` on the row
  - `getAttachmentById`, `getAttachmentsByNote({includeDeleted})`, `readAttachmentBytes`
  - `deleteAttachment`: soft-delete via `deletedAt` — file stays on disk so tombstones still sync
  - `purgeAttachment`: hard-delete for GC, tolerates missing/locked files
- `repository_providers.dart`: new `attachmentRepositoryProvider` routed through `_useLocal`
- `sync_orchestrator.dart`: `_collectChangedAttachments(cursor)` gathers rows where `lastModifiedDate > cursor` and loads binary bytes from disk (skipped for tombstones)

**Verification:** `flutter analyze` clean, 289/289 tests pass.

### Sync engine skeleton — DONE (2026-04-21)

New files under `lib/core/data/sync/`:
- `sync_models.dart` — value types (`NoteBlob`, `AttachmentBlob`, `ManifestEntry`, `SyncManifest`, `SyncRequest`, `SyncResult`, `SyncError`)
- `cloud_sync_provider.dart` — `CloudSyncProvider` abstract contract
- `sync_meta_repository.dart` — per-provider `lastPushedAt` cursor (SharedPreferences)
- `onedrive_auth.dart` — OAuth stub (real flutter_appauth + flutter_secure_storage lands when we implement)
- `onedrive_sync_provider.dart` — stub; `sync()` returns `SyncResult.failed` with a helpful "not implemented yet" message
- `api_sync_provider.dart` — stub with same pattern
- `sync_orchestrator.dart` — picks the active provider from `DataMode` + `CloudProvider`, collects notes changed since the cursor, calls the provider, advances cursor on success

UI:
- **Sync now** button in Settings (visible only when `mode != Local`)
- Button calls orchestrator, shows in-progress snackbar, then success/failure snackbar with error message

**Current behavior when user taps "Sync now":** orchestrator gathers locally-changed notes, calls provider.sync(), which returns a failed SyncResult with an informative message pointing at the sync contract / cloud-storage setup docs. No state mutation, no crash.

**Verification:** `flutter analyze` clean, 289/289 tests pass.

**Next to wire (post-skeleton):**
- `AttachmentRepository` + orchestrator's `_collectChangedAttachments`
- Apply-pulled-note LWW merge (currently a TODO — was briefly implemented then removed to keep skeleton lean)
- Real Microsoft Graph calls in `OneDriveSyncProvider`
- Real REST calls in `ApiSyncProvider`

### DataMode 2 → 3 modes — DONE (2026-04-21)
- `data_mode.dart`: enum values are now `local` / `cloudStorage` / `cloudApi` (+ `description` getter)
- New `CloudProvider` enum (`onedrive` only for v1) + `cloudProviderProvider` persisting to `cloud_provider` pref key
- Legacy persisted `'api'` automatically upgrades to `DataMode.cloudApi` on load
- `repository_providers.dart`: collapsed per-provider if-chains into a `_useLocal(mode)` helper; `local` and `cloudStorage` both route to SQLite, `cloudApi` routes to API repositories
- `settings_screen.dart`: provider sub-dropdown appears only when `CloudStorage` is selected; mode-specific description text replaces the misleading "cloud-synced folder" helper
- `flutter analyze` clean, 289/289 tests pass

**Note:** `cloudStorage` mode currently routes to local SQLite but has no sync layer yet. Nothing is actually pushed to OneDrive — that lands in Phase 4.
