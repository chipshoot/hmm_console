import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/pending_sync_count_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/navigation/router_config.dart' show rootNavigatorKey;
import 'package:hmm_console/core/widgets/home_sync_overlay.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_access_panel.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_coach_mark.dart';
import 'package:hmm_console/core/widgets/quick_panel/quick_panel_settings.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedDataMode extends DataModeNotifier {
  _FixedDataMode(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
}

// `NotifierProvider<ConcreteNotifier, bool>.overrideWith` requires the
// override factory to return that exact concrete Notifier subclass (see
// `_FixedDataMode extends DataModeNotifier` above) — a single generic
// `Notifier<bool>` doesn't type-check for either provider, so this shares
// the fixed-value `build()` via a mixin instead of one `_FixedBool` class.
mixin _FixedBool on Notifier<bool> {
  bool get fixedValue;
  @override
  bool build() => fixedValue;
}

class _FixedQuickPanelEnabled extends QuickPanelEnabledNotifier
    with _FixedBool {
  _FixedQuickPanelEnabled(this.fixedValue);
  @override
  final bool fixedValue;
}

class _FixedQuickPanelHintShown extends QuickPanelHintShownNotifier
    with _FixedBool {
  _FixedQuickPanelHintShown(this.fixedValue);
  @override
  final bool fixedValue;
}

/// Stands in for the real `syncControllerProvider ->
/// syncOrchestratorProvider -> dataModeProvider` rebuild chain (riverpod
/// 3.x removed the legacy `StateProvider`, so we roll a tiny `Notifier`
/// the DataMode-switch regression test can drive directly and
/// deterministically via `container.read(...notifier).select(...)`).
class _SelectedControllerNotifier extends Notifier<SyncController> {
  _SelectedControllerNotifier(this._first);
  final SyncController _first;

  @override
  SyncController build() => _first;

  void select(SyncController controller) => state = controller;
}

final _selectedControllerProvider =
    NotifierProvider<_SelectedControllerNotifier, SyncController>(
        () => throw UnimplementedError('override in test'));

SyncController _idleController() {
  final c = SyncController(syncAction: () async => SyncResult(
        pulledNotes: 0,
        pulledAttachments: 0,
        pushedNotes: 0,
        pushedAttachments: 0,
        completedAt: DateTime.now().toUtc(),
      ));
  return c;
}

