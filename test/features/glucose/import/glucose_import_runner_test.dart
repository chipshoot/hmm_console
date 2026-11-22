import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/import/glucose_import_runner.dart';
import 'package:hmm_console/features/glucose/import/glucose_importer.dart';
import 'package:hmm_console/features/glucose/import/glucose_sample_source.dart';
import 'package:hmm_console/features/glucose/states/glucose_settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_glucose_repository.dart';
import '../support/fake_glucose_sample_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGlucoseRepository repo;
  late FakeGlucoseSampleSource source;
  late GlucoseImportPrefs prefs;
  late DateTime clock;
  late int importerBuilds;

  bool ios = true;
  bool cloudApi = false;
  bool onDevice = true;
  bool waiting = false;
  bool syncing = false;
  late ChangeNotifier syncEvents;

  Future<T?> exclusive<T>(Future<T> Function() body) async => body();

  GlucoseImportRunner make() {
    final runner = GlucoseImportRunner(
      importer: () {
        importerBuilds++;
        return GlucoseImporter(
          repo: repo,
          source: source,
          prefs: prefs,
          now: () => clock,
          runExclusive: exclusive,
          toOffset: (u) => OffsetDateTime(u, Duration.zero),
        );
      },
      prefs: prefs,
      isIOS: () => ios,
      isCloudApi: () => cloudApi,
      importOnDevice: () async => onDevice,
      waitingForFirstSync: () => waiting,
      syncEvents: syncEvents,
      isSyncing: () => syncing,
      now: () => clock,
    );
    addTearDown(runner.dispose);
    return runner;
  }

  /// Lets the start/resume run (async, not awaited) finish.
  Future<void> settle() => Future<void>.delayed(
    Duration.zero,
  ).then((_) => Future<void>.delayed(const Duration(milliseconds: 10)));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeGlucoseRepository();
    source = FakeGlucoseSampleSource([
      GlucoseSample(
        sampleId: 'A',
        instantUtc: DateTime.utc(2026, 11, 1),
        mgdl: 100,
      ),
    ]);
    prefs = GlucoseImportPrefs();
    clock = DateTime.utc(2026, 11, 22, 12);
    importerBuilds = 0;
    ios = true;
    cloudApi = false;
    onDevice = true;
    waiting = false;
    syncing = false;
    syncEvents = ChangeNotifier();
  });

  group('automatic run is skipped when a gate fails', () {
    setUp(() async => prefs.markImportedOnce());

    for (final (name, fail) in <(String, void Function())>[
      ('not iOS', () => ios = false),
      ('Cloud API', () => cloudApi = true),
      ('setting off', () => onDevice = false),
      ('waiting for first sync', () => waiting = true),
    ]) {
      test(name, () async {
        fail();
        make().start();
        await settle();
        expect(source.windows, isEmpty);
        expect(importerBuilds, 0);
      });
    }

    test('first import not done', () async {
      SharedPreferences.setMockInitialValues({});
      make().start();
      await settle();
      expect(source.windows, isEmpty);
    });
  });

  test('runs on start when every gate passes', () async {
    await prefs.markImportedOnce();
    final runner = make()..start();
    await settle();

    expect(source.windows, hasLength(1));
    expect(source.accessRequests, 0);
    expect(runner.lastResult.value?.added, 1);
  });

  test('resume runs at most once every 15 minutes', () async {
    await prefs.markImportedOnce();
    final runner = make()..start();
    await settle();
    expect(source.windows, hasLength(1));

    clock = clock.add(const Duration(minutes: 10));
    runner.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(source.windows, hasLength(1));

    clock = clock.add(const Duration(minutes: 6));
    runner.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(source.windows, hasLength(2));
  });

  test('a start held back by the first sync runs once it finishes', () async {
    await prefs.markImportedOnce();
    waiting = true;
    make().start();
    await settle();
    expect(source.windows, isEmpty);

    waiting = false;
    syncEvents.notifyListeners();
    await settle();
    expect(source.windows, hasLength(1));

    // Later syncs do not trigger more runs.
    clock = clock.add(const Duration(hours: 1));
    syncEvents.notifyListeners();
    await settle();
    expect(source.windows, hasLength(1));
  });

  test('importNow runs before the first import and asks for access', () async {
    final runner = make()..start();
    await settle();
    expect(source.windows, isEmpty);

    final result = await runner.importNow();

    expect(result, isNotNull);
    expect(result!.added, 1);
    expect(source.accessRequests, 1);
    expect(runner.lastResult.value, same(result));
    expect(await prefs.importedOnce(), isTrue);
  });

  test('importNow ignores the 15-minute throttle', () async {
    await prefs.markImportedOnce();
    final runner = make()..start();
    await settle();

    final result = await runner.importNow();

    expect(result, isNotNull);
    expect(source.windows, hasLength(2));
  });

  test('importNow returns null in Cloud API mode', () async {
    cloudApi = true;
    final runner = make();

    expect(await runner.importNow(), isNull);
    expect(importerBuilds, 0);
    expect(source.accessRequests, 0);
  });

  test('importNow returns null when another gate fails', () async {
    onDevice = false;
    expect(await make().importNow(), isNull);
    onDevice = true;
    ios = false;
    expect(await make().importNow(), isNull);
    expect(source.windows, isEmpty);
  });
}
