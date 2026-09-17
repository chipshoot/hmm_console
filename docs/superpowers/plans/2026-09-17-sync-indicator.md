# Sync Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A status dot on the dashboard's account avatar that shows at a glance whether the app is synced to the cloud, and an avatar sheet that names the reason and the one action that fixes it when it is not.

**Architecture:** A pure `syncIndicatorStateFor` function maps the existing `SyncStatus` + `DataMode` onto five visual states. A small `SyncStatusDot` widget renders one; the dashboard overlays it on the avatar it already draws and subscribes the way the Settings card already does. The avatar sheet gains a header and a context-specific first action. No change to the sync engine.

**Tech Stack:** Flutter, Riverpod, `ListenableBuilder` over the existing `SyncController` (a `ChangeNotifier`). No new dependency.

**Mockup (approved 2026-09-17):** https://claude.ai/artifact/59HDhRAmzgZxBZTiEduQzF

## Global Constraints

- **Nothing new in the sync engine.** `SyncController` already calls `notifyListeners()` on every status transition (`sync_controller.dart` lines 291, 330, 367) and `SyncStatusCard` already consumes it via `ListenableBuilder`. The dot uses the identical subscription. Do not add a stream or a provider for status.
- **Five states, and they must be told apart.** Synced, syncing, waiting, failed, and none. Collapsing any two is the exact mistake that produced four bug reports on the licence feature. Loading is NOT one of these — `SyncStatus` is a synchronous field.
- **Local mode shows no dot.** Absence is the signal. A grey "off" dot would claim a state about a cloud that is not there.
- **The failing sheet's first action is specific**, never a generic "Retry": an `auth` error gets "Sign in again"; anything else gets "Sync now". Two variants ship; more follow once real failures show what is common.
- Every user-facing string goes through ARB, `en` and `zh`. The Chinese is unreviewed like the rest.
- The sheet is already Cupertino on iOS and Material elsewhere (`_showUserMenu`); the header goes in both branches.
- Motion respects `MediaQuery.disableAnimations`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/data/sync/sync_indicator_state.dart` | Pure mapping: `(SyncStatus, DataMode) → SyncIndicatorState`, plus `isAuthFailure` |
| `lib/core/data/sync/widgets/sync_status_dot.dart` | Renders one state as a dot; owns the pulse |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Overlays the dot on the avatar; sheet header + first action |
| `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` | 4 new keys |

---

### Task 1: The state mapping

Every rule that could be wrong lives here, in a pure function, where a test can reach all five states without a widget.

**Files:**
- Create: `lib/core/data/sync/sync_indicator_state.dart`
- Test: `test/core/data/sync/sync_indicator_state_test.dart`

**Interfaces:**
- Produces: `enum SyncIndicatorState { synced, syncing, waiting, failed, none }`; `SyncIndicatorState syncIndicatorStateFor(SyncStatus status, DataMode mode)`; `bool isAuthFailure(SyncStatus status)`.
- Consumes: `SyncStatus` (`sync_controller.dart` lines 41–80: `isSyncing`, `lastSyncAt`, `lastResult`, `consecutiveFailures`, `lastAutoTriggerSkippedForNetwork`); `DataMode`; `SyncError.recordType`, where `'auth'` marks an auth failure (`sync_orchestrator.dart` line 98).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_indicator_state.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';

SyncResult _result({bool ok = true, List<SyncError> errors = const []}) =>
    SyncResult(
      pulledNotes: 0, pulledAttachments: 0, pushedNotes: 0,
      pushedAttachments: 0, completedAt: DateTime.utc(2026, 9, 17),
      errors: ok ? const [] : errors,
    );

const _authError =
    SyncError(recordType: 'auth', recordId: '', message: 'sub claim missing');
const _noteError =
    SyncError(recordType: 'note', recordId: 'n1', message: 'Push failed');

void main() {
  test('Local mode shows NO dot, whatever the status says', () {
    // Absence is the signal: a dot of any colour would claim something
    // about a cloud that is not there.
    const status = SyncStatus(isSyncing: true);
    expect(syncIndicatorStateFor(status, DataMode.local),
        SyncIndicatorState.none);
  });

  test('in flight wins over everything', () {
    final status = SyncStatus(
        isSyncing: true, consecutiveFailures: 5,
        lastResult: _result(ok: false, errors: const [_noteError]));
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.syncing);
  });

  test('a failed last run is failed', () {
    final status =
        SyncStatus(lastResult: _result(ok: false, errors: const [_noteError]));
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.failed);
  });

  test('three consecutive failures is failed even with no lastResult', () {
    // The Settings card treats the streak as its own signal; so does this.
    const status = SyncStatus(consecutiveFailures: 3);
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.failed);
  });

  test('held for Wi-Fi is waiting, not failed', () {
    // Nothing is wrong; the network policy is doing its job.
    const status = SyncStatus(lastAutoTriggerSkippedForNetwork: true);
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.waiting);
  });

  test('a successful last run is synced', () {
    final status = SyncStatus(
        lastSyncAt: DateTime.utc(2026, 9, 17), lastResult: _result());
    expect(syncIndicatorStateFor(status, DataMode.cloudStorage),
        SyncIndicatorState.synced);
  });

  test('never synced yet, in a cloud mode, is waiting', () {
    // Cloud is configured but nothing has run: not a failure, not a success.
    const status = SyncStatus();
    expect(syncIndicatorStateFor(status, DataMode.cloudApi),
        SyncIndicatorState.waiting);
  });

  group('isAuthFailure', () {
    test('true when the last result carries an auth error', () {
      final status =
          SyncStatus(lastResult: _result(ok: false, errors: const [_authError]));
      expect(isAuthFailure(status), isTrue);
    });

    test('false for an ordinary failure', () {
      final status =
          SyncStatus(lastResult: _result(ok: false, errors: const [_noteError]));
      expect(isAuthFailure(status), isFalse);
    });

    test('false with no result at all', () {
      expect(isAuthFailure(const SyncStatus()), isFalse);
    });
  });
}
```

