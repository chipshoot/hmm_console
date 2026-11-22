import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/states/glucose_edit_state.dart';
import 'package:hmm_console/features/glucose/states/glucose_list_state.dart';
import 'package:hmm_console/features/glucose/states/glucose_providers.dart';
import 'package:hmm_console/features/glucose/states/glucose_settings_providers.dart';

import '../support/fake_glucose_repository.dart';

class _Unit extends GlucoseDisplayUnitNotifier {
  @override
  GlucoseUnit build() => GlucoseUnit.mmoll;
}

final _now = DateTime(2026, 11, 22, 10, 30, 45);

ProviderContainer _container(FakeGlucoseRepository repo) {
  final c = ProviderContainer(
    // Riverpod retries a failed load; the error should surface at once.
    retry: (_, _) => null,
    overrides: [
      glucoseRepositoryProvider.overrideWithValue(repo),
      glucoseClockProvider.overrideWithValue(() => _now),
      glucoseDisplayUnitProvider.overrideWith(_Unit.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

GlucoseReading _imported() => GlucoseReading(
  id: 'imp',
  takenAt: OffsetDateTime(
    DateTime.utc(2026, 11, 20, 12, 41),
    const Duration(hours: -5),
  ),
  glucose: const GlucoseValue(112, GlucoseUnit.mgdl),
  source: GlucoseSource.appleHealth,
  appleHealth: const AppleHealthRef(
    sampleId: 'S1',
    sourceName: 'CONTOUR DIABETES',
  ),
);

void main() {
  test('a new form starts at the display unit and whole-minute now', () async {
    final c = _container(FakeGlucoseRepository());
    final s = await c.read(glucoseEditProvider(null).future);
    expect(s.unit, GlucoseUnit.mmoll);
    expect(s.at, DateTime(2026, 11, 22, 10, 30));
    expect(s.canSave, isFalse);
  });

  test('validation is in the typed unit', () async {
    final c = _container(FakeGlucoseRepository());
    final n = c.read(glucoseEditProvider(null).notifier);
    await c.read(glucoseEditProvider(null).future);
    n.setUnit(GlucoseUnit.mgdl);
    n.setValueText('650');
    expect(c.read(glucoseEditProvider(null)).value!.valueOutOfRange, isTrue);
    expect(c.read(glucoseEditProvider(null)).value!.canSave, isFalse);
    n.setValueText('6,2');
    expect(c.read(glucoseEditProvider(null)).value!.valueOutOfRange, isTrue);
    n.setUnit(GlucoseUnit.mmoll);
    expect(c.read(glucoseEditProvider(null)).value!.canSave, isTrue);
  });

  test(
    'saving a new reading stores value, manual source, picked time',
    () async {
      final repo = FakeGlucoseRepository();
      final c = _container(repo);
      final n = c.read(glucoseEditProvider(null).notifier);
      await c.read(glucoseEditProvider(null).future);
      n.setValueText('6.2');
      final picked = DateTime(2026, 11, 21, 7, 41);
      n.setAt(picked);
      final saved = await n.save();
      final stored = await repo.getReading(saved.id);
      expect(stored!.glucose, const GlucoseValue(6.2, GlucoseUnit.mmoll));
      expect(stored.source, GlucoseSource.manual);
      expect(stored.takenAt, OffsetDateTime.fromLocal(picked));
      expect(stored.context, isNull);
    },
  );

  test('clearing the tag stores no context', () async {
    final repo = FakeGlucoseRepository();
    final c = _container(repo);
    final n = c.read(glucoseEditProvider(null).notifier);
    await c.read(glucoseEditProvider(null).future);
    n.setValueText('6.2');
    n.setContext(GlucoseContext.fasting);
    n.setContext(null);
    final saved = await n.save();
    expect((await repo.getReading(saved.id))!.context, isNull);
  });

  test('an imported reading changes only tag and notes', () async {
    final o = _imported();
    final repo = FakeGlucoseRepository([o]);
    final c = _container(repo);
    final n = c.read(glucoseEditProvider('imp').notifier);
    final s = await c.read(glucoseEditProvider('imp').future);
    expect(s.isImported, isTrue);
    expect(s.canSave, isTrue);
    n.setValueText('300');
    n.setAt(DateTime(2020));
    n.setContext(GlucoseContext.afterMeal);
    n.setNotes('late lunch');
    await n.save();
    final r = (await repo.getReading('imp'))!;
    expect(r.context, GlucoseContext.afterMeal);
    expect(r.notes, 'late lunch');
    expect(r.glucose, o.glucose);
    expect(r.takenAt, o.takenAt);
    expect(r.appleHealth, o.appleHealth);
    expect(r.source, GlucoseSource.appleHealth);
  });

  test(
    'a manual edit keeps the recorded offset when only time changes',
    () async {
      final o = GlucoseReading(
        id: 'm',
        takenAt: OffsetDateTime(
          DateTime.utc(2026, 11, 20, 12, 41),
          const Duration(hours: -5),
        ),
        glucose: const GlucoseValue(6.2, GlucoseUnit.mmoll),
      );
      final repo = FakeGlucoseRepository([o]);
      final c = _container(repo);
      final n = c.read(glucoseEditProvider('m').notifier);
      final s = await c.read(glucoseEditProvider('m').future);
      expect(s.at, DateTime(2026, 11, 20, 7, 41));
      n.setAt(DateTime(2026, 11, 20, 8, 5));
      await n.save();
      final r = (await repo.getReading('m'))!;
      expect(r.takenAt.offset, const Duration(hours: -5));
      expect(r.takenAt.utc, DateTime.utc(2026, 11, 20, 13, 5));
      expect(r.glucose, o.glucose);
    },
  );

  test('a missing reading fails to load', () async {
    final c = _container(FakeGlucoseRepository());
    // Keep the auto-disposed provider alive while it loads.
    c.listen(glucoseEditProvider('nope'), (_, _) {});
    await expectLater(
      c.read(glucoseEditProvider('nope').future),
      throwsA(isA<GlucoseMissing>()),
    );
  });
}
