# Task Plan — Cloud-sync improvements

**Status:** Phase A in progress · all 8 decisions locked in (user accepted recommendations 2026-05-24)
**Branches:** Phase A on `feat/per-user-onedrive-isolation` (off `main`)
**Last update:** 2026-05-24

## Goal

Three improvements to the cloudStorage (OneDrive) sync tier of `hmm_console`:

1. **Auto-sync** — fire `syncOrchestrator.syncNow()` on app lifecycle transitions (foreground + background) plus a periodic 10-minute safety net while the app is in the foreground. Today the only trigger is the manual "Sync Now" button in Settings.
2. **WiFi-only toggle** — let the user choose "WiFi only" vs "Any network" for auto-sync, defaulting to WiFi only (saves cellular data, matches OneDrive desktop client's default).
3. **Per-user OneDrive isolation** — today every Hmm user signed into the same Microsoft account writes to the same `approot/notes/{id}.json` path; their notes collide. Namespace by the Hmm IDP `sub` claim so each user gets `approot/users/{sub}/...`.

## Phasing rationale

A → B → C, in that order:

- **A (per-user isolation)** is a data-path change. Must land first so B and C build on the right OneDrive structure — otherwise we'd ship auto-sync that writes to the colliding path and have to migrate again.
- **B (auto-sync)** is the foundation for C.
- **C (WiFi-only)** gates B. The setting only matters when there are auto-fires to gate (manual Sync Now can stay always-on or respect the toggle — open decision C1).

## Decisions (locked 2026-05-24)

| # | Decision | Resolution |
|---|---|---|
| A1 | What if IDP `sub` claim is missing? | ✅ Block sync with clear error |
| A2 | Migration strategy for existing single-user OneDrive data | ✅ Copy into `users/{sub}/`, leave originals + marker file |
| B1 | Auto-sync minimum gap (throttle) | ✅ 30 s |
| B2 | Auto-sync failure UX | ✅ Silent + snackbar; persistent badge after 3 consecutive fails |
| B3 | Sync on edit-screen exit? | ✅ No — lifecycle + periodic only |
| C1 | Manual Sync Now respects WiFi-only? | ✅ Bypass with confirm dialog on cellular |
| C2 | Default network policy | ✅ WiFi only |
| C3 | Show "N MB pending upload" estimate | ✅ Out of scope for v1 |

## Phase A — Per-user OneDrive isolation

**Owner:** TBD · **Branch:** TBD · **Status:** pending decisions

### Tasks

- [x] **A.1** Inject `CurrentUserSubResolver` typedef (`Future<String?> Function()`) into `OneDriveGraphClient` constructor
- [x] **A.2** Replace static `_approot` with `_userPath(relative, {action})` builder; throws `OneDriveGraphException(401)` if resolver returns null/empty; URL-encodes the sub
- [x] **A.3** Wire resolver in `onedrive_sync_provider.dart` (via `IdpTokenService.getStoredClaims()['sub']`) + new `oneDriveGraphClientProvider` reads from the IDP token service
- [x] **A.4** No existing graph-client tests to update
- [x] **A.5** New `test/core/data/sync/onedrive_graph_client_path_test.dart` — 11 tests covering user-scoped paths (GET/PUT/DELETE), URL encoding of special characters in sub, missing-sub → 401, empty-string sub, legacy unscoped paths still readable for migration, marker present/absent + write
- [x] **A.6** Migration logic in `OneDriveSyncProvider.migrateLegacyIfNeeded()` (called from `SyncOrchestrator.syncNow()` via `is OneDriveSyncProvider` cast — doesn't pollute the abstract interface). Single global marker at `approot/users/.legacy_migrated.json`. Preserves existing per-user manifest. Migration failure logged as a SyncError but doesn't abort the sync.
- [x] **A.7** New `test/core/data/sync/onedrive_migration_test.dart` — 5 tests covering marker-present (skip), no-user (skip without marking), no-legacy-data (mark + return 0), full copy with deleted-entry skipping, preserve-existing-per-user-manifest tripwire
- [ ] **A.8** Manual end-to-end verification: sign in two Hmm users on one device sharing one Microsoft account, sync each, inspect OneDrive AppFolder via Graph Explorer to confirm separate subtrees

### Files touched

| File | Action |
|---|---|
| `lib/core/data/sync/onedrive_graph_client.dart` | modify |
| `lib/core/data/sync/onedrive_sync_provider.dart` | modify |
| `lib/core/data/sync/sync_orchestrator.dart` | modify (add migration call once) |
| `test/core/data/sync/onedrive_graph_client_path_test.dart` | new |
| `test/core/data/sync/onedrive_sync_provider_test.dart` | modify if exists |

### Risk

**Medium** — touches the live data path. Migration must be idempotent + rollback-safe. Recommend a `--dry-run` mode at the CLI level for the marker logic before first release.

## Phase B — Auto-sync controller

**Owner:** TBD · **Branch:** TBD · **Status:** blocked by A

### Tasks

- [ ] **B.1** New `lib/core/data/sync/sync_controller.dart`: `SyncController extends WidgetsBindingObserver`. Owns periodic `Timer`, throttle state (`_lastSyncStartedAt`), in-flight flag (`_isSyncing`).
- [ ] **B.2** Expose `triggerAutoSync(SyncTriggerReason reason)` — drops trigger silently if `_isSyncing || (now - _lastSyncStartedAt < throttleWindow)`.
- [ ] **B.3** `didChangeAppLifecycleState`: on `resumed` → 250 ms debounce → trigger; on `paused` → trigger immediately. Cancel periodic timer on `paused`, reschedule on `resumed`.
- [ ] **B.4** Periodic timer: every 10 min while app is in `resumed`. Cancel on `paused` + on logout.
- [ ] **B.5** Add `lastSyncAt`, `lastSyncError`, `isSyncing` getters to `SyncOrchestrator` (or a sibling state holder).
- [ ] **B.6** Register `SyncController` as a binding observer in `main.dart` *after* auth resolves.
- [ ] **B.7** New `test/core/data/sync/sync_controller_test.dart`: fake clock + fake orchestrator. Cases: foreground fires, background fires, periodic fires every 10 min, throttle prevents double-fire, coalescing drops trigger when busy, periodic cancelled on background.
- [ ] **B.8** New `lib/features/settings/presentation/widgets/sync_status_card.dart`: displays sync state (syncing… / last synced N ago / failed with retry). Wires to the orchestrator getters.
- [ ] **B.9** Manual smoke test on iOS sim + Android emulator: background → foreground → confirm sync fires; wait 10 min → confirm periodic fires.

### Files touched

| File | Action |
|---|---|
| `lib/core/data/sync/sync_controller.dart` | new |
| `lib/core/data/sync/sync_orchestrator.dart` | modify (add state getters) |
| `lib/main.dart` (or root widget) | modify (observer registration) |
| `lib/features/settings/presentation/widgets/sync_status_card.dart` | new |
| `lib/features/settings/presentation/screens/settings_screen.dart` | modify (embed sync status card) |
| `test/core/data/sync/sync_controller_test.dart` | new |

### Risk

**Low** — pure scheduling, no data-shape change. Main edge cases: iOS lifecycle bounce on phone calls, race with cold-start auth resolution.

## Phase C — WiFi-only toggle

**Owner:** TBD · **Branch:** TBD · **Status:** blocked by B

### Tasks

- [ ] **C.1** Add `connectivity_plus` dependency to `pubspec.yaml`
- [ ] **C.2** New `lib/features/settings/domain/sync_settings.dart`: `enum SyncNetworkPolicy { wifiOnly, anyNetwork }` + `SyncSettings` value object
- [ ] **C.3** New `lib/features/settings/providers/sync_settings_provider.dart`: Notifier-backed by `shared_preferences`, default `wifiOnly`
- [ ] **C.4** `SyncController.triggerAutoSync()`: query `connectivity_plus`, skip with logged `SyncResult.skipped('WiFi-only, current: cellular')` when policy blocks
- [ ] **C.5** Settings UI: radio group "Sync over: WiFi only / Any network" in Settings screen
- [ ] **C.6** `_syncNow` (manual): if WiFi-only is on AND on cellular, show confirm dialog ("Sync over cellular?"); if confirmed, bypass policy
- [ ] **C.7** `SyncStatusCard` shows "Waiting for WiFi" state when last auto-sync was skipped for that reason
- [ ] **C.8** New `test/features/settings/providers/sync_settings_provider_test.dart`
- [ ] **C.9** Modify `test/core/data/sync/sync_controller_test.dart`: fake connectivity, assert WiFi-only blocks auto-sync on cellular

### Files touched

| File | Action |
|---|---|
| `pubspec.yaml` | modify (add connectivity_plus + crypto NOT needed, already there) |
| `lib/features/settings/domain/sync_settings.dart` | new |
| `lib/features/settings/providers/sync_settings_provider.dart` | new |
| `lib/core/data/sync/sync_controller.dart` | modify (connectivity gate) |
| `lib/features/settings/presentation/screens/settings_screen.dart` | modify (radio group, confirm dialog) |
| `lib/features/settings/presentation/widgets/sync_status_card.dart` | modify (WiFi-waiting state) |
| `test/features/settings/providers/sync_settings_provider_test.dart` | new |
| `test/core/data/sync/sync_controller_test.dart` | modify |

### Risk

**Low** — bolted on after auto-sync exists. Only edge case: connectivity_plus's behavior on iOS simulator (may always report WiFi) — handle in tests via the connectivity fake.

## Scope summary

| Phase | New files | Modified files | Approx LOC (prod + test) | Risk |
|---|---|---|---|---|
| A | 1 | 3 | ~150 + ~150 | medium |
| B | 3 | 3 | ~200 + ~200 | low |
| C | 3 | 4 | ~120 + ~80 | low |
| **Total** | **7** | **10** | **~470 + ~430** | — |

Estimated 2–3 sessions of focused work. Each phase is independently shippable + merge-able to main.
