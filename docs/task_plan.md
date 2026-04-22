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

### Phase 1: Scope & Design Decisions — `in_progress`
- [ ] User confirms mode model (2 vs 3) and initial feature scope
- [ ] Decide conflict resolution policy
- [ ] Pick initial cloud providers for v1 (likely iCloud + API, OneDrive later)
- [ ] Document the sync contract (push / pull / merge semantics)

### Phase 2: OneDrive Research & Azure Setup — `pending`
- [ ] Register app in Azure AD; capture client ID + redirect URIs
- [ ] Verify `flutter_appauth` on iOS/Android/macOS/Windows/Web
- [ ] Prototype OAuth/PKCE flow → token → Graph `/me/drive/special/approot` call
- [ ] Confirm `Files.ReadWrite.AppFolder` scope gives expected sandbox
- [ ] Decide on data layout (per-entity JSON + manifest vs SQLite blob)

### Phase 3: Note-Centric Local Schema (Path C) — `pending`
- [ ] Design SQLite schema:
  - `notes`: `id`, `catalog_id`, `parent_note_id` (nullable, self-FK), `author_id`, `title`, `body`, `payload` (JSON), `created_at`, `updated_at`, `deleted_at`
  - `note_catalogs`: `id`, `name`, `display_name`, `parent_catalog_id` (nullable, for automobile → gas_log/maintenance/… hierarchy)
  - `authors`: `id`, `display_name`, `email`
  - `tags`: `id`, `name`
  - `note_tags`: `note_id`, `tag_id` (composite PK)
  - `attachments`: `id`, `note_id`, `filename`, `mime_type`, `size`, `local_path`, `remote_path`, `created_at`, `updated_at`, `deleted_at`
  - Indexes: `notes(updated_at)`, `notes(catalog_id, deleted_at)`, `notes(parent_note_id)`, `attachments(note_id)`, `attachments(updated_at)`
- [ ] Migrations: initial schema + seed rows in `note_catalogs` (`automobile`, `gas_log` with parent=automobile)
- [ ] Hive → SQLite migration: one-shot on first launch reading existing Hive boxes
  - Automobiles → notes with `catalog='automobile'`
  - Gas logs → notes with `catalog='gas_log'`, `parent_note_id=<automobile note id>`
- [ ] `NoteRepository` (generic CRUD + `watchByCatalog`, `watchByParent`)
- [ ] `AttachmentRepository` (CRUD + binary file handling)
- [ ] Codec layer: per-catalog Dart encoders/decoders (`Automobile ↔ Note`, `GasLog ↔ Note`)
- [ ] Typed repositories (`AutomobileRepository`, `GasLogRepository`) delegating to `NoteRepository`

### Phase 3b: Redesign DataMode Model — `pending`
- [ ] Update `lib/core/data/data_mode.dart` to three-mode enum + optional provider
- [ ] Persist selection + provider choice via SharedPreferences
- [ ] Update `dataModeProvider` consumers

### Phase 4: Sync Engine Abstraction — `pending`
- [ ] Define `CloudSyncProvider` interface (push note, push attachment, pull manifest, pull blob, LWW merge)
- [ ] Implement `ApiSyncProvider` (maps notes → `/notes` + `/notecatalogs` + `/tags` REST endpoints; attachments via API upload)
- [ ] Implement `OneDriveSyncProvider` (Graph REST + AppFolder)
  - Notes: `/notes/<id>.json`
  - Attachments: `/attachments/<id>.<ext>`
  - Index: `/manifest.json` (notes + attachments with `updated_at` / `deleted`)
- [ ] Sync trigger points (app start, on write, manual button, optional periodic)
- [ ] LWW resolution: compare `updated_at` per note / attachment

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