`SyncStatus` has a private `_copyWith`; construct it with named parameters as above. If a field name here does not compile, the test is wrong and `sync_controller.dart` lines 41–80 are right — fix the test, not the model. Check whether `SyncResult.success` is a getter derived from `errors` or a stored field; if stored, pass it explicitly in `_result`.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/data/sync/sync_indicator_state_test.dart`
Expected: FAIL — `sync_indicator_state.dart` does not exist.

- [ ] **Step 3: Write the mapping**

```dart
import '../data_mode.dart';
import 'sync_controller.dart';

/// What the dashboard dot shows. Five states, deliberately kept apart:
/// collapsing "waiting" into "failed", or "never synced" into "synced", is
/// the mistake that produced four bug reports on the licence screens.
enum SyncIndicatorState {
  /// Last run succeeded.
  synced,

  /// A run is in flight right now.
  syncing,

  /// Nothing is wrong, but nothing has happened either: held for Wi-Fi by
  /// the network policy, or cloud is configured and no run has occurred.
  waiting,

  /// The last run failed, or three or more in a row have.
  failed,

  /// Local data mode: there is no cloud, so there is no dot. Absence is the
  /// signal — a grey dot would claim a state about nothing.
  none,
}

SyncIndicatorState syncIndicatorStateFor(SyncStatus status, DataMode mode) {
  if (mode == DataMode.local) return SyncIndicatorState.none;
  // Order matters and mirrors SyncStatusCard: in-flight beats a stale
  // failure, a failure streak beats a Wi-Fi hold, a hold beats a stale
  // result.
  if (status.isSyncing) return SyncIndicatorState.syncing;
  if (status.consecutiveFailures >= 3) return SyncIndicatorState.failed;
  if (status.lastAutoTriggerSkippedForNetwork) return SyncIndicatorState.waiting;
  final last = status.lastResult;
  if (last != null && !last.success) return SyncIndicatorState.failed;
  if (status.lastSyncAt != null) return SyncIndicatorState.synced;
  return SyncIndicatorState.waiting;
}