void main() {
  testWidgets('does not block taps on content behind it', (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.local)),
          syncControllerProvider.overrideWithValue(c),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
          // Not exercising the coach mark here — pin the hint as already
          // seen so its full-screen scrim (real first-run behavior) can't
          // intercept the tap this test is checking passes through.
          quickPanelHintShownProvider
              .overrideWith(() => _FixedQuickPanelHintShown(true)),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: Stack(
            children: [
              Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: TextButton(
                    onPressed: () => tapped = true,
                    child: const Text('top-left button'),
                  ),
                ),
              ),
              const HomeSyncOverlay(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('top-left button'));
    expect(tapped, isTrue,
        reason: 'overlay is bottom-trailing; must not intercept taps '
            'elsewhere on the screen');
  });

  testWidgets('a threshold-crossing pending count shows the anti-loss '
      'prompt', (tester) async {
    final c = SyncController(syncAction: () async => throw StateError('x'));
    addTearDown(c.dispose);
    // Force the "blocked" condition via a failed prior sync so
    // shouldPromptPendingSync's gate is satisfied once pending crosses
    // the threshold.
    await c.triggerAutoSync(SyncTriggerReason.periodic); // records a failure

    final controller = StreamController<int>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
          syncControllerProvider.overrideWithValue(c),
          pendingSyncCountProvider.overrideWith((ref) => controller.stream),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Stack(children: [HomeSyncOverlay()]),
        ),
      ),
    );
    await tester.pump();

    controller.add(0);
    await tester.pump();
    controller.add(10); // crosses pendingSyncPromptThreshold (5)
    await tester.pump();
    await tester.pump();

    expect(find.textContaining("haven't reached your cloud"), findsOneWidget);
  });

  testWidgets(
      'FIRST background on cellular: prompt is delivered after the async '
      "WiFi gate resolves, not missed by reading the flag too early",
      (tester) async {
    // Fresh controller — no prior sync, flags clear — mirrors the exact
    // incident: user creates a note, backgrounds within the debounce
    // window, and the WiFi-only gate hasn't resolved yet when
    // `didChangeAppLifecycleState(paused)` fires.
    final gateCompleter = Completer<bool>();
    final c = SyncController(
      syncAction: () async => throw StateError('should not sync'),
      canAutoSync: () => gateCompleter.future,
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
          syncControllerProvider.overrideWithValue(c),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(3)),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Stack(children: [HomeSyncOverlay()]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Background the app — this is what SyncController's own
    // didChangeAppLifecycleState(paused) also reacts to in production by
    // firing `unawaited(triggerAutoSync(...))`, which synchronously
    // claims isSyncing (no notify) and then awaits the gate. We drive
    // that same async gate directly here for determinism.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final autoSyncFuture = c.triggerAutoSync(SyncTriggerReason.appBackground);
    await tester.pump();

    // At this instant, exactly like the bug: the flag is still false and
    // lastResult is still null because the gate hasn't resolved yet.
    expect(c.status.lastAutoTriggerSkippedForNetwork, isFalse);
    expect(find.textContaining("haven't reached your cloud"), findsNothing);

    // Now the gate resolves as BLOCKED (WiFi-only policy, on cellular).
    // The controller's notifyListeners() fires synchronously as part of
    // this continuation — before this `await` returns.
    gateCompleter.complete(false);
    await autoSyncFuture;
    expect(c.status.lastAutoTriggerSkippedForNetwork, isTrue,
        reason: 'the gate must have resolved and set the flag by now');

    // The app is still `paused` (frame rendering suspended, same as a
    // real backgrounded app — see AppLifecycleState.paused semantics),
    // so `showDialog`'s pushed route hasn't painted yet even though
    // `_maybePrompt` already ran and committed to showing it. Simulate
    // the realistic next event — the user reopening the app — to observe
    // the prompt that was waiting for them.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    // The controller's notifyListeners() (fired when the flag flips to
    // true) must have delivered the prompt that the synchronous
    // paused-time read missed.
    expect(find.textContaining("haven't reached your cloud"), findsOneWidget);
  });

  testWidgets(
      'healthy WiFi background sync succeeds and pending clears: no '
      'false-alarm prompt', (tester) async {
    final c = SyncController(
      syncAction: () async => SyncResult(
        pulledNotes: 0,
        pulledAttachments: 0,
        pushedNotes: 3,
        pushedAttachments: 0,
        completedAt: DateTime.now().toUtc(),
      ),
      canAutoSync: () async => true,
    );
    addTearDown(c.dispose);

    final pendingController = StreamController<int>();
    addTearDown(pendingController.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
          syncControllerProvider.overrideWithValue(c),
          pendingSyncCountProvider.overrideWith((ref) => pendingController.stream),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Stack(children: [HomeSyncOverlay()]),
        ),
      ),
    );
    await tester.pump();

    pendingController.add(3);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await c.triggerAutoSync(SyncTriggerReason.appBackground);
    await tester.pump();
    await tester.pump();

    // Sync succeeded on the first try — the gate never blocked it, so
    // the flag never flips and no prompt should show.
    expect(c.status.lastAutoTriggerSkippedForNetwork, isFalse);
    expect(c.status.lastResult?.success, isTrue);

    // Pending drops to 0 once the push lands.
    pendingController.add(0);
    await tester.pump();

    // Return to the foreground (frame rendering was suspended while
    // `paused`, mirroring a real backgrounded app) so any would-be dialog
    // would actually paint if one had been queued — it hadn't.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining("haven't reached your cloud"), findsNothing);
  });

  testWidgets(
      'DataMode switch mid-background: the listener re-binds to the new '
      "controller instance, so the new controller's gate resolution still "
      'drives the prompt (regression for the stale-listener bug)',
      (tester) async {
    // Controller A: the "old" instance, live when we background. Its
    // syncAction/gate never actually get exercised — it's here purely to
    // prove the overlay stops listening to it after the swap.
    final controllerA = SyncController(
      syncAction: () async => throw StateError('A should not sync'),
    );
    addTearDown(controllerA.dispose);

    // Controller B: the "new" instance a DataMode switch would produce
    // (mirrors main.dart's `ref.listen<SyncController>` rebind). Gated so
    // we can resolve it as network-blocked deterministically, exactly
    // like the "FIRST background on cellular" test above.
    final gateCompleter = Completer<bool>();
    final controllerB = SyncController(
      syncAction: () async => throw StateError('B should not sync'),
      canAutoSync: () => gateCompleter.future,
    );
    addTearDown(controllerB.dispose);

    // `syncControllerProvider` normally rebuilds via `syncOrchestratorProvider
    // -> dataModeProvider`; overriding it to watch `_selectedControllerProvider`
    // lets the test swap the "live" controller deterministically, standing in
    // for that rebuild chain.
    final container = ProviderContainer(overrides: [
      dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
      _selectedControllerProvider
          .overrideWith(() => _SelectedControllerNotifier(controllerA)),
      syncControllerProvider
          .overrideWith((ref) => ref.watch(_selectedControllerProvider)),
      pendingSyncCountProvider.overrideWith((ref) => Stream.value(10)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Stack(children: [HomeSyncOverlay()]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Background the app while controller A is still live — arms the
    // background-prompt window. Both of A's flags are clear, so no
    // prompt yet.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.textContaining("haven't reached your cloud"), findsNothing);

    // Simulate the DataMode switch: `syncControllerProvider` is rebuilt
    // into controller B. The old controller (A) is never notified again
    // (mirrors `ref.onDispose(controller.stop)` — no more
    // `notifyListeners()` calls) and `_maybePrompt`'s own
    // `ref.read(syncControllerProvider)` already tracks B from this point
    // on. The bug under test is purely whether the *listener* also
    // re-binds.
    container.read(_selectedControllerProvider.notifier).select(controllerB);
    // `Provider`s that watch another provider recompute lazily on next
    // read, not eagerly on the dependency's change — in the real widget
    // tree, `SyncPill` (rendered alongside `HomeSyncOverlay`) already
    // does `ref.watch(syncControllerProvider)` on every build, which
    // keeps it hot. Force the same eager recompute here so the swap
    // propagates deterministically without depending on incidental
    // frame-scheduling timing.
    container.read(syncControllerProvider);
    await tester.pump();
    await tester.pump();

    // Drive B's gated auto-sync exactly like a real background trigger
    // would, and resolve it as network-blocked.
    final autoSyncFuture =
        controllerB.triggerAutoSync(SyncTriggerReason.appBackground);
    await tester.pump();
    gateCompleter.complete(false);
    await autoSyncFuture;
    expect(controllerB.status.lastAutoTriggerSkippedForNetwork, isTrue,
        reason: 'the gate must have resolved blocked and set the flag');

    // The app is still `paused` (frame rendering suspended), so a dialog
    // committed via `_maybePrompt` while backgrounded hasn't painted yet
    // — same as the "FIRST background on cellular" test above. Resume to
    // observe it.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    // If the overlay's listener re-bound to B (the fix), B's
    // notifyListeners() reached `_onControllerChanged` while still armed,
    // and the prompt shows. If the listener stayed stale on the orphaned
    // A (the bug), this notification never arrives and no prompt shows —
    // this assertion is what catches the regression.
    expect(find.textContaining("haven't reached your cloud"), findsOneWidget);
  });

  testWidgets('hidden by default — no panel, taps pass through to content',
      (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);
    var tappedBehind = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        quickPanelEnabledProvider.overrideWith(() => _FixedQuickPanelEnabled(true)),
        quickPanelHintShownProvider.overrideWith(() => _FixedQuickPanelHintShown(true)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: Stack(children: [
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                  onPressed: () => tappedBehind = true,
                  child: const Text('behind')),
            ),
          ),
          const HomeSyncOverlay(),
        ]),
      ),
    ));
    await tester.pump();
    expect(find.byType(QuickAccessPanel), findsNothing);
    await tester.tap(find.text('behind'));
    expect(tappedBehind, isTrue);
  });

  testWidgets('long-press the corner reveals the panel; outside-tap dismisses',
      (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        quickPanelEnabledProvider.overrideWith(() => _FixedQuickPanelEnabled(true)),
        quickPanelHintShownProvider.overrideWith(() => _FixedQuickPanelHintShown(true)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Stack(children: [HomeSyncOverlay()]),
      ),
    ));
    await tester.pump();

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.longPressAt(Offset(size.width - 20, size.height - 20));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessPanel), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessPanel), findsNothing);
  });

  testWidgets('disabled: long-press does nothing', (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        quickPanelEnabledProvider.overrideWith(() => _FixedQuickPanelEnabled(false)),
        quickPanelHintShownProvider.overrideWith(() => _FixedQuickPanelHintShown(true)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Stack(children: [HomeSyncOverlay()]),
      ),
    ));
    await tester.pump();

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.longPressAt(Offset(size.width - 20, size.height - 20));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessPanel), findsNothing);
  });

  testWidgets('at-risk dot shows only when shouldPromptPendingSync is true',
      (tester) async {
    // Blocked/failed controller — mirrors the "threshold-crossing pending
    // count shows the anti-loss prompt" test above: a failed prior sync
    // sets `lastResult.success == false`, satisfying
    // `shouldPromptPendingSync`'s blocked/failed condition.
    final c = SyncController(syncAction: () async => throw StateError('x'));
    addTearDown(c.dispose);
    await c.triggerAutoSync(SyncTriggerReason.periodic);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(3)),
        quickPanelEnabledProvider.overrideWith(() => _FixedQuickPanelEnabled(true)),
        quickPanelHintShownProvider.overrideWith(() => _FixedQuickPanelHintShown(true)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Stack(children: [HomeSyncOverlay()]),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('quickPanelAtRiskDot')), findsOneWidget);
  });

  testWidgets('no dot on the healthy/synced path', (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        quickPanelEnabledProvider.overrideWith(() => _FixedQuickPanelEnabled(true)),
        quickPanelHintShownProvider.overrideWith(() => _FixedQuickPanelHintShown(true)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Stack(children: [HomeSyncOverlay()]),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('quickPanelAtRiskDot')), findsNothing);
  });

  testWidgets('tapping the dot opens the panel', (tester) async {
    final c = SyncController(syncAction: () async => throw StateError('x'));
    addTearDown(c.dispose);
    await c.triggerAutoSync(SyncTriggerReason.periodic);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(3)),
        quickPanelEnabledProvider.overrideWith(() => _FixedQuickPanelEnabled(true)),
        quickPanelHintShownProvider.overrideWith(() => _FixedQuickPanelHintShown(true)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Stack(children: [HomeSyncOverlay()]),
      ),
    ));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('quickPanelAtRiskDot')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessPanel), findsOneWidget);
  });

  testWidgets('coach mark shows once, gone after "Got it"', (tester) async {
    // Real settings-backed provider (mirrors quick_panel_settings_test.dart's
    // harness) rather than a `_Fixed*` double: `markShown()` must actually
    // flip the persisted flag and reactively hide the coach mark, which an
    // immutable fixed-value Notifier can't observe.
    SharedPreferences.setMockInitialValues({});
    final c = _idleController();
    addTearDown(c.dispose);

    final container = ProviderContainer(overrides: [
      dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
      syncControllerProvider.overrideWithValue(c),
      pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
    ]);
    addTearDown(container.dispose);
    // Settle the async settings load (default AppSettings: quickPanelEnabled
    // true, quickPanelHintShown false) before pumping the widget.
    await container.read(settingsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Stack(children: [HomeSyncOverlay()]),
        ),
      ),
    );
    await tester.pump();

    // hint starts unseen → coach mark visible
    expect(find.byType(QuickPanelCoachMark), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickPanelCoachMark), findsNothing);
  });
}
