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
