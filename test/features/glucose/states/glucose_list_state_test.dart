import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/contract/glucose_errors.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/states/glucose_list_state.dart';
import 'package:hmm_console/features/glucose/states/glucose_providers.dart';

import '../support/fake_glucose_repository.dart';

final _now = DateTime(2026, 11, 22, 10);

/// Counts reads; while [gate] is set, each read waits for it.
class _GatedRepo extends FakeGlucoseRepository {
  int reads = 0;
  Completer<void>? gate;

  @override
  Future<List<GlucoseReading>> readingsBetween(
    DateTime from,
    DateTime to,
  ) async {
    reads++;
    final g = gate;
    if (g != null) await g.future;
    return super.readingsBetween(from, to);
  }
}

GlucoseReading _r(String id, OffsetDateTime at) => GlucoseReading(
  id: id,
  takenAt: at,
  glucose: const GlucoseValue(110, GlucoseUnit.mgdl),
);

OffsetDateTime _local(int m, int d, int h) =>
    OffsetDateTime.fromLocal(DateTime(2026, m, d, h));

ProviderContainer _container(FakeGlucoseRepository repo) {
  final c = ProviderContainer(
    overrides: [
      glucoseRepositoryProvider.overrideWithValue(repo),
      glucoseClockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('groups by the reading\'s own wall date, newest first', () async {
    // 23:30 on 20 Nov at -05:00 is 21 Nov in UTC but stays on 20 Nov.
    final travel = OffsetDateTime.tryParse('2026-11-20T23:30:00-05:00')!;
    final c = _container(
      FakeGlucoseRepository([
        _r('a', _local(11, 22, 8)),
        _r('b', _local(11, 22, 7)),
        _r('c', travel),
      ]),
    );
    final data = await c.read(glucoseListProvider.future);
    expect(data.today, DateTime.utc(2026, 11, 22));
    expect(data.days.map((d) => d.date), [
      DateTime.utc(2026, 11, 22),
      DateTime.utc(2026, 11, 20),
    ]);
    expect(data.days.first.readings.map((r) => r.id), ['a', 'b']);
    expect(data.days.last.readings.single.id, 'c');
  });

  test('reaches back 90 days and no further', () async {
    final c = _container(
      FakeGlucoseRepository([
        _r(
          'in',
          OffsetDateTime.fromLocal(_now.subtract(const Duration(days: 89))),
        ),
        _r(
          'out',
          OffsetDateTime.fromLocal(_now.subtract(const Duration(days: 91))),
        ),
      ]),
    );
    final data = await c.read(glucoseListProvider.future);
    expect([for (final d in data.days) ...d.readings.map((r) => r.id)], ['in']);
  });

  test('a burst of changes during a reload costs one more read', () async {
    final repo = _GatedRepo();
    final c = _container(repo);
    final sub = c.listen(glucoseListProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(glucoseListProvider.future);
    final before = repo.reads;

    repo.gate = Completer<void>();
    for (var i = 0; i < 50; i++) {
      await repo.saveReading(_r('r$i', _local(11, 22, 8)));
    }
    await Future<void>.delayed(Duration.zero);
    repo.gate!.complete();
    repo.gate = null;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(repo.reads - before, 2);
    expect(
      c.read(glucoseListProvider).requireValue.days.single.readings,
      hasLength(50),
    );
  });

  test('refreshes when the repository changes', () async {
    final repo = FakeGlucoseRepository();
    final c = _container(repo);
    final sub = c.listen(glucoseListProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(glucoseListProvider.future)).isEmpty, isTrue);

    await repo.saveReading(_r('a', _local(11, 22, 8)));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(glucoseListProvider).requireValue.days, hasLength(1));
  });

  test('cloud API mode fails with the unavailable error', () async {
    final c = ProviderContainer(
      overrides: [
        glucoseRepositoryProvider.overrideWith(
          (ref) => throw GlucoseCloudApiUnavailable(),
        ),
        glucoseClockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(glucoseListProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      c.read(glucoseListProvider.future),
      throwsA(predicate((Object e) => isGlucoseCloudApiUnavailable(e))),
    );
  });
}
