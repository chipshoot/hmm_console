import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/activity/contract/activity_errors.dart';
import 'package:hmm_console/features/activity/data/local_activity_repository.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/states/activity_providers.dart';

import '../../contacts/data/contact_repository_fakes.dart';
import '../contract/activity_repository_contract.dart';

late HmmDatabase _db;
late LocalHmmNoteRepository _notes;
late LocalNoteCatalogRepository _catalogs;

Future<LocalActivityRepository> _make() async {
  _db = HmmDatabase(NativeDatabase.memory());
  final authorId = await _db
      .into(_db.authors)
      .insert(AuthorsCompanion.insert(accountName: 'tester'));
  final author = await (_db.select(
    _db.authors,
  )..where((a) => a.id.equals(authorId))).getSingle();
  _notes = LocalHmmNoteRepository(_db, () async => author);
  _catalogs = LocalNoteCatalogRepository(_db);
  return LocalActivityRepository(_notes, _catalogs);
}

Activity _act(String id) => Activity(
  id: id,
  kind: 'health.walk',
  start: OffsetDateTime(DateTime.utc(2026, 11, 21, 12), Duration.zero),
  durationMinutes: 20,
);

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

void main() {
  tearDown(() async => _db.close());

  runActivityRepositoryContract(_make);

  group('LocalActivityRepository', () {
    late LocalActivityRepository repo;
    setUp(() async => repo = await _make());

    Future<int> catalogId() async => (await _catalogs.getOrCreateCatalog(
      activityCatalogName,
      '{"type":"activity"}',
    )).id;

    test('stores the subject as Activity:<id>', () async {
      await repo.saveActivity(_act('a1'));
      final n = (await _notes.getNoteByUuid('a1'))!;
      expect(n.subject, 'Activity:a1');
      expect(n.subject, activitySubjectFor('a1'));
    });

    test('a bad JSON note is skipped in lists and throws on get', () async {
      await repo.saveActivity(_act('good'));
      await _notes.createNote(
        HmmNoteCreate(
          subject: 'Activity:bad',
          catalogId: await catalogId(),
          content: '{bad',
          uuid: 'bad',
        ),
      );
      final got = await repo.activitiesBetween(
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 12, 1),
      );
      expect(got.map((a) => a.id), ['good']);
      await expectLater(
        repo.getActivity('bad'),
        throwsA(isA<ActivityUnreadable>()),
      );
    });

    test('an id owned by another catalog throws ActivityIdCollision', () async {
      final other = await _catalogs.getOrCreateCatalog('Hmm.Other', '{}');
      await _notes.createNote(
        HmmNoteCreate(
          subject: 'Mine',
          catalogId: other.id,
          content: 'keep me',
          uuid: 'shared',
        ),
      );
      await expectLater(
        repo.saveActivity(_act('shared')),
        throwsA(isA<ActivityIdCollision>()),
      );
      expect((await _notes.getNoteByUuid('shared'))!.content, 'keep me');
    });
  });

  group('activityRepositoryProvider', () {
    ProviderContainer c(DataMode m) => ProviderContainer(
      overrides: [
        dataModeProvider.overrideWith(() => _Mode(m)),
        localActivityRepositoryProvider.overrideWithValue(
          LocalActivityRepository(
            FakeNoteRepository(),
            FakeCatalogRepository(),
          ),
        ),
      ],
    );

    test('local and cloudStorage resolve the local repository', () {
      for (final m in [DataMode.local, DataMode.cloudStorage]) {
        final k = c(m);
        addTearDown(k.dispose);
        expect(
          k.read(activityRepositoryProvider),
          isA<LocalActivityRepository>(),
        );
      }
    });

    test('cloudApi throws ActivityCloudApiUnavailable', () {
      final k = c(DataMode.cloudApi);
      addTearDown(k.dispose);
      Object? caught;
      try {
        k.read(activityRepositoryProvider);
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(isActivityCloudApiUnavailable(caught!), isTrue);
    });
  });
}
