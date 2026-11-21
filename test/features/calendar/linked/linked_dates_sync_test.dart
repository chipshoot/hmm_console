import 'dart:async';
import 'dart:ui';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/auth/current_author_account_name_provider.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/i18n/app_localizations_now.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/data/local_calendar_repository.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/linked/linked_dates_matcher.dart';
import 'package:hmm_console/features/calendar/linked/dated_note_sources_provider.dart';
import 'package:hmm_console/features/calendar/linked/linked_dates_sync.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

Future<LocalCalendarRepository> _make() async {
  final db = HmmDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final authorId = await db
      .into(db.authors)
      .insert(AuthorsCompanion.insert(accountName: 'tester'));
  final author = await (db.select(
    db.authors,
  )..where((a) => a.id.equals(authorId))).getSingle();
  return LocalCalendarRepository(
    LocalHmmNoteRepository(db, () async => author),
    LocalNoteCatalogRepository(db),
  );
}

class _Note implements DatedNote {
  _Note(this.dates);
  @override
  final List<DatedItem> dates;
}

class _Source implements DatedNoteSource {
  _Source(this.items);
  final List<DatedItem> items;
  bool fail = false;
  @override
  Set<String> get subsystems => {'driverLicence'};
  @override
  Future<List<DatedNote>> datedNotes() async {
    if (fail) throw StateError('boom');
    return [_Note(items)];
  }

  @override
  Future<String?> locationOf(EventOwner owner) async => null;
}

class _FakeController extends ChangeNotifier {
  bool syncing = false;
  bool busy = false;
  void notify() => notifyListeners();
  Future<T?> runExclusive<T>(Future<T> Function() body) async {
    if (syncing || busy) return null;
    busy = true;
    try {
      return await body();
    } finally {
      busy = false;
    }
  }
}

class _LocalMode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.local;
}

class _CountingSource implements DatedNoteSource {
  int calls = 0;
  @override
  Set<String> get subsystems => {'driverLicence'};
  @override
  Future<List<DatedNote>> datedNotes() async {
    calls++;
    return const [];
  }

  @override
  Future<String?> locationOf(EventOwner owner) async => null;
}

final _en = lookupAppLocalizations(const Locale('en'));

DatedItem _licence() => const DatedItem(
  key: 'licence:expiry',
  kind: LinkedKind.licenceExpiry,
  args: {},
  date: AllDay(2027, 3, 14),
  owner: EventOwner(subsystem: 'driverLicence', noteUuid: 'self'),
);

