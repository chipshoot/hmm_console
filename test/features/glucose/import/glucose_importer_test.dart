import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/data/glucose_codec.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/import/glucose_importer.dart';
import 'package:hmm_console/features/glucose/import/glucose_sample_source.dart';
import 'package:hmm_console/features/glucose/states/glucose_settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_glucose_repository.dart';
import '../support/fake_glucose_sample_source.dart';

class _CountingRepo extends FakeGlucoseRepository {
  int saves = 0;

  @override
  Future<GlucoseReading> saveReading(GlucoseReading r) {
    saves++;
    return super.saveReading(r);
  }

  int batches = 0;

  @override
  Future<void> saveReadings(List<GlucoseReading> readings) {
    saves += readings.length;
    if (readings.isNotEmpty) batches++;
    return super.saveReadings(readings);
  }
}

final _now = DateTime.utc(2026, 11, 22, 12);

GlucoseSample _sample(String id, DateTime at, num mgdl, [String? src]) =>
    GlucoseSample(sampleId: id, instantUtc: at, mgdl: mgdl, sourceName: src);

void main() {
  late _CountingRepo repo;
  late FakeGlucoseSampleSource source;
  late GlucoseImportPrefs prefs;
  late int exclusiveCalls;

  Future<T?> runExclusive<T>(Future<T> Function() body) async {
    exclusiveCalls++;
    return body();
  }

  GlucoseImporter importer({
    OffsetDateTime Function(DateTime utc)? toOffset,
    Future<T?> Function<T>(Future<T> Function())? exclusive,
  }) => GlucoseImporter(
    repo: repo,
    source: source,
    prefs: prefs,
    now: () => _now,
    runExclusive: exclusive ?? runExclusive,
    toOffset: toOffset ?? (u) => OffsetDateTime(u, Duration.zero),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _CountingRepo();
    source = FakeGlucoseSampleSource([
      _sample('A', DateTime.utc(2026, 11, 1, 8), 101, 'Contour'),
      _sample('B', DateTime.utc(2026, 11, 2, 8), 154.5, 'Contour'),
      _sample('C', DateTime.utc(2026, 11, 3, 8), 88),
    ]);
    prefs = GlucoseImportPrefs();
    exclusiveCalls = 0;
  });

  test('ids are UUID v5 over appleHealth:<sampleId>', () {
    expect(kGlucoseIdNamespace, '5b6f2c1e-8d3a-4f7b-9e2c-1a4d6b8c0e57');
    final id = glucoseIdForSample('A');
    expect(id, glucoseIdForSample('A'));
    expect(id, isNot(glucoseIdForSample('B')));
    expect(id[14], '5'); // version nibble
  });

  test('first import reads all history and saves every sample', () async {
    final result = await importer().run(manual: true);

    expect(result.error, isNull);
    expect(result.added, 3);
    expect(result.seen, 3);
    expect(source.windows.single, (DateTime.utc(2000), _now));
    expect(source.accessRequests, 1);

    final a = await repo.getReading(glucoseIdForSample('A'));
    expect(a, isNotNull);
    expect(a!.source, GlucoseSource.appleHealth);
    expect(a.glucose, const GlucoseValue(101, GlucoseUnit.mgdl));
    expect(a.appleHealth!.sampleId, 'A');
    expect(a.appleHealth!.sourceName, 'Contour');
    expect(a.context, isNull);
    expect(a.takenAt.utc, DateTime.utc(2026, 11, 1, 8));
    expect(a.updatedAt, isNotNull); // stamped by the repository

    final b = await repo.getReading(glucoseIdForSample('B'));
    expect(b!.glucose.value, 154.5);
    final c = await repo.getReading(glucoseIdForSample('C'));
    expect(c!.appleHealth!.sourceName, isNull);

    expect(await prefs.importedOnce(), isTrue);
    expect(await prefs.lastImportEnd(), _now);
  });

  test('a second run with the same samples adds nothing', () async {
    await importer().run(manual: true);
    final savesAfterFirst = repo.saves;

    final result = await importer().run(manual: false);

    expect(result.added, 0);
    expect(result.error, isNull);
    expect(repo.saves, savesAfterFirst);
  });

  test('a deleted reading stays deleted', () async {
    await importer().run(manual: true);
    await repo.deleteReading(glucoseIdForSample('B'));
    final saves = repo.saves;

    final result = await importer().run(manual: false);

    expect(result.added, 0);
    expect(repo.saves, saves);
    expect(await repo.getReading(glucoseIdForSample('B')), isNull);
  });

  test('an existing reading is not modified', () async {
    final id = glucoseIdForSample('A');
    await repo.saveReading(
      GlucoseReading(
        id: id,
        takenAt: OffsetDateTime(DateTime.utc(2026, 11, 1, 8), Duration.zero),
        glucose: const GlucoseValue(101, GlucoseUnit.mgdl),
        source: GlucoseSource.appleHealth,
        appleHealth: const AppleHealthRef(sampleId: 'A'),
        context: GlucoseContext.afterMeal,
        notes: 'x',
      ),
    );

    final result = await importer().run(manual: true);

    expect(result.added, 2);
    final a = await repo.getReading(id);
    expect(a!.context, GlucoseContext.afterMeal);
    expect(a.notes, 'x');
  });

  test('a later import starts 7 days before the last end', () async {
    await prefs.setLastImportEnd(DateTime.utc(2026, 11, 20));
    await prefs.markImportedOnce();

    await importer().run(manual: false);

    expect(source.windows.single, (DateTime.utc(2026, 11, 13), _now));
    expect(source.accessRequests, 0);
  });

  test('a manual import after the first does not ask for access', () async {
    await prefs.markImportedOnce();
    await prefs.setLastImportEnd(DateTime.utc(2026, 11, 20));

    await importer().run(manual: true);

    expect(source.accessRequests, 0);
  });

  test('a source error leaves the bookkeeping untouched', () async {
    await prefs.setLastImportEnd(DateTime.utc(2026, 11, 20));
    source.error = StateError('health down');

    final result = await importer().run(manual: true);

    expect(result.error, isA<StateError>());
    expect(result.added, 0);
    expect(await prefs.lastImportEnd(), DateTime.utc(2026, 11, 20));
    expect(await prefs.importedOnce(), isFalse);
  });

  test('a held sync lock is an error and advances nothing', () async {
    Future<T?> held<T>(Future<T> Function() body) async => null;

    final result = await importer(exclusive: held).run(manual: true);

    expect(result.error, isA<GlucoseImportBusy>());
    expect(repo.saves, 0);
    expect(await prefs.lastImportEnd(), isNull);
    expect(await prefs.importedOnce(), isFalse);
  });

  test('the same sample listed twice is saved once', () async {
    source.samplesList.add(source.samplesList.first);

    final result = await importer().run(manual: true);

    expect(result.added, 3);
    expect(repo.saves, 3);
  });

  test('Review Focus 1: 250 samples save in chunks under the lock', () async {
    source.samplesList
      ..clear()
      ..addAll([
        for (var i = 0; i < 250; i++)
          _sample('S$i', DateTime.utc(2026, 1, 1).add(Duration(hours: i)), 100),
      ]);

    final result = await importer().run(manual: true);

    expect(result.added, 250);
    expect(repo.saves, 250);
    expect(exclusiveCalls, greaterThanOrEqualTo(3));
  });

  test('250 samples are saved as one batch per chunk', () async {
    source.samplesList
      ..clear()
      ..addAll([
        for (var i = 0; i < 250; i++)
          _sample('S$i', DateTime.utc(2026, 1, 1).add(Duration(hours: i)), 100),
      ]);

    await importer().run(manual: true);

    expect(repo.batches, 3);
  });

  test('an empty first import advances nothing', () async {
    source.samplesList.clear();

    final result = await importer().run(manual: true);

    expect(result.error, isNull);
    expect(result.seen, 0);
    expect(await prefs.lastImportEnd(), isNull);
    expect(await prefs.importedOnce(), isFalse);
  });

  test('after an empty first import, the next reads all history', () async {
    source.samplesList.clear();
    await importer().run(manual: true);

    source.samplesList.add(_sample('OLD', DateTime.utc(2024, 3, 1, 8), 110));
    final result = await importer().run(manual: true);

    expect(source.windows.last, (DateTime.utc(2000), _now));
    expect(source.accessRequests, 2);
    expect(result.added, 1);
    expect(await repo.getReading(glucoseIdForSample('OLD')), isNotNull);
    expect(await prefs.lastImportEnd(), _now);
    expect(await prefs.importedOnce(), isTrue);
  });

  test('Review Focus 2: takenAt keeps the zone offset at the sample', () async {
    source.samplesList
      ..clear()
      ..add(_sample('Z', DateTime.utc(2026, 1, 15, 12), 120));

    await importer(
      toOffset: (u) => OffsetDateTime(u, const Duration(hours: -5)),
    ).run(manual: true);

    final r = await repo.getReading(glucoseIdForSample('Z'));
    expect(r!.takenAt.toIso(), '2026-01-15T07:00:00-05:00');
    expect(
      GlucoseCodec.encode(r),
      contains('"takenAt":"2026-01-15T07:00:00-05:00"'),
    );
  });
}
