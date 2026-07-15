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
}
