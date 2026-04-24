# Task Plan: Client-Side Data Storage Modes + Note-Centric Data Model

**Branch:** `feature/client-side-data`
**Started:** 2026-04-20
**Status:** planning

## Goal

Two intertwined changes:

**1. Note-centric local data model (Path C — unified notes + typed Dart views)**
Restructure local storage around the backend's note model: `notes` + `note_catalogs` + `authors` + `tags` + `attachments`. Every feature — gas_log today; automobile hub, maintenance, insurance, accident, todo, memo, book_note, health_info tomorrow — is a filtered view over `notes` discriminated by `catalog_id` and/or `parent_note_id`. Type-specific fields live in `notes.payload` JSON. Typed Dart entities (`Automobile`, `GasLog`, `MaintenanceRecord`, …) encode/decode from `Note`.

**2. Three storage modes with pluggable sync**
Redesign `DataMode { local, api }` → `{ Local, CloudStorage, CloudApi }`:
- **Local only** — data stays on device (SQLite); no sync
- **Cloud storage** — local-first + sync to user's personal cloud (OneDrive v1; iCloud/Drive/Dropbox later)
- **Cloud (API)** — local-first + sync to Hmm backend API (`api.homemademessage.com`)

All modes read/write the same local SQLite store. Cloud modes layer a sync engine on top. Users select mode (and provider) in Settings.

## Non-goals

- Real-time collaborative editing / multi-device live sync
- Per-feature mode (mode is app-wide)
- Migration UI for moving data *between* different cloud providers (initial version: switching provider wipes remote and re-uploads)

## Confirmed Scope

- **Mode model:** three modes — `Local` / `CloudStorage` / `CloudApi`
- **Feature scope:** all data-backed features (gas_log, message_management, future notes/tags)
- **CloudStorage providers v1:** OneDrive only (iCloud/Drive/Dropbox deferred)
- **OneDrive data layout:** per-note JSON blobs under `/notes/<id>.json` + `/manifest.json` index (type inside blob via `catalog_id`)
- **Conflict resolution:** LWW via `updated_at` only (no version, no ETag CAS)
- **gas_log local store:** migrate Hive → SQLite (one-time migration on first launch)
- **Data model:** Path C — unified notes + typed Dart views
  - Schema: `notes` (with `parent_note_id`, `payload` JSON) + `note_catalogs` + `authors` + `tags` + `note_tags` + `attachments`
  - Typed Dart entities sit on top: `Automobile`, `GasLog`, `MaintenanceRecord`, `InsurancePolicy`, `Accident`, etc.
- **Catalogs in this branch:**
  - Infrastructure for all catalogs
  - Seed catalogs: `automobile`, `gas_log` (migrated from Hive)
  - Rest (maintenance, insurance, accident, todo, memo, book_note, health_info) added in follow-up branches — the infra makes each cheap

## Open Questions (see findings.md)

1. Azure AD app registration — user to follow `docs/cloud_storage_setup.md` §1 and share client ID
2. Per-catalog extension tables — wait until a specific catalog proves it needs relational indexes beyond the JSON payload?

## Phases

### Phase 1: Scope & Design Decisions — `complete`
- [x] Mode model = three modes (Local / CloudStorage / CloudApi)
- [x] Feature scope = all data-backed features
- [x] CloudStorage provider v1 = OneDrive only
- [x] OneDrive layout = per-entity JSON + manifest
- [x] Conflict resolution = LWW via `updated_at`
- [x] gas_log local store = migrate Hive → SQLite (de facto already done on branch)
- [x] Data model = Path C (unified notes + typed Dart views)
- [x] Sync contract documented (`docs/sync_contract.md`)

### Phase 2: OneDrive Research & Azure Setup — `pending`
- [ ] Register app in Azure AD; capture client ID + redirect URIs
- [ ] Verify `flutter_appauth` on iOS/Android/macOS/Windows/Web
- [ ] Prototype OAuth/PKCE flow → token → Graph `/me/drive/special/approot` call
- [ ] Confirm `Files.ReadWrite.AppFolder` scope gives expected sandbox
- [ ] Decide on data layout (per-entity JSON + manifest vs SQLite blob)

### Phase 3: Note-Centric Local Schema (Path C) — `in_progress`

