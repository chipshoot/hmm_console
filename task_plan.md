# Task Plan — Cloud-sync improvements

**Status:** All three phases implemented · A.8 + B.9 + C.10 manual verification pending
**Branches:**
- Phase A: `feat/per-user-onedrive-isolation` (off `main`) — pushed
- Phase B: `feat/auto-sync-controller` (stacked on Phase A) — pushed
- Phase C: `feat/wifi-only-sync` (stacked on Phase B) — pushed
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

- [x] **B.1** New `lib/core/data/sync/sync_controller.dart`: `SyncController extends ChangeNotifier with WidgetsBindingObserver`. Owns periodic `Timer`, foreground-debounce `Timer`, throttle state (`_lastSyncStartedAt`), in-flight flag (read from `_status.isSyncing`).
- [x] **B.2** Both `triggerAutoSync(SyncTriggerReason)` and `triggerManualSync()` implemented. Auto-trigger drops silently when in-flight OR inside the 30-s throttle window; manual bypasses throttle but still respects in-flight (returns null when busy).
- [x] **B.3** `didChangeAppLifecycleState`: `resumed` → 250-ms debounce → trigger + restart periodic; `paused` → cancel periodic + cancel debounce + fire `appBackground` immediately; `inactive`/`detached`/`hidden` ignored (too noisy on iOS).
- [x] **B.4** Periodic timer: `Timer.periodic(10 min)`. Cancelled on `paused` + on `stop()` (which `dispose()` calls).
- [x] **B.5** State held on `SyncController` itself (a `ChangeNotifier`) as `SyncStatus { isSyncing, lastSyncAt, lastResult, lastReason, consecutiveFailures }`. Decided against putting it on `SyncOrchestrator` because the orchestrator is intentionally stateless — `syncNow()` just runs the algorithm.
- [x] **B.6** Wired in `lib/main.dart` — converted `MainApp` from `ConsumerWidget` → `ConsumerStatefulWidget` so we have `initState`/`dispose`. `ref.read(syncControllerProvider).start()` in initState, `.stop()` in dispose.
- [x] **B.7** New `test/core/data/sync/sync_controller_test.dart` — 13 tests. Uses real `TestWidgetsFlutterBinding` + `handleAppLifecycleStateChanged` for lifecycle dispatch, fake clock for throttle, fake action for in-flight coalescing.
- [x] **B.8** New `lib/features/settings/presentation/widgets/sync_status_card.dart` + embedded in Settings screen. Renders "Syncing…" / "Synced N ago" / "Last sync failed" / "Sync failing — last 3 attempts" (persistent badge after 3 fails, per B2 decision). `ListenableBuilder` rebinds on every `notifyListeners()`.
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

