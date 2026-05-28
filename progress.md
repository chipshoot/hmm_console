# Progress log — Cloud-sync improvements

Newest entries at the top.

## 2026-05-27 — Phase E: post-sign-in onboarding flow

- Branch `feat/onboarding-flow` off main.
- Triggered by user feedback after D.1+D.2 merged: "If user is in cloud tier, when he uses second device to login, we should force him to login to cloud and sync data" — to avoid a second device building up a local-only data silo that creates semantic duplicates on a later tier switch.
- Pushed back gently on the word "force" — we have no reliable server-side signal that a Hmm user "uses cloud tier" (no JWT claim, no IDP column). Implementing true force needs IDP work (Option B). Instead landed Option A: an onboarding screen that asks once, defaults the user toward the right configuration based on their answer.
- Implementation:
  - `OnboardingCompletedNotifier` (`Notifier<bool>`) backed by `SharedPreferences` key `onboarding_completed`. Per-install (NOT synced — syncing it would re-show on every device, defeating the point).
  - `OnboardingScreen` (`lib/features/onboarding/presentation/screens/onboarding_screen.dart`) — two-choice RadioGroup (New to Hmm / I already use Hmm on another device), Continue button. Migrating branch runs the full guided setup: setMode(cloudStorage) → OneDriveAuth.signIn() → SyncController.triggerManualSync() → markCompleted() → context.go('/'). New-user branch just markCompleted() → '/'. Error path on the migrating branch shows the message + a "Skip for now" escape so the user is never stranded.
  - Router (`router_config.dart`) gains a third redirect condition: authenticated + !onboardingDone + !onOnboardingPath → /onboarding. Conversely, authenticated + onboardingDone + onPath → / (one-shot, prevents loop / deep-link re-entry).
- 4 new tests in `test/features/onboarding/providers/onboarding_provider_test.dart`. Full suite **553 / 553** (+4 from this branch, no regressions). Lint clean.
- **E.6 (manual smoke test) is the only remaining task.** Need to install a fresh build on iOS sim, watch the onboarding screen render after sign-up, click through both branches, and verify the redirect doesn't re-fire after completion.

## 2026-05-26 — Phase D.2: settings sync (default units, locale, network policy)

- Branch `feat/settings-sync` off main.
- Closes the second half of the user bug report from 2026-05-25 ("settings don't sync").
- Architecture:
  - `SyncableSettings` value object (`lib/features/settings/domain/syncable_settings.dart`) aggregates gas-log units + currency + showRegistration, sync network policy, UI locale, and a `lastModified` stamp. JSON-roundtrippable.
  - `SyncableSettingsRepository` (`lib/features/settings/data/syncable_settings_repository.dart`) reads/writes the bundle against the SAME SharedPreferences keys the per-feature notifiers already own (`gas_log_settings`, `sync.network_policy`, `app_locale`), plus a new `settings.last_modified` key that every setter bumps.
  - `SettingsBus` (`lib/features/settings/providers/settings_bus_provider.dart`) — counter-style notifier the orchestrator bumps after a remote pull-apply. Per-feature notifiers `ref.watch` it in `build()`, so a pulled bundle propagates into in-memory state without an app restart.