/// Whether the most recent failure was a sign-in problem, so the sheet can
/// offer "Sign in again" rather than a retry that would fail the same way.
bool isAuthFailure(SyncStatus status) =>
    status.lastResult?.errors.any((e) => e.recordType == 'auth') ?? false;
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/core/data/sync/sync_indicator_state_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 5: Mutation-check**

Move the `lastAutoTriggerSkippedForNetwork` check below the `lastResult` check, so a Wi-Fi hold with a stale failure reads failed. Expected: the held-for-Wi-Fi test still passes (it has no lastResult) — so ALSO add a stale failed `lastResult` to that test's status first. Then expected: it fails. Restore both.
Return `synced` from the final line. Expected: the never-synced test fails. Restore.
Remove the `DataMode.local` guard. Expected: the Local test fails. Restore.

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/sync/sync_indicator_state.dart test/core/data/sync/sync_indicator_state_test.dart
git commit -m "feat(sync): map sync status onto five indicator states"
```

---

### Task 2: The dot

**Files:**
- Create: `lib/core/data/sync/widgets/sync_status_dot.dart`
- Test: `test/core/data/sync/widgets/sync_status_dot_test.dart`

**Interfaces:**
- Produces: `SyncStatusDot({required SyncIndicatorState state, double size = 13})`. Renders `SizedBox.shrink()` for `none`.
- Consumes: `SyncIndicatorState` (Task 1).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/sync_indicator_state.dart';
import 'package:hmm_console/core/data/sync/widgets/sync_status_dot.dart';

void main() {
  Future<void> pump(WidgetTester tester, SyncIndicatorState s,
      {bool reducedMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(body: Center(child: SyncStatusDot(state: s))),
      ),
    ));
    await tester.pump();
  }

  testWidgets('none renders nothing at all', (tester) async {
    await pump(tester, SyncIndicatorState.none);
    expect(find.byKey(const Key('syncStatusDot')), findsNothing);
  });

  for (final s in [
    SyncIndicatorState.synced,
    SyncIndicatorState.syncing,
    SyncIndicatorState.waiting,
    SyncIndicatorState.failed,
  ]) {
    testWidgets('$s renders a dot', (tester) async {
      await pump(tester, s);
      expect(find.byKey(const Key('syncStatusDot')), findsOneWidget);
    });
  }

  testWidgets('each visible state is a DIFFERENT colour', (tester) async {
    // The whole point is telling them apart at a glance.
    final colours = <Color>{};
    for (final s in [
      SyncIndicatorState.synced,
      SyncIndicatorState.syncing,
      SyncIndicatorState.waiting,
      SyncIndicatorState.failed,
    ]) {
      await pump(tester, s);
      final box = tester.widget<DecoratedBox>(find.byKey(const Key('syncStatusFill')));
      colours.add((box.decoration as BoxDecoration).color!);
    }
    expect(colours, hasLength(4));
  });

  testWidgets('syncing pulses, and the pulse honours reduced motion',
      (tester) async {
    await pump(tester, SyncIndicatorState.syncing);
    expect(find.byKey(const Key('syncStatusPulse')), findsOneWidget);

    await pump(tester, SyncIndicatorState.syncing, reducedMotion: true);
    expect(find.byKey(const Key('syncStatusPulse')), findsNothing);
  });

  testWidgets('a settled state does not pulse', (tester) async {
    await pump(tester, SyncIndicatorState.synced);
    expect(find.byKey(const Key('syncStatusPulse')), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/data/sync/widgets/sync_status_dot_test.dart`
Expected: FAIL — `sync_status_dot.dart` does not exist.

- [ ] **Step 3: Write the widget**

