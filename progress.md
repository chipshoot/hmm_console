# Progress log — Cloud-sync improvements

Newest entries at the top.

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
