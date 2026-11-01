import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/note_purge_scheduler.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

SyncResult _ok() => SyncResult(
  pulledNotes: 0,
  pulledAttachments: 0,
  pushedNotes: 0,
  pushedAttachments: 0,
  completedAt: DateTime.utc(2026, 10, 18),
);

void main() {
  late DateTime clock;
  late List<DateTime> runs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime.utc(2026, 10, 18, 8);
    runs = [];
  });

  NotePurgeScheduler scheduler(SyncController c, {Object? fail}) =>
      NotePurgeScheduler(
        controller: c,
        now: () => clock,
        purgeExpired: (now) async {
          if (fail != null) throw fail;
          runs.add(now);
          return 3;
        },
      );

  test('runs once, then waits a day', () async {
    final c = SyncController(syncAction: () async => _ok());
    addTearDown(c.dispose);
    final s = scheduler(c);

    expect(await s.maybeRun(), 3);
    expect(runs, [clock]);
    final prefs = await SharedPreferences.getInstance();
    expect(
      DateTime.parse(prefs.getString(NotePurgeScheduler.lastRunKey)!),
      clock,
    );

    clock = clock.add(const Duration(hours: 23));
    expect(await s.maybeRun(), isNull);
    expect(runs, hasLength(1));

    clock = clock.add(const Duration(hours: 2));
    expect(await s.maybeRun(), 3);
    expect(runs, hasLength(2));
  });

  test('skips while a sync runs and does not record a run', () async {
    final gate = Completer<SyncResult>();
    final c = SyncController(syncAction: () => gate.future);
    addTearDown(c.dispose);
    final s = scheduler(c);

    final syncing = c.triggerManualSync();
    expect(await s.maybeRun(), isNull);
    expect(runs, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NotePurgeScheduler.lastRunKey), isNull);

    gate.complete(_ok());
    await syncing;
    expect(await s.maybeRun(), 3);
  });

  test('a throwing purge is swallowed and not recorded', () async {
    final c = SyncController(syncAction: () async => _ok());
    addTearDown(c.dispose);

    expect(await scheduler(c, fail: StateError('db')).maybeRun(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NotePurgeScheduler.lastRunKey), isNull);
  });
}