```dart
import 'package:flutter/material.dart';

import '../sync_indicator_state.dart';

/// A presence-style dot for one [SyncIndicatorState].
///
/// Sized to sit on the corner of a 36px avatar. Semantic colours are fixed
/// hex rather than theme tokens: green/orange/red must mean the same thing
/// on both light and dark, and the theme accent already means "this app".
class SyncStatusDot extends StatelessWidget {
  const SyncStatusDot({super.key, required this.state, this.size = 13});

  final SyncIndicatorState state;
  final double size;

  static const _synced = Color(0xFF34C759);
  static const _waiting = Color(0xFFFF9F0A);
  static const _failed = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    if (state == SyncIndicatorState.none) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final colour = switch (state) {
      SyncIndicatorState.synced => _synced,
      SyncIndicatorState.syncing => scheme.primary,
      SyncIndicatorState.waiting => _waiting,
      SyncIndicatorState.failed => _failed,
      SyncIndicatorState.none => Colors.transparent,
    };
    // Motion is the only thing that says "happening now"; it is also the
    // first thing to drop for anyone who has asked for less of it.
    final pulse = state == SyncIndicatorState.syncing &&
        !MediaQuery.of(context).disableAnimations;

    return SizedBox(
      key: const Key('syncStatusDot'),
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (pulse) _Pulse(colour: colour, size: size),
          DecoratedBox(
            key: const Key('syncStatusFill'),
            decoration: BoxDecoration(
              color: colour,
              shape: BoxShape.circle,
              // Ring in the surface colour so the dot reads as sitting ON
              // the avatar rather than cut into it.
              border: Border.all(color: scheme.surface, width: 2.5),
            ),
            child: SizedBox(width: size, height: size),
          ),
        ],
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.colour, required this.size});
  final Color colour;
  final double size;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const Key('syncStatusPulse'),
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        final grow = widget.size * 0.4 * t;
        return Positioned(
          left: -grow, top: -grow, right: -grow, bottom: -grow,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.colour.withValues(alpha: 0.6 * (1 - t)),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/core/data/sync/widgets/sync_status_dot_test.dart`
Expected: PASS (8 tests). If the pulse test hangs, it is because `pump()` above uses a single `pump` — a repeating animation never settles, so never use `pumpAndSettle` in this file.

- [ ] **Step 5: Mutation-check**

Make `waiting` and `failed` the same colour. Expected: the distinct-colours test fails. Restore.
Drop the `disableAnimations` check. Expected: the reduced-motion test fails. Restore.

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/sync/widgets test/core/data/sync/widgets
git commit -m "feat(sync): add the status dot widget"
```

---

### Task 3: The strings

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`

- [ ] **Step 1: Add the keys**

`app_en.arb`, after the existing `syncAnyway` key:
```json
"syncSheetSignedInAs": "Signed in as {email}",
"@syncSheetSignedInAs": { "placeholders": { "email": { "type": "String" } } },
"syncSheetSignInAgain": "Sign in again",
"syncSheetSyncNow": "Sync now",
"syncSheetAuthExpired": "Your Hmm sign-in has expired. Sign in again to resume syncing."
```

`app_zh.arb`, same position:
```json
"syncSheetSignedInAs": "已登录：{email}",
"syncSheetSignInAgain": "重新登录",
"syncSheetSyncNow": "立即同步",
"syncSheetAuthExpired": "Hmm 登录已过期。请重新登录以恢复同步。"
```

The existing `syncStatusSynced`, `syncStatusSyncing`, `syncStatusWaitingWifi`, `syncStatusLastFailed`, `syncStatusFailing`, and `syncStatusNever` keys are reused for the status line — do not duplicate them.

- [ ] **Step 2: Regenerate and check parity**