LinkedDatesSync _sync(
  LocalCalendarRepository repo,
  _FakeController c,
  List<DatedNoteSource> sources, {
  bool cloudApi = false,
  Stream<void> notes = const Stream.empty(),
  Duration debounce = const Duration(milliseconds: 20),
  bool Function()? waitingForFirstSync,
  bool Function()? lastSyncFailed,
}) => LinkedDatesSync(
  sources: () => sources,
  matcher: () => LinkedDatesMatcher(repo, l: _en),
  isCloudApi: () => cloudApi,
  noteChanges: () => notes,
  syncEvents: c,
  isSyncing: () => c.syncing,
  runExclusive: c.runExclusive,
  debounce: debounce,
  waitingForFirstSync: waitingForFirstSync ?? () => false,
  lastSyncFailed: lastSyncFailed ?? () => false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final id = linkedEventId('licence:expiry');

  test('runs the matcher over every source', () async {
    final repo = await _make();
    final sync = _sync(repo, _FakeController(), [
      _Source([_licence()]),
    ]);
    expect(await sync.runNow(), const MatchResult(1, 0, 0));
    expect(await repo.getEvent(id), isNotNull);
    sync.dispose();
  });

  test('a throwing source leaves existing linked events alone', () async {
    final repo = await _make();
    final ok = _Source([_licence()]);
    await _sync(repo, _FakeController(), [ok]).runNow();
    ok.fail = true;
    final result = await _sync(repo, _FakeController(), [ok]).runNow();
    expect(result, isNull);
    expect(await repo.getEvent(id), isNotNull);
  });

  test('no run while a sync is in progress', () async {
    final repo = await _make();
    final c = _FakeController()..syncing = true;
    final sync = _sync(repo, c, [
      _Source([_licence()]),
    ]);
    expect(await sync.runNow(), isNull);
    expect(await repo.getEvent(id), isNull);

    c.syncing = false;
    sync.start();
    // start() triggers once; let the debounce and the run finish.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await repo.getEvent(id), isNotNull);
    sync.dispose();
  });

  test('a finished sync triggers a run, a running one does not', () async {
    final repo = await _make();
    final c = _FakeController();
    final sync = _sync(repo, c, [
      _Source([_licence()]),
    ])..start();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await repo.deleteEvent(id);
    c.syncing = true;
    c.notify();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await repo.getEvent(id), isNull);
    c.syncing = false;
    c.notify();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await repo.getEvent(id), isNotNull);
    sync.dispose();
  });

  test('cloud API mode does nothing', () async {
    final repo = await _make();
    final sync = _sync(repo, _FakeController(), [
      _Source([_licence()]),
    ], cloudApi: true);
    expect(await sync.runNow(), isNull);
    expect(await repo.getEvent(id), isNull);
  });

  test('bursts of note changes run once', () {
    fakeAsync((async) {
      var runs = 0;
      final c = _FakeController();
      final sync = LinkedDatesSync(
        sources: () => const [],
        matcher: () {
          runs++;
          throw StateError('stop after counting');
        },
        isCloudApi: () => false,
        noteChanges: () => const Stream.empty(),
        syncEvents: c,
        isSyncing: () => false,
        runExclusive: c.runExclusive,
      );
      for (var i = 0; i < 5; i++) {
        sync.trigger();
        async.elapse(const Duration(milliseconds: 200));
      }
      expect(runs, 0);
      async.elapse(const Duration(milliseconds: 2100));
      expect(runs, 1);
      sync.dispose();
    });
  });

  test('a note change triggers a run', () async {
    final repo = await _make();
    final notes = StreamController<void>();
    addTearDown(notes.close);
    final sync = _sync(repo, _FakeController(), [
      _Source([_licence()]),
    ], notes: notes.stream)..start();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await repo.deleteEvent(id);
    notes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await repo.getEvent(id), isNotNull);
    sync.dispose();
  });

  test('app resume triggers a run', () async {
    final repo = await _make();
    final sync = _sync(repo, _FakeController(), [
      _Source([_licence()]),
    ]);
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await repo.getEvent(id), isNotNull);
    sync.dispose();
  });

  test('a run skipped by the lock is retried once', () async {
    final repo = await _make();
    final c = _FakeController();
    var calls = 0;
    final sync = LinkedDatesSync(
      sources: () => [
        _Source([_licence()]),
      ],
      matcher: () => LinkedDatesMatcher(repo, l: _en),
      isCloudApi: () => false,
      noteChanges: () => const Stream.empty(),
      syncEvents: c,
      isSyncing: () => false,
      runExclusive: <T>(body) async {
        calls++;
        return calls == 1 ? null : c.runExclusive<T>(body);
      },
      debounce: const Duration(milliseconds: 20),
    );
    expect(await sync.runNow(), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(calls, 2);
    expect(await repo.getEvent(id), isNotNull);
    sync.dispose();
  });

  test('a notes watch that errors is re-attached and still triggers', () async {
    final repo = await _make();
    final source = _Source([_licence()])..fail = true;
    final second = StreamController<void>();
    addTearDown(second.close);
    var attaches = 0;
    final sync = LinkedDatesSync(
      sources: () => [source],
      matcher: () => LinkedDatesMatcher(repo, l: _en),
      isCloudApi: () => false,
      noteChanges: () => ++attaches == 1
          ? Stream<void>.error(StateError('no author yet'))
          : second.stream,
      syncEvents: _FakeController(),
      isSyncing: () => false,
      runExclusive: _FakeController().runExclusive,
      debounce: const Duration(milliseconds: 20),
      retryDelay: const Duration(milliseconds: 20),
    )..start();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(attaches, 2);
    expect(await repo.getEvent(id), isNull);
    source.fail = false;
    second.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await repo.getEvent(id), isNotNull);
    sync.dispose();
  });

  test('runs wait for the first sync, then the finished sync runs', () async {
    final repo = await _make();
    final c = _FakeController();
    var waiting = true;
    final sync = _sync(repo, c, [
      _Source([_licence()]),
    ], waitingForFirstSync: () => waiting)..start();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await sync.runNow(), isNull);
    expect(await repo.getEvent(id), isNull);
    waiting = false;
    c.notify();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(await repo.getEvent(id), isNotNull);
    sync.dispose();
  });

  test('after a failed sync nothing is removed', () async {
    final repo = await _make();
    final source = _Source([_licence()]);
    var failed = false;
    final sync = _sync(repo, _FakeController(), [
      source,
    ], lastSyncFailed: () => failed);
    await sync.runNow();
    source.items.clear();
    failed = true;
    expect(await sync.runNow(), const MatchResult(0, 0, 0));
    expect(await repo.getEvent(id), isNotNull);
    failed = false;
    expect(await sync.runNow(), const MatchResult(0, 0, 1));
    sync.dispose();
  });

  test('the provider runs once the current author is ready', () async {
    final repo = await _make();
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final controller = SyncController(
      syncAction: () async {
        throw StateError('not exercised');
      },
    );
    addTearDown(controller.dispose);
    final author = Completer<Author>();
    final source = _CountingSource();
    final container = ProviderContainer(
      overrides: [
        dataModeProvider.overrideWith(_LocalMode.new),
        syncOrchestratorProvider.overrideWithValue(
          SyncOrchestrator(
            provider: null,
            db: db,
            meta: SyncMetaRepository(),
            vaultStore: () async => throw UnimplementedError(),
          ),
        ),
        syncControllerProvider.overrideWithValue(controller),
        currentAuthorProvider.overrideWith((ref) => author.future),
        datedNoteSourcesProvider.overrideWithValue([source]),
        calendarRepositoryProvider.overrideWithValue(repo),
        appLocalizationsNowProvider.overrideWithValue(_en),
      ],
    );
    addTearDown(container.dispose);
    // Not started, so only the author becoming ready can cause a run.
    container.read(linkedDatesSyncProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    author.complete(
      const Author(id: 1, accountName: 'tester', role: 0, isActivated: true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    expect(source.calls, 1);
  });
}