- [x] **C.1** Added `connectivity_plus: ^7.1.1` to `pubspec.yaml`
- [x] **C.2** New `lib/features/settings/domain/sync_settings.dart` — `enum SyncNetworkPolicy { wifiOnly, anyNetwork }` + `SyncSettings` value object with `copyWith`/`==`/`hashCode`
- [x] **C.3** New `lib/features/settings/providers/sync_settings_provider.dart` — `Notifier<SyncSettings>` backed by `SharedPreferences`, default `wifiOnly` (decision C2). `_loadFromPrefs` guards on `ref.mounted` after async gap (caught a real production bug — Riverpod 3 throws on disposed-state writes).
- [x] **C.4** `SyncController` gains `CanAutoSyncCheck` typedef + optional constructor parameter. `triggerAutoSync()` calls the gate after the synchronous in-flight/throttle check, sets `lastAutoTriggerSkippedForNetwork=true` when blocked. Production-wires composes `syncSettingsProvider` + `connectivity_plus`. Required a refactor to claim `isSyncing` synchronously (before the gate's `await`) so parallel triggers don't both pass the in-flight check.
- [x] **C.5** Settings UI: `_SyncNetworkPolicySection` with `RadioGroup<SyncNetworkPolicy>` (the post-Flutter-3.32 ancestor pattern — got off deprecated `groupValue`/`onChanged` per-tile API). Hidden when DataMode == local.
- [x] **C.6** `_syncNow` in Settings + the embedded button on `SyncStatusCard` both route through `confirmManualSyncIfOnCellular(context, ref)` helper before bypassing the WiFi-only policy. Manual still bypasses (decision C1) but the user is asked first via AlertDialog.
- [x] **C.7** `SyncStatusCard` adds "Waiting for WiFi to sync" state (with `Icons.wifi_off`) when `status.lastAutoTriggerSkippedForNetwork == true`. State clears on next real sync.
- [x] **C.8** New `test/features/settings/providers/sync_settings_provider_test.dart` — 4 tests (default, persisted-anyNetwork-read, fallback on typo, setNetworkPolicy persistence across containers).
- [x] **C.9** Extended `test/core/data/sync/sync_controller_test.dart` with 5 WiFi-gate tests (skip when false, run when true, success clears flag, manual bypasses, dedup of repeated-skip notifyListeners).
- [ ] **C.10** Manual smoke test on iOS sim + Android emulator: set WiFi-only, disconnect WiFi → confirm auto-sync skips; tap Sync now → confirm cellular dialog appears; confirm → sync proceeds.

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

## Phase D — Sync gaps (post-A/B/C bug reports)

**Owner:** TBD · **Branch:** `fix/sync-push-missing-from-remote` (D.1 only) · **Status:** D.1 in progress, D.2 deferred

User reported on 2026-05-25 that "Sync Now only pushes changed gas logs — the automobile note never makes it to the cloud, and the settings (default units, etc.) are missing entirely." Two distinct bugs sharing one symptom. See `findings.md` for the full diagnosis.

### D.1 — Self-healing push for notes missing from remote manifest

**Bug:** `SyncOrchestrator._collectChangedNotes(cursor)` is a pure filter on `mtime > cursor`. Cursor drift (Phase A migration timing, failed pushes that still advance the cursor, etc.) silently loses local notes — they never get re-pushed.

**Fix:** after pulling the remote manifest, also push any local note whose UUID is NOT in `remote.notes`. Self-healing — picks up anything cursor-skipping left behind.

Tasks:
- [ ] **D.1.1** Refactor `_collectChangedNotes` to accept the pulled `remote` manifest + take the manifest-diff into account, OR keep that method as-is and add a sibling `_collectMissingFromRemote(remote)` that merges into the same push queue
- [ ] **D.1.2** Move the push-collection call to AFTER the manifest pull (so we have the remote set to diff against) — but BEFORE pulling note bodies (so we don't push back what we're about to overwrite via LWW). Verify the existing ordering invariant
- [ ] **D.1.3** Add regression test: setUp DB with a note whose mtime < cursor + an empty remote manifest → assert it gets pushed
- [ ] **D.1.4** Add regression test: same note but remote manifest DOES contain it → assert it does NOT get re-pushed
- [ ] **D.1.5** Add regression test: note with mtime < cursor, remote manifest has it deleted=true, local is alive → don't double-push (LWW still applies); local will get tombstoned on pull instead
- [ ] **D.1.6** Manual smoke test on iOS sim: create automobile, sync, manually delete the `users/{sub}/notes/{auto-uuid}.json` file in OneDrive via Graph Explorer, sync again → automobile should reappear

### D.2 — Settings sync (default units, locale, network policy, etc.) — DEFERRED

**Bug:** settings live in `SharedPreferences`, not in the `notes` table. `SyncOrchestrator` only knows about notes. So no settings ever travel to the cloud. Has been the case since cloudStorage tier shipped.

**Fix shape (when picked up):** serialize a whitelisted set of SharedPreferences keys to a `settings.json` blob, push/pull it as a sibling to `manifest.json` in the user subtree, with explicit conflict-resolution policy.

Tasks (will be expanded when this is picked up):
- [ ] **D.2.1** Decide which settings should sync (default units yes, theme yes, DataMode probably no, vault path definitely no, …)
- [ ] **D.2.2** Add a `SyncableSettings` value object + serializer
- [ ] **D.2.3** Add push/pull leg to orchestrator for settings (separate from notes — different cadence + conflict semantics)
- [ ] **D.2.4** Tests
- [ ] **D.2.5** Manual smoke test

## Scope summary

| Phase | New files | Modified files | Approx LOC (prod + test) | Risk |
|---|---|---|---|---|
| A | 1 | 3 | ~150 + ~150 | medium |
| B | 3 | 3 | ~200 + ~200 | low |
| C | 3 | 4 | ~120 + ~80 | low |
| **Total** | **7** | **10** | **~470 + ~430** | — |

Estimated 2–3 sessions of focused work. Each phase is independently shippable + merge-able to main.
