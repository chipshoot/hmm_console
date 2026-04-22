# Findings: Client-Side Data Storage Modes

## Architectural North Star (2026-04-20)

**Everything is a note. Typed Dart entities are views over Note.payload. (Path C)**

Backend already models this (see `docs/SYSTEM_DESIGN.md`):
- `/notes` — base entity (title, body, author, tags, timestamps, metadata)
- `/notecatalogs` — templates that define a note *type* / schema
- `/authors` — user profiles
- `/tags` — cross-cutting categorization

Client mirrors it: one `notes` table + `note_catalogs` + `authors` + `tags` + `note_tags` + `attachments`. Type-specific fields live in `notes.payload` (JSON). Parent/child hierarchy via `notes.parent_note_id` (self-referential FK). Binary files (photos, etc.) in `attachments`, referenced by `note_id` and synced as separate blobs.

**Catalogs planned:**

*Personal:*
- todo
- memo
- book_note
- health_info

*Automobile (parent):*
- automobile

*Automobile children* (all have `parent_note_id` → an automobile note):
- gas_log
- maintenance
- insurance
- accident

Additional automobile-related data (outside photos, documents) attaches to the appropriate note (automobile itself, or a specific accident, etc.) via `attachments`.

**Typed Dart domain stays intact.** `Automobile`, `GasLog`, `MaintenanceRecord`, etc. are real Dart classes that encode/decode from `Note`:
```
Automobile <-> Note (catalog='automobile', payload={make, model, VIN, ...})
GasLog     <-> Note (catalog='gas_log', parent_note_id=auto.id, payload={odometer, price, ...})
```

Repositories expose typed APIs (`AutomobileRepository.getAll()`) internally backed by the generic `NoteRepository`.

**Implications for this feature:**
- Local SQLite schema is catalog-agnostic from day one — gas_log is just one catalog among many
- OneDrive layout: `/notes/<id>.json` + `/attachments/<id>.<ext>` (type inside each blob via `catalog_id`)
- Sync engine operates on notes + attachments — one pass covers every catalog
- Each UI feature (gas_log screen, automobile hub, todo list) = filtered view over `notes` by `catalog_id` and/or `parent_note_id`
- Adding a new catalog post-branch (todo, memo, etc.) = seed a `note_catalogs` row + write a typed Dart view + a UI screen. No schema migration, no new sync code.

## Confirmed Decisions

- **2026-04-20**: Mode model = **three modes** (Q1 = Option A)
  - `Local` / `CloudStorage` / `CloudApi`
  - Under the hood, `CloudStorage` still needs a provider sub-selection (iCloud vs OneDrive vs …). That picker appears only when the user selects CloudStorage — keeping the top-level model simple while letting provider expand without breaking the enum.
- **2026-04-20**: Feature scope = **all data-backed features** (Q2 = Option 2)
  - gas_log (Hive → migrate or wrap), message_management (in-memory mock → real local store), plus any new feature added on this branch
  - Implication: gas_log's Hive layer needs a decision — either migrate to the new SQLite store, or keep Hive and build the sync engine on top of a feature-agnostic repository interface
- **2026-04-20**: CloudStorage providers for v1 = **OneDrive only** (Q from Phase 1 = Option C)
  - Cross-platform from day one (iOS/Android/macOS/Windows/Web)
  - No first-party Flutter SDK — use `flutter_appauth` (OAuth/PKCE) + raw Microsoft Graph REST
  - Tokens stored in `flutter_secure_storage`
  - iCloud, Google Drive, Dropbox deferred to v2+
