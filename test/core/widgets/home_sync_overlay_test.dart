import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/pending_sync_count_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/navigation/router_config.dart' show rootNavigatorKey;
import 'package:hmm_console/core/widgets/home_button.dart';
import 'package:hmm_console/core/widgets/home_sync_overlay.dart';
import 'package:hmm_console/core/widgets/sync_pill.dart';

class _FixedDataMode extends DataModeNotifier {
  _FixedDataMode(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
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
  testWidgets('renders Home + Sync controls over a raw Scaffold '
      '(mimics DashboardScreen)', (tester) async {
    final c = _idleController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWith(() => _FixedDataMode(DataMode.cloudStorage)),
          syncControllerProvider.overrideWithValue(c),
          pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: Stack(
            children: [
              Scaffold(body: const Center(child: Text('dashboard content'))),
              const HomeSyncOverlay(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('dashboard content'), findsOneWidget);
    expect(find.byType(HomeButton), findsOneWidget);
    expect(find.byType(SyncPill), findsOneWidget);
  });

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
}
