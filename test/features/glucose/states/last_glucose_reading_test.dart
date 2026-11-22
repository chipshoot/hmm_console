import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/states/glucose_list_state.dart';
import 'package:hmm_console/features/glucose/states/glucose_providers.dart';
import 'package:hmm_console/features/glucose/states/last_glucose_reading.dart';

import '../support/fake_glucose_repository.dart';

final _now = DateTime(2026, 11, 22, 10);

/// Counts reads; while [gate] is set, each read waits for it.
class _GatedRepo extends FakeGlucoseRepository {
  _GatedRepo([super.seed]);
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

GlucoseReading _r(String id, DateTime at, num v) => GlucoseReading(
  id: id,
  takenAt: OffsetDateTime.fromLocal(at),
  glucose: GlucoseValue(v, GlucoseUnit.mmoll),
);

class _Mode extends DataModeNotifier {
  _Mode(this.mode);
  final DataMode mode;
  @override
  DataMode build() => mode;
}

class _ErroringRepo extends FakeGlucoseRepository {
  _ErroringRepo(super.seed);
  final errors = StreamController<void>.broadcast();
  @override
  Stream<void> changes() => errors.stream;
}

ProviderContainer _c(
  FakeGlucoseRepository repo, {
  DataMode mode = DataMode.local,
}) {
  final c = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _Mode(mode)),
      localGlucoseRepositoryProvider.overrideWithValue(repo),
      glucoseClockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('is the newest reading', () async {
    final c = _c(
      FakeGlucoseRepository([
        _r('a', DateTime(2026, 11, 21, 8), 5.0),
        _r('b', DateTime(2026, 11, 22, 8), 6.2),
      ]),
    );
    expect((await c.read(lastGlucoseReadingProvider.future))?.id, 'b');
  });

  test('is null with no readings', () async {
    final c = _c(FakeGlucoseRepository());
    expect(await c.read(lastGlucoseReadingProvider.future), isNull);
  });

  test('is null in Cloud API mode', () async {
    final c = _c(FakeGlucoseRepository(), mode: DataMode.cloudApi);
    expect(await c.read(lastGlucoseReadingProvider.future), isNull);
  });

  test('refreshes when the repository changes', () async {
    final repo = FakeGlucoseRepository([
      _r('a', DateTime(2026, 11, 21, 8), 5.0),
    ]);
    final c = _c(repo);
    c.listen(lastGlucoseReadingProvider, (_, _) {});
    expect((await c.read(lastGlucoseReadingProvider.future))?.id, 'a');
    await repo.saveReading(_r('b', DateTime(2026, 11, 22, 9), 7.1));
    await Future<void>.delayed(Duration.zero);
    expect((await c.read(lastGlucoseReadingProvider.future))?.id, 'b');
  });

  test('a burst of changes during a read costs one more read', () async {
    final repo = _GatedRepo([_r('a', DateTime(2026, 11, 21, 8), 5.0)]);
    final c = _c(repo);
    c.listen(lastGlucoseReadingProvider, (_, _) {});
    await c.read(lastGlucoseReadingProvider.future);
    final before = repo.reads;

    repo.gate = Completer<void>();
    for (var i = 0; i < 50; i++) {
      await repo.saveReading(_r('r$i', DateTime(2026, 11, 22, 1 + i % 8), 6));
    }
    await Future<void>.delayed(Duration.zero);
    repo.gate!.complete();
    repo.gate = null;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(repo.reads - before, 2);
    expect(c.read(lastGlucoseReadingProvider).value?.id, isNot('a'));
  });

  test('a failing change stream keeps the value', () async {
    final repo = _ErroringRepo([_r('a', DateTime(2026, 11, 21, 8), 5.0)]);
    final c = _c(repo);
    c.listen(lastGlucoseReadingProvider, (_, _) {});
    expect((await c.read(lastGlucoseReadingProvider.future))?.id, 'a');
    repo.errors.addError(StateError('boom'));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(lastGlucoseReadingProvider).value?.id, 'a');
  });
}