- **2026-04-20**: OneDrive data layout = **per-entity JSON blobs + manifest** (option A)
  - Path layout under app folder: `/{entityType}/{id}.json` (e.g. `/gas_logs/<id>.json`, `/automobiles/<id>.json`)
  - Single `/manifest.json` at root with `{ entityType, id, updated_at, deleted }` entries for fast diff/pull
  - Enables multi-device delta sync: device pulls manifest, compares `updated_at`, fetches only changed blobs
  - Tombstones via `deleted: true` + `updated_at` in manifest (don't hard-delete until GC)
- **2026-04-20**: Conflict resolution = **LWW via `updated_at` only**
  - No version field, no ETag CAS in v1
  - Every syncable entity carries `updated_at` + `deleted_at` (tombstones)
  - On sync, whichever side has the larger `updated_at` wins
  - Accept the trade-off: concurrent offline edits on two devices can silently lose one side's change. Low risk for single-user gas-log/messages usage.
- **2026-04-20**: gas_log local store = **migrate Hive → SQLite** (Q6 = Option b)
  - SQLite required for efficient `WHERE updated_at > ?` sync queries and relational lookups
  - One-time migration on first app launch post-upgrade: read Hive boxes → write rows into SQLite → mark Hive as migrated
- **2026-04-20**: Data model = **note-centric with typed Dart views** (Path C)
  - All feature data stored in one `notes` table discriminated by `catalog_id`
  - Hierarchy via `parent_note_id` (e.g. gas_log → automobile)
  - Type-specific fields in `notes.payload` JSON; no per-catalog extension tables yet (add only when proven needed)
  - Typed Dart entities (`Automobile`, `GasLog`, `MaintenanceRecord`, …) sit on top, encoding/decoding from `Note`
  - Binary attachments (photos, docs) in a separate `attachments` table; synced as standalone blobs
  - Sync engine is catalog-agnostic

## Open Questions (need user answers)

### Q3: OneDrive auth
- `flutter_appauth` for OAuth 2.0 + PKCE against Microsoft identity platform (`login.microsoftonline.com/common`)
- Register app in Azure AD → get client ID + redirect URI
- Scopes: `Files.ReadWrite.AppFolder`, `offline_access`, `User.Read`
- Store access + refresh token in `flutter_secure_storage`
- Redirect URI: custom scheme like `msauth.com.homemademessage.hmm://auth` (iOS/Android) or `http://localhost` (web/desktop)

## Existing Code (2026-04-20 snapshot)

### `lib/core/data/data_mode.dart`
- Current enum: `DataMode { local, api }` with `displayName`
- `DataModeNotifier` persists to SharedPreferences under key `data_mode`
- `databasePathProvider` reads `local_db_path` pref, else defaults to `<appDocDir>/hmm.db`
- `updateDatabasePath` delegates to `setDatabasePath` in `local/database.dart`

### `lib/core/data/` (untracked — new on this branch)
- `data_mode.dart`
- `local/` (SQLite setup)
- `repository_providers.dart`
- `result.dart`

### Existing features and their storage
| Feature | Current store | DI |
|---------|---------------|-----|
| auth | Firebase + IDP tokens | Riverpod |
| gas_log | Hive (offline-first) | GetIt |
| message_management | in-memory mock | GetIt |
| dashboard | composite | mixed |

Per `CLAUDE.md`, new features should prefer Riverpod. Gas_log is still on GetIt + Hive — any migration is non-trivial.

### Settings screen
- `lib/features/settings/presentation/screens/settings_screen.dart` modified on this branch (+115 lines). Need to read to see current DataMode UI before designing changes.

### Pubspec changes so far
- `pubspec.yaml` has ~6 new lines (likely `sqflite`/`path_provider`/similar — confirm)
- `pubspec.lock` updated significantly

## Discoveries (log each as you find them)

### 2026-04-20
- Branch already introduces `DataMode`, SQLite DB scaffolding, and `result.dart` (likely Result/Either) — foundation for a unified repository layer
- No sync engine yet

## References

- Microsoft Graph OneDrive API: https://learn.microsoft.com/en-us/onedrive/developer/rest-api/
- Apple CloudKit: https://developer.apple.com/documentation/cloudkit
- pub.dev icloud_storage: https://pub.dev/packages/icloud_storage (community)
