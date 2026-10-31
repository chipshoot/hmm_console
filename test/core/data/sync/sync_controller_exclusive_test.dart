import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';

SyncResult _ok() => SyncResult(
  pulledNotes: 0,
  pulledAttachments: 0,
  pushedNotes: 0,
  pushedAttachments: 0,
  completedAt: DateTime.utc(2026, 10, 18),
);

void main() {
  test('runExclusive refuses while a sync is in flight', () async {
    final gate = Completer<SyncResult>();
    final c = SyncController(syncAction: () => gate.future);
    addTearDown(c.dispose);

    final syncing = c.triggerManualSync();
    var ran = false;
    expect(await c.runExclusive(() async => ran = true), isNull);
    expect(ran, isFalse);

    gate.complete(_ok());
    await syncing;
    expect(await c.runExclusive(() async => 2), 2);
  });

  test('auto syncs triggered during an exclusive run are skipped', () async {
    var syncs = 0;
    final c = SyncController(
      syncAction: () async {
        syncs++;
        return _ok();
      },
      throttle: Duration.zero,
    );
    addTearDown(c.dispose);

    final gate = Completer<void>();
    final run = c.runExclusive(() => gate.future.then((_) => 'done'));
    expect(await c.triggerAutoSync(SyncTriggerReason.periodic), isNull);
    expect(syncs, 0);

    gate.complete();
    expect(await run, 'done');
    expect(await c.triggerManualSync(), isNotNull);
    expect(syncs, 1);
  });

  test('a throwing exclusive body releases the slot', () async {
    final c = SyncController(syncAction: () async => _ok());
    addTearDown(c.dispose);

    await expectLater(
      c.runExclusive<int>(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(await c.runExclusive(() async => 1), 1);
  });

  test(
    'a manual sync requested during an exclusive run waits, then syncs',
    () async {
      var syncs = 0;
      final c = SyncController(
        syncAction: () async {
          syncs++;
          return _ok();
        },
        throttle: Duration.zero,
      );
      addTearDown(c.dispose);

      final gate = Completer<void>();
      final run = c.runExclusive(() => gate.future);
      final manual = c.triggerManualSync();
      await Future<void>.delayed(Duration.zero);
      expect(syncs, 0);

      gate.complete();
      await run;
      expect(await manual, isNotNull);
      expect(syncs, 1);
    },
  );

  test('an auto sync during an exclusive run is still dropped', () async {
    var syncs = 0;
    final c = SyncController(
      syncAction: () async {
        syncs++;
        return _ok();
      },
      throttle: Duration.zero,
    );
    addTearDown(c.dispose);

    final gate = Completer<void>();
    final run = c.runExclusive(() => gate.future);
    expect(await c.triggerAutoSync(SyncTriggerReason.periodic), isNull);
    gate.complete();
    await run;
    expect(syncs, 0);
  });

  test(
    'a throwing exclusive body still releases a waiting manual sync',
    () async {
      var syncs = 0;
      final c = SyncController(
        syncAction: () async {
          syncs++;
          return _ok();
        },
        throttle: Duration.zero,
      );
      addTearDown(c.dispose);

      final gate = Completer<void>();
      final run = c.runExclusive<void>(() => gate.future);
      final runCheck = expectLater(run, throwsStateError);
      final manual = c.triggerManualSync();
      gate.completeError(StateError('x'));
      await runCheck;
      expect(await manual, isNotNull);
      expect(syncs, 1);
    },
  );
}
