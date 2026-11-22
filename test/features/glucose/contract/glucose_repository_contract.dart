import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/contract/i_glucose_repository.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';

GlucoseReading _r(String id, {DateTime? at, num value = 112}) => GlucoseReading(
  id: id,
  takenAt: OffsetDateTime(at ?? DateTime.utc(2026, 11, 21, 12), Duration.zero),
  glucose: GlucoseValue(value, GlucoseUnit.mgdl),
  context: GlucoseContext.fasting,
  notes: 'a note',
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

/// The contract every [IGlucoseRepository] must satisfy. [create] must
/// return a fresh, empty store.
void runGlucoseRepositoryContract(
  Future<IGlucoseRepository> Function() create,
) {
  group('IGlucoseRepository contract', () {
    late IGlucoseRepository repo;
    setUp(() async => repo = await create());

    test('save then get returns the same fields, whole-second stamp', () async {
      final saved = await repo.saveReading(_r('g1'));
      final got = await repo.getReading('g1');
      expect(got, isNotNull);
      expect(got!.takenAt, saved.takenAt);
      expect(got.glucose.value, 112);
      expect(got.glucose.unit, GlucoseUnit.mgdl);
      expect(got.context, GlucoseContext.fasting);
      expect(got.notes, 'a note');
      expect(got.updatedAt, isNotNull);
      expect(got.updatedAt!.isUtc, isTrue);
      expect(got.updatedAt!.millisecond, 0);
      expect(got.updatedAt, saved.updatedAt);
    });

    test('getReading of an unknown id is null', () async {
      expect(await repo.getReading('nope'), isNull);
    });

    test('saving the same id twice updates, never duplicates', () async {
      await repo.saveReading(_r('g1'));
      await repo.saveReading(_r('g1', value: 130));
      final all = await repo.readingsBetween(_from, _to);
      expect(all, hasLength(1));
      expect(all.single.glucose.value, 130);
    });

    test(
      'readingsBetween is [from, to) by takenAt.utc, newest first',
      () async {
        await repo.saveReading(
          _r('before', at: DateTime.utc(2026, 10, 31, 23)),
        );
        await repo.saveReading(_r('atFrom', at: _from));
        await repo.saveReading(_r('mid', at: DateTime.utc(2026, 11, 15)));
        await repo.saveReading(_r('late', at: DateTime.utc(2026, 11, 30, 23)));
        await repo.saveReading(_r('atTo', at: _to));
        final got = await repo.readingsBetween(_from, _to);
        expect(got.map((r) => r.id), ['late', 'mid', 'atFrom']);
      },
    );

    test('delete then get is null; deleting a missing id is a no-op', () async {
      await repo.deleteReading('ghost');
      await repo.saveReading(_r('g1'));
      await repo.deleteReading('g1');
      expect(await repo.getReading('g1'), isNull);
      await repo.deleteReading('g1');
    });

    test('delete then save the same id leaves exactly one', () async {
      await repo.saveReading(_r('g1'));
      await repo.deleteReading('g1');
      expect(await repo.readingsBetween(_from, _to), isEmpty);
      await repo.saveReading(_r('g1'));
      final all = await repo.readingsBetween(_from, _to);
      expect(all, hasLength(1));
      expect(all.single.id, 'g1');
    });

    test('saving a deleted id restores it', () async {
      await repo.saveReading(_r('g1'));
      await repo.deleteReading('g1');
      await repo.saveReading(_r('g1', value: 99));
      expect((await repo.getReading('g1'))!.glucose.value, 99);
    });

    test(
      'existsIncludingDeleted: false unknown, true live and deleted',
      () async {
        expect(await repo.existsIncludingDeleted('g1'), isFalse);
        await repo.saveReading(_r('g1'));
        expect(await repo.existsIncludingDeleted('g1'), isTrue);
        await repo.deleteReading('g1');
        expect(await repo.getReading('g1'), isNull);
        expect(await repo.existsIncludingDeleted('g1'), isTrue);
      },
    );

    test('saveReadings stores every reading and emits a change', () async {
      await repo.saveReading(_r('seed'));
      final ch = _Changes(repo.changes());
      try {
        await ch.expectBump(
          () => repo.saveReadings([_r('b1'), _r('b2', value: 140)]),
        );
        expect((await repo.getReading('b1'))!.glucose.value, 112);
        expect((await repo.getReading('b2'))!.glucose.value, 140);
        expect(await repo.readingsBetween(_from, _to), hasLength(3));
      } finally {
        await ch.cancel();
      }
    });

    test('saveReadings of an empty list is a no-op', () async {
      await repo.saveReadings(const []);
      expect(await repo.readingsBetween(_from, _to), isEmpty);
    });

    test(
      'changes() is quiet on subscribe, emits after save and delete',
      () async {
        await repo.saveReading(_r('seed'));
        final ch = _Changes(repo.changes());
        try {
          await ch.settle();
          expect(ch.count, 0);
          await ch.expectBump(() => repo.saveReading(_r('g1')));
          await ch.expectBump(() => repo.deleteReading('g1'));
        } finally {
          await ch.cancel();
        }
      },
    );
  });
}