```bash
flutter gen-l10n
python3 -c "
import json
en=json.load(open('lib/l10n/app_en.arb')); zh=json.load(open('lib/l10n/app_zh.arb'))
ek={k for k in en if not k.startswith('@')}; zk={k for k in zh if not k.startswith('@')}
print('en',len(ek),'zh',len(zk)); print(sorted(ek-zk), sorted(zk-ek))"
```
Expected: equal counts (530 + 4 = 534 each), both lists empty.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n && git commit -m "feat(sync): add sheet strings, en/zh"
```

---

### Task 4: The dashboard

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Test: `test/features/dashboard/sync_indicator_test.dart`

**Interfaces:**
- Consumes: `syncControllerProvider`, `dataModeProvider`, `currentUserProvider`, `signOutUseCaseProvider`, `syncIndicatorStateFor`, `isAuthFailure`, `SyncStatusDot`.
- The avatar is `GestureDetector(onTap: _showUserMenu, child: _buildAvatar(user, colorScheme))` at `dashboard_screen.dart` ~line 158. The sheet is `_showUserMenu()` at ~line 287, with a Cupertino branch and a Material branch.

- [ ] **Step 1: Write the failing tests**

**Copy the harness from `test/features/dashboard/dashboard_cheatsheet_tile_test.dart`** — it already solves the two hard parts: `_SignedIn extends CurrentUserNotifier` short-circuits `_restoreUserIfNeeded` so no token fake is needed, and `_IntroSeen extends IntroCardSeenNotifier` keeps `SettingsController` out. Reuse both verbatim.

Add a fake controller:

```dart
class _FakeSync extends SyncController {
  _FakeSync() : super(syncAction: () async => throw UnimplementedError());
  SyncStatus _s = const SyncStatus();
  @override
  SyncStatus get status => _s;
  void set(SyncStatus s) { _s = s; notifyListeners(); }
}
```

Check the exact `syncAction` parameter type in `sync_controller.dart` line 140 and match it; do NOT call `start()` on the fake.

Override `syncControllerProvider.overrideWithValue(fake)`, `dataModeProvider`, `currentUserProvider` (`_SignedIn`), `introCardSeenProvider` (`_IntroSeen`). Assert:

- in `cloudStorage` with a successful status, `syncStatusDot` is present
- in `local`, `syncStatusDot` is absent
- **after `fake.set(<failed status>)`, the dot's `syncStatusFill` colour changes** — this is the one that proves the subscription is live rather than a one-time read at build
- tapping the avatar with an `auth` failure shows `syncSheetSignInAgain` and `syncSheetAuthExpired`
- tapping it with an ordinary failure shows `syncSheetSyncNow` and NOT `syncSheetSignInAgain`
- tapping it when synced shows `syncSheetSyncNow` and a `syncStatusSynced` line

The dashboard fires real HTTP for some cards in `cloudApi`; run these tests in `cloudStorage` and `local`, and use bounded `pump`s rather than `pumpAndSettle` — the licence tests learned this the hard way.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/dashboard/sync_indicator_test.dart`
Expected: FAIL — no `syncStatusDot` exists.

- [ ] **Step 3: Overlay the dot on the avatar**

Replace the `GestureDetector` child at ~line 158:

```dart
GestureDetector(
  onTap: _showUserMenu,
  child: ListenableBuilder(
    // The identical subscription SyncStatusCard uses: the controller is a
    // ChangeNotifier and fires on every status transition. No new stream.
    listenable: ref.watch(syncControllerProvider),
    builder: (context, _) {
      final state = syncIndicatorStateFor(
        ref.read(syncControllerProvider).status,
        ref.watch(dataModeProvider),
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatar(user, colorScheme),
          Positioned(right: -1, bottom: -1, child: SyncStatusDot(state: state)),
        ],
      );
    },
  ),
),
```

- [ ] **Step 4: Add the sheet header and the first action**

At the top of `_showUserMenu()`:

```dart
final controller = ref.read(syncControllerProvider);
final status = controller.status;
final state = syncIndicatorStateFor(status, ref.read(dataModeProvider));
final auth = isAuthFailure(status);
final email = ref.read(currentUserProvider)?.email ?? '';
```