- `CloudSyncProvider` interface gained `pullSettings()` / `pushSettings(body)`. OneDrive impl routes through the existing graph client (new `getSettings` / `putSettings` methods, target `users/{sub}/settings.json`). The cloudApi (`ApiSyncProvider`) stubs them as no-ops until a `/v1/settings` endpoint lands on the .NET side.
- `SyncOrchestrator.syncNow()` gets a new step 0b before the note legs. LWW branches: cloud empty + local at epoch → no-op (don't seed defaults); cloud empty + local has changes → push; cloud newer → apply to prefs + fire `onSettingsApplied`; local newer → push; equal → no-op.
- Per-feature notifier setters (`GasLogSettingsNotifier.update`, `SyncSettingsNotifier.setNetworkPolicy`, `LocaleNotifier.setLocale`) all call `repo.bumpLastModified()` after writing their slice. Their `build()` methods `ref.watch(settingsBusProvider)` so a remote-apply triggers reload.
- 13 new tests, all green:
  - 7 `SyncableSettingsRepository` (defaults, hydrate from existing prefs keys, garbage-blob tolerance, null-locale apply, bumpLastModified)
  - 6 orchestrator LWW branches (fresh+empty=no-op, local-new+cloud-empty=push, cloud-newer=apply+bump, local-newer=push, equal=no-op, pull-throws=non-fatal SyncError)
- Full suite **549 / 549** (+13 from this fix, no regressions). Lint clean.
- D.2.5 (cross-device manual smoke) is the only remaining task — needs two real devices, can be done before or after merge.

## 2026-05-25 — Phase D.1: self-healing push for notes missing from remote

- User-reported bug: "Sync Now only pushes the gas log I updated; the automobile note never reaches OneDrive even though it's in the local DB." Logged + analyzed in `findings.md` (same date).
- Two distinct bugs surfaced from one symptom:
  - **D.1** (this commit): cursor-drift in the note push leg. `_collectChangedNotes` filters strictly on `mtime > cursor`; any note whose mtime fell below the cursor after a prior sync (regardless of why) gets silently skipped forever.
  - **D.2** (deferred): settings live in `SharedPreferences`, not the DB. They've never had a sync path. Scoped as a separate task in `task_plan.md`.
- Fix: after pulling the remote manifest, additively push any local note whose UUID is NOT in `remote.notes`. Self-healing — asymmetric to the pull leg's LWW (which only handles "remote has it, local stale-or-missing"). New `_collectMissingFromRemote({remoteUuids, alreadyQueued})` helper, merged into the existing push queue.
- Safe placement: AFTER the manifest pull (need `remote` to diff against), BEFORE the body-pull loop (no concern about overwriting just-pulled content because the body-pull only touches notes that ARE in the remote manifest — the disjoint set we're collecting is untouched by pull).
- 4 new regression tests in `test/core/data/sync/sync_orchestrator_missing_from_remote_test.dart` — first orchestrator-level tests in the codebase. Includes a `_FakeCloudSyncProvider` that captures pushes for assertion.
- Full suite **536 / 536** (+4 from this fix, no regressions). Lint clean.
- Branch `fix/sync-push-missing-from-remote` off main.

## 2026-05-24 — Phase C implementation complete (C.10 manual verification pending)

- Branch `feat/wifi-only-sync` stacked on `feat/auto-sync-controller`.
- `connectivity_plus: ^7.1.1` added. The package exposes `Connectivity().checkConnectivity()` returning `Future<List<ConnectivityResult>>` — list because a device can have multiple active interfaces (mobile + vpn, satellite + mobile, etc.). WiFi-allowed check is just `results.contains(ConnectivityResult.wifi)`.
- `lib/features/settings/domain/sync_settings.dart`: `SyncNetworkPolicy { wifiOnly, anyNetwork }` enum + `SyncSettings` value object. Settings is wrapped in a value type rather than a bare enum so future expansion (periodic-interval override, retry-budget) doesn't change the provider shape.
- `lib/features/settings/providers/sync_settings_provider.dart`: `Notifier<SyncSettings>` mirroring `DataModeNotifier`'s pattern (synchronous default in `build()` + async `_loadFromPrefs` to hydrate). Default `wifiOnly` (decision C2). **Caught a real bug while testing**: the original `_loadFromPrefs` didn't check `ref.mounted` before writing `state` after the async `SharedPreferences.getInstance()` gap. Riverpod 3 throws on writes-after-dispose, and in tests `addTearDown(container.dispose)` could fire before the load completed. Added `if (!ref.mounted) return;` guard.
- `SyncController` adds `CanAutoSyncCheck` typedef constructor param + `SyncStatus.lastAutoTriggerSkippedForNetwork` field. **Required a refactor**: the original `triggerAutoSync` checked `_status.isSyncing` synchronously and then did `_runSync` which set `isSyncing=true` synchronously. With Phase C's `await _canAutoSync()` between those, two parallel triggers could both pass the in-flight check (both see `isSyncing=false`). Fix: claim `isSyncing=true` synchronously at trigger entry, defer `notifyListeners()` until either the gate passes (show "Syncing…") or it fails (show "Waiting for WiFi") — no UI flicker.
- Production wiring composes `syncSettingsProvider` + `Connectivity().checkConnectivity()` via `ref.read` (per-call) so flipping the radio in Settings → Sync over takes effect on the very next auto-trigger.
- Settings UI: new `_SyncNetworkPolicySection` widget (`RadioGroup<SyncNetworkPolicy>` — modern post-Flutter-3.32 ancestor; got off deprecated per-tile `groupValue`/`onChanged`). `confirmManualSyncIfOnCellular(context, ref)` helper in `sync_status_card.dart` is shared between the embedded card button and the legacy `_syncNow` flow.
- `SyncStatusCard` gets a new "Waiting for WiFi to sync" visual state (Icons.wifi_off) when `lastAutoTriggerSkippedForNetwork == true`.
- 9 new tests: 4 in `sync_settings_provider_test.dart`, 5 added to `sync_controller_test.dart`. Full suite: **532 / 532 passing** (+9 from Phase C, no regressions). Lint clean.
- **C.10 (cellular smoke test) is the only Phase C item left.** Needs human-driven verification on iOS sim + Android emulator: WiFi-only policy + airplane mode → confirm auto-sync skips with banner; manual Sync now → confirm dialog appears.

## 2026-05-24 — Phase B implementation complete (B.9 manual verification pending)

- Branch `feat/auto-sync-controller` stacked on `feat/per-user-onedrive-isolation`.
- New `lib/core/data/sync/sync_controller.dart` — single class `SyncController extends ChangeNotifier with WidgetsBindingObserver`. Owns periodic timer, foreground debounce timer, throttle state, `SyncStatus` value object. Public API: `start()`, `stop()`, `triggerAutoSync(reason)`, `triggerManualSync()`, `status` getter, plus standard `ChangeNotifier` `addListener` for UI binding.
- Decided to keep state on the controller (a `ChangeNotifier`) rather than on `SyncOrchestrator`. Reasoning: orchestrator is stateless by design (each `syncNow()` is its own algorithm pass). Status is a consumer-of-orchestrator concept that lives one layer up.
- Lifecycle handling: `resumed` → 250 ms debounce → fire (avoids iOS resumed→inactive→resumed bouncing during notifications); `paused` → cancel timers + fire `appBackground` immediately; `inactive`/`detached`/`hidden` ignored (too noisy on iOS).
- Throttle: 30 s minimum gap between auto-fires; manual bypasses but still respects in-flight.
- `main.dart` converted from `ConsumerWidget` → `ConsumerStatefulWidget` so initState/dispose can `.start()` and `.stop()` the controller.
- New `lib/features/settings/presentation/widgets/sync_status_card.dart` — `ListenableBuilder`-driven card with four visual states: syncing, idle (with relative time), last-sync-failed (transient), persistent-failure-badge (≥3 consecutive fails). Embedded above the existing manual Sync Now button in the Settings screen.
- 13 new tests in `test/core/data/sync/sync_controller_test.dart`. Tests use `TestWidgetsFlutterBinding.ensureInitialized()` + `WidgetsBinding.instance.handleAppLifecycleStateChanged(...)` to drive real lifecycle dispatch through the registered observer. Throttle + clock are injected via `ClockNow` typedef.
- Full suite: **523 / 523 passing** (+13 from Phase B, no regressions). Lint clean.
- **B.9 (two-device lifecycle smoke test) is the only Phase B item left.** Needs manual verification on iOS sim + Android emulator: background the app, foreground it, confirm a sync runs; wait 10 min in foreground, confirm the periodic fires. Code is committed + pushed.

## 2026-05-24 — Phase A implementation complete (A.8 manual verification pending)

- Branch `feat/per-user-onedrive-isolation` off main.
- `OneDriveGraphClient`: added `CurrentUserSubResolver` typedef + injection. Replaced static `_approot` constant usage with a per-call `_userPath(rel, {action})` builder that produces `approot:/users/{encoded-sub}/{rel}[:/action]` and throws `OneDriveGraphException(401)` if no Hmm user is signed in. Added `getLegacyManifest`, `getLegacyNoteBlob`, `hasLegacyMigrationMarker`, `writeLegacyMigrationMarker` for one-time migration access.
- `OneDriveSyncProvider`: new constructor param `IdpTokenService`. New public `migrateLegacyIfNeeded()` — checks the marker, reads legacy manifest, copies each non-deleted note into the user's subtree, preserves any pre-existing per-user manifest (won't clobber cross-device sync state), writes the marker.
- `SyncOrchestrator.syncNow()`: calls `migrateLegacyIfNeeded()` via `is OneDriveSyncProvider` cast (kept off the abstract `CloudSyncProvider` interface — this is a OneDrive-specific concern). Migration failure is recorded as a SyncError but doesn't abort the sync.
- Two new test files. **16 new tests total**, all green:
  - `test/core/data/sync/onedrive_graph_client_path_test.dart` — 11 tests covering user-scoped paths, URL encoding, missing-sub → 401, legacy access, marker present/absent/write.
  - `test/core/data/sync/onedrive_migration_test.dart` — 5 tests covering marker-present, no-user, no-legacy-data, full copy with deleted-entry skipping, preserve-existing-per-user-manifest tripwire.
- Full suite: **510 / 510 passing** (+16 from Phase A, no regressions).
- One test-setup gotcha worth noting in `findings.md`: tests must pass `Dio(BaseOptions(validateStatus: (_) => true))`. The production graph client sets this on its own internal Dio so `if (resp.statusCode == 404) return null` branches work; if a test passes a bare `Dio()`, the default validateStatus throws on 4xx and every "missing file returns null" test fails confusingly with `DioException [bad response]`.
- **A.8 (two-user manual verification) is the only Phase A task left.** Code is committed + pushed; A.8 needs you to do it because it requires two real Microsoft account contexts. Phase A's PR can be opened + merged now; A.8 becomes a follow-up verification gate before declaring Phase A "done done".

## 2026-05-24 — Planning kicked off

- Created `task_plan.md`, `findings.md`, `progress.md` at repo root (matches the Hmm backend convention; CLAUDE.md doesn't specify otherwise for hmm_console).
- Wrote the three-phase plan: A (per-user OneDrive isolation) → B (auto-sync controller) → C (WiFi-only toggle). A blocks B blocks C, but each is independently shippable to main once started.
- Captured all relevant findings from this session's investigation in `findings.md` so a future session can resume cold.
- **Status: BLOCKED on 8 open decisions** (A1, A2, B1, B2, B3, C1, C2, C3). Recommendations are in `task_plan.md` — once answered, Phase A can start.
- No code touched yet, no branch created.
