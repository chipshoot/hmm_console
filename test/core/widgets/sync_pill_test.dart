import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/pending_sync_count_provider.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/navigation/router_config.dart' show rootNavigatorKey;
import 'package:hmm_console/core/widgets/sync_pill.dart';

Future<void> _pump(
  WidgetTester tester, {
  required DataMode mode,
  SyncController? controller,
  int pending = 0,
}) async {
  final c = controller ??
      SyncController(syncAction: () async => SyncResult(
            pulledNotes: 0,
            pulledAttachments: 0,
            pushedNotes: 0,
            pushedAttachments: 0,
            completedAt: DateTime.now().toUtc(),
          ));
  addTearDown(c.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _FixedDataMode(mode)),
        syncControllerProvider.overrideWithValue(c),
        pendingSyncCountProvider.overrideWith((ref) => Stream.value(pending)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: SyncPill()),
      ),
    ),
  );
  await tester.pump();
}

class _FixedDataMode extends DataModeNotifier {
  _FixedDataMode(this._mode);
  final DataMode _mode;
  @override
  DataMode build() => _mode;
}

void main() {
  testWidgets('local mode renders a neutral/disabled chip', (tester) async {
    await _pump(tester, mode: DataMode.local);
    expect(find.text('Local only'), findsOneWidget);
  });

  testWidgets('cloudApi mode renders a neutral/disabled chip (Phase 1)',
      (tester) async {
    await _pump(tester, mode: DataMode.cloudApi);
    expect(find.text('Cloud (soon)'), findsOneWidget);
  });

  testWidgets('cloudStorage + synced renders "Synced"', (tester) async {
    final c = SyncController(syncAction: () async => SyncResult(
          pulledNotes: 0,
          pulledAttachments: 0,
          pushedNotes: 0,
          pushedAttachments: 0,
          completedAt: DateTime.now().toUtc(),
        ));
    await _pump(tester, mode: DataMode.cloudStorage, controller: c, pending: 0);
    expect(find.text('Synced'), findsOneWidget);
  });

  testWidgets('cloudStorage + pending renders "N unsynced"', (tester) async {
    await _pump(tester, mode: DataMode.cloudStorage, pending: 3);
    expect(find.text('3 unsynced'), findsOneWidget);
  });

  testWidgets('cloudStorage + syncing renders "Syncing…"', (tester) async {
    final c = SyncController(syncAction: () => Completer<SyncResult>().future);
    await _pump(tester, mode: DataMode.cloudStorage, controller: c);
    // Fire-and-forget: syncAction is a Completer that never completes (the
    // sync stays in-flight by design), so awaiting triggerManualSync would
    // hang. The synchronous part flips isSyncing + notifies listeners.
    unawaited(c.triggerManualSync());
    await tester.pump();
    expect(find.text('Syncing…'), findsOneWidget);
  });
}