Check whether `currentUserProvider` exposes a value directly or through `AsyncValue` and read it accordingly.

**Status line:** copy the `headline` selection from `SyncStatusCard._Body` (`sync_status_card.dart` lines 50–75) into a small private `_syncHeadline(SyncStatus, AppLocalizations)` in the dashboard file rather than reimplementing the ordering. When `auth`, append `l.syncSheetAuthExpired` as its own line.

**Cupertino branch:** `CupertinoActionSheet(title: Text(l.syncSheetSignedInAs(email)), message: Text(<status line(s)>), actions: [...])`.
**Material branch:** a leading `ListTile(enabled: false, title: Text(l.syncSheetSignedInAs(email)), subtitle: Text(<status line(s)>))`.

**First action, both branches, ONLY when `state != SyncIndicatorState.none`:**
- if `auth` → label `l.syncSheetSignInAgain`, runs `ref.read(signOutUseCaseProvider).signOut()` — the auth redirect then lands on the login screen, which is the only sign-in-again path this app has.
- else → label `l.syncSheetSyncNow`, runs the same call the Settings card's "Sync now" button makes — find it in `sync_status_card.dart` around line 111 and copy it exactly, including any cellular confirmation it goes through.

Then the existing Settings and Sign out rows, unchanged.

- [ ] **Step 5: Run them and watch them pass**

Run: `flutter test test/features/dashboard/sync_indicator_test.dart`
Expected: PASS

- [ ] **Step 6: Mutation-check**

Replace `ListenableBuilder` with a direct read of `status` in `build`. Expected: the "set() changes the dot" test fails. This is the mutation that matters — without it the dot is a photograph of startup. Restore.
Make the `auth` branch offer `syncSheetSyncNow`. Expected: the auth-sheet test fails. Restore.
Render the dot regardless of `state`. Expected: the Local test fails. Restore.

- [ ] **Step 7: Commit**

```bash
flutter analyze
git add lib/features/dashboard test/features/dashboard
git commit -m "feat(dashboard): sync status dot on the avatar, with a sheet that says why"
```

---

### Task 5: Verification

- [ ] **Step 1: Analyzer** — `flutter analyze`. Expected: only the 2 pre-existing issues (`onboarding_screen.dart`, `main.dart`).
- [ ] **Step 2: Full suite** — `flutter test`. Expected: all pass. It stood at 1535 before this work.
- [ ] **Step 3: ARB parity** — the script from Task 3 Step 2. Expected: equal, empty.
- [ ] **Step 4: Both themes, on the simulator.** Light and dark. The dot's ring must read against both the light and dark avatar, and green/orange/red must all be distinguishable on both grounds. The colours are fixed hex, not theme tokens, precisely so this holds — confirm it does.
- [ ] **Step 5: On device.** Deploy with `scripts/deploy-prod-ios-device.sh`. Then:
  - Turn on airplane mode, tap the avatar, tap "Sync now". The dot goes red; reopen the sheet and it names the failure.
  - Turn airplane mode off, "Sync now" again. The dot pulses, then goes green.
  - Switch data mode to Local in Settings. The dot disappears entirely.
  - Switch back to Cloud Storage. It returns.
- [ ] **Step 6: Commit**

```bash
git add -A lib test docs && git commit -m "chore(sync): verify the indicator across themes and states"
```

---

## Out of scope

- **Per-cause first actions beyond `auth`.** "Reconnect OneDrive" for a lapsed Microsoft token, "Waiting for Wi-Fi" as an explanation — worth adding once real failures show which are common. Two variants ship; `syncIndicatorStateFor` and `isAuthFailure` are where more go.
- **A dot anywhere other than the dashboard.** The Settings card already covers Settings.
- **Login-free local mode (#49).** This indicator makes the login coupling *visible*; removing it is that separate item.