**Already in place on the branch before this session:**
- [x] SQLite schema (Drift): `Authors`, `NoteCatalogs`, `Notes`, `Tags`, `NoteTagRefs`
- [x] `LocalNoteRepository` (generic CRUD)
- [x] Typed local repos (`LocalAutomobileRepository`, `LocalGasLogRepository`, `LocalGasStationRepository`, `LocalAuthorRepository`, `LocalNoteCatalogRepository`, `LocalTagRepository`) encoding/decoding via `notes.content` JSON
- [x] DataMode-based routing in `repository_providers.dart`

**Completed this session (schemaVersion 1 → 2 migration):**
- [x] Added `notes.parent_note_id` (nullable self-FK) + index
- [x] Added `notes.deleted_at` (datetime tombstone) + migration backfill from old `is_deleted` flag
- [x] Added indexes on `notes.last_modified_date`, `notes.catalog_id`, `notes.parent_note_id`
- [x] New `attachments` table with indexes on `note_id` and `last_modified_date`
- [x] `LocalNoteRepository` updated: `deletedAt.isNull()` filters + tombstone on delete
- [x] Drift codegen regenerated, `flutter analyze` clean, all 289 tests pass

**Still pending:**
- [x] `AttachmentRepository` (CRUD + binary file handling) — done 2026-04-21
- [x] Replace subject-hack with clean `catalog_id` + `parent_note_id` queries (done 2026-04-21)
- [ ] Hive legacy cleanup — verify no remaining Hive usage, remove dead code if any
- [ ] Seed `automobile` and `gas_log` rows in `note_catalogs` at startup (if not already)
- [ ] One-time migration of existing v1 note rows: populate `parent_note_id` from old subject `"GasLog,AutomobileId:N"` pattern (optional — only needed if beta users have pre-refactor data)

### Phase 3b: Redesign DataMode Model — `complete`
- [x] Three-mode enum (`local`, `cloudStorage`, `cloudApi`) with `displayName` + `description`
- [x] New `CloudProvider` enum (`onedrive`) with persistence via `cloudProviderProvider`
- [x] `DataModeNotifier` preserves legacy `'api'` persisted value (maps → `cloudApi`)
- [x] `repository_providers.dart` routes `local` + `cloudStorage` to SQLite, `cloudApi` to API repos (via `_useLocal` helper)
- [x] Settings screen shows provider sub-picker when CloudStorage is selected; per-mode description text
- [x] `flutter analyze` clean, 289 tests pass

### Phase 4: Sync Engine Abstraction — `in_progress`
- [x] `CloudSyncProvider` interface (`lib/core/data/sync/cloud_sync_provider.dart`)
- [x] Shared value types: `NoteBlob`, `AttachmentBlob`, `ManifestEntry`, `SyncManifest`, `SyncRequest`, `SyncResult`, `SyncError` (`sync_models.dart`)
- [x] `SyncMetaRepository` — per-provider `lastPushedAt` cursor in SharedPreferences
- [x] `OneDriveAuth` real implementation (flutter_appauth 12 + flutter_secure_storage, auto-refresh)
- [x] `OneDriveConfig` — client ID via `--dart-define=ONEDRIVE_CLIENT_ID`, discovery URL, redirect URI, scopes
- [x] iOS Info.plist + Android build.gradle.kts native wiring for `com.homemademessage.hmm://auth` scheme
- [x] Settings: Sign in / Sign out of OneDrive buttons (with configured-check), auth state via `oneDriveAuthStateProvider`
- [x] `OneDriveSyncProvider` stub — returns a typed `SyncResult.failed` until Graph wiring lands
- [x] `ApiSyncProvider` stub — returns `SyncResult.failed` until REST wiring lands
- [x] `SyncOrchestrator` — selects provider from DataMode + CloudProvider, collects changed notes via `lastModifiedDate > cursor`, advances cursor on success
- [x] "Sync now" button wired in Settings (visible only when `mode != Local`)
- [x] Attachment collection in orchestrator (`_collectChangedAttachments` reads row + binary bytes from disk, skips tombstones)
- [x] **1b** OneDrive Graph HTTP client (`OneDriveGraphClient`): bearer interceptor, manifest get/put, note blob get/put/delete, attachment get/put/delete with 4 MiB guard rail
- [x] **1c+1d** Full sync algorithm in `SyncOrchestrator` — pull manifest → LWW-apply newer remote notes/attachments → push local changes since cursor → rewrite and push manifest → advance cursor only on clean run. Provider contract refactored to I/O primitives only (pullManifest/pushManifest/pullNoteBody/pushNoteBody/pullAttachmentBytes/pushAttachmentBytes).
- [x] **Bug 1 fix (initial-sync re-upload):** moved local-delta collection before the pull phase so fresh-device onboarding doesn't push what it just pulled.
- [x] **Bug 2/3 fix (cross-device identity):** schema v2→v3 adds `notes.uuid` + `attachments.uuid` (RFC 4122 v4 via `lib/core/util/uuid.dart`, `clientDefault`). Sync layer uses uuids as identity, `catalogName` for catalog resolution, `parentNoteUuid` with a two-pass resolution for parent-note references, and `noteUuid` for attachment parent resolution.
- [ ] **1e** Real smoke test against a OneDrive account (revisit after bug-fix branch lands)
- [ ] Real API implementation (maps to `/notes` + `/notecatalogs` + `/tags` REST endpoints)
- [ ] Optional sync triggers (app resume, on write, periodic timer)

