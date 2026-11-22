import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/contract/i_activity_repository.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';

Activity _a(
  String id, {
  DateTime? at,
  String kind = 'health.walk',
  int minutes = 30,
}) => Activity(
  id: id,
  kind: kind,
  start: OffsetDateTime(at ?? DateTime.utc(2026, 11, 21, 12), Duration.zero),
  durationMinutes: minutes,
  intensity: ActivityIntensity.light,
  measurements: const [
    ActivityMeasurement(name: 'distance', value: 2.5, unit: 'km'),
  ],
  notes: 'a note',
  details: const {
    'health': {'x': 1},
  },
);

class _Changes {
  _Changes(Stream<void> s) {
    _sub = s.listen((_) => count++);
  }
  late final StreamSubscription<void> _sub;
  int count = 0;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  Future<void> expectBump(Future<void> Function() action) async {
    await settle();
    final start = count;
    await action();
    for (var i = 0; i < 40 && count <= start; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(count, greaterThan(start));
  }

  Future<void> cancel() => _sub.cancel();
}

final _from = DateTime.utc(2026, 11, 1);
final _to = DateTime.utc(2026, 12, 1);

/// The contract every [IActivityRepository] must satisfy. [create] must
/// return a fresh, empty store.
void runActivityRepositoryContract(
  Future<IActivityRepository> Function() create,
) {
  group('IActivityRepository contract', () {
    late IActivityRepository repo;
    setUp(() async => repo = await create());

    test('save then get returns the same fields, whole-second stamp', () async {
      final saved = await repo.saveActivity(_a('a1'));
      final got = await repo.getActivity('a1');
      expect(got, isNotNull);
      expect(got!.kind, 'health.walk');
      expect(got.start, saved.start);
      expect(got.durationMinutes, 30);
      expect(got.intensity, ActivityIntensity.light);
      expect(got.measurements, saved.measurements);
      expect(got.notes, 'a note');
      expect(got.details, saved.details);
      expect(got.updatedAt, isNotNull);
      expect(got.updatedAt!.millisecond, 0);
      expect(got.updatedAt, saved.updatedAt);
    });

    test('getActivity of an unknown id is null', () async {
      expect(await repo.getActivity('nope'), isNull);
    });

    test('saving the same id twice updates, never duplicates', () async {
      await repo.saveActivity(_a('a1'));
      await repo.saveActivity(_a('a1', minutes: 45));
      final all = await repo.activitiesBetween(_from, _to);
      expect(all, hasLength(1));
      expect(all.single.durationMinutes, 45);
    });

    test(
      'activitiesBetween is [from, to) by start.utc, newest first',
      () async {
        await repo.saveActivity(
          _a('before', at: DateTime.utc(2026, 10, 31, 23)),
        );
        await repo.saveActivity(_a('atFrom', at: _from));
        await repo.saveActivity(_a('mid', at: DateTime.utc(2026, 11, 15)));
        await repo.saveActivity(_a('late', at: DateTime.utc(2026, 11, 30, 23)));
        await repo.saveActivity(_a('atTo', at: _to));
        final got = await repo.activitiesBetween(_from, _to);
        expect(got.map((a) => a.id), ['late', 'mid', 'atFrom']);
      },
    );

    test('areas filters by Activity.area', () async {
      await repo.saveActivity(_a('w'));
      await repo.saveActivity(_a('r', kind: 'reading.reading'));
      final got = await repo.activitiesBetween(_from, _to, areas: {'reading'});
      expect(got.map((a) => a.id), ['r']);
    });

    test('delete then get is null; deleting a missing id is a no-op', () async {
      await repo.deleteActivity('ghost');
      await repo.saveActivity(_a('a1'));
      await repo.deleteActivity('a1');
      expect(await repo.getActivity('a1'), isNull);
      await repo.deleteActivity('a1');
    });

    test('delete then save the same id leaves exactly one', () async {
      await repo.saveActivity(_a('a1'));
      await repo.deleteActivity('a1');
      expect(await repo.activitiesBetween(_from, _to), isEmpty);
      await repo.saveActivity(_a('a1'));
      final all = await repo.activitiesBetween(_from, _to);
      expect(all, hasLength(1));
      expect(all.single.id, 'a1');
    });

    test(
      'changes() is quiet on subscribe, emits after save and delete',
      () async {
        await repo.saveActivity(_a('seed'));
        final ch = _Changes(repo.changes());
        try {
          await ch.settle();
          expect(ch.count, 0);
          await ch.expectBump(() => repo.saveActivity(_a('a1')));
          await ch.expectBump(() => repo.deleteActivity('a1'));
        } finally {
          await ch.cancel();
        }
      },
    );
  });
}