### Phase 5: Settings UI — `pending`
- [ ] Update `settings_screen.dart` with mode picker + provider picker
- [ ] Show sync status (last sync time, pending changes, errors)
- [ ] Manual "Sync now" action

### Phase 6: Migrate Existing Features onto Note Model — `pending`
- [ ] gas_log: rewrite repository as `GasLogRepository` delegating to `NoteRepository` (filter `catalog_id='gas_log'`)
- [ ] gas_log: update tests in `test/features/gas_log/`
- [ ] automobile: rewrite repository as `AutomobileRepository` delegating to `NoteRepository` (filter `catalog_id='automobile'`)
- [ ] message_management: **out of scope this branch** — leave in-memory mock; convert when we implement `memo` catalog later
- [ ] dashboard: verify across all three modes
- [ ] New catalogs (maintenance, insurance, accident, todo, memo, book_note, health_info): **not implemented in this branch** — only the infra that makes them cheap to add next

### Phase 7: Testing & Verification — `pending`
- [ ] Unit tests for sync engine
- [ ] Integration test: switch modes, verify data persistence
- [ ] Manual: iOS simulator iCloud sandbox test
- [ ] Manual: API mode against production backend

### Phase 8: Docs — `pending`
- [ ] Update `docs/SYSTEM_DESIGN.md`
- [ ] Update `CLAUDE.md` architecture section
- [ ] Update README if user-facing

## Decisions

| Date | Decision | Reason |
|------|----------|--------|
| 2026-04-20 | Keep SQLite as the always-on local cache | Existing infra in `lib/core/data/local/`, offline-first is the whole point |

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|

## Files (expected)

- Modified: `lib/core/data/data_mode.dart` (three-mode enum + provider)
- New: `lib/core/data/notes/note.dart` (base domain entity)
- New: `lib/core/data/notes/note_catalog.dart`
- New: `lib/core/data/notes/note_repository.dart` (generic)
- New: `lib/core/data/notes/attachment.dart`
- New: `lib/core/data/notes/attachment_repository.dart`
- New: `lib/core/data/local/schema.dart` (SQLite schema + migrations)
- New: `lib/core/data/local/hive_migration.dart` (one-shot Hive → SQLite for gas_log + automobile)
- New: `lib/core/data/sync/sync_provider.dart` (interface)
- New: `lib/core/data/sync/api_sync_provider.dart`
- New: `lib/core/data/sync/onedrive_sync_provider.dart`
- New: `lib/core/data/sync/onedrive_auth.dart` (flutter_appauth wrapper)
- Modified: `lib/features/settings/presentation/screens/settings_screen.dart`
- Modified: `lib/features/gas_log/domain/entities/automobile.dart` (add Note codec)
- Modified: `lib/features/gas_log/domain/entities/gas_log.dart` (add Note codec)
- Modified: `lib/features/gas_log/data/providers/gas_log_providers.dart` (note-backed)
- Modified: `lib/features/gas_log/data/repositories/*` (delegate to NoteRepository)
- Modified: `lib/features/gas_log/usecases/*.dart` (adapt)
- Modified: `pubspec.yaml` (new deps: flutter_appauth, flutter_secure_storage, sqlite tooling if not already present)
