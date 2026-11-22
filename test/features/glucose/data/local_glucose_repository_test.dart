import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/contract/glucose_errors.dart';
import 'package:hmm_console/features/glucose/data/local_glucose_repository.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/states/glucose_providers.dart';

import '../../contacts/data/contact_repository_fakes.dart';
import '../contract/glucose_repository_contract.dart';

late HmmDatabase _db;
late LocalHmmNoteRepository _notes;
late LocalNoteCatalogRepository _catalogs;

Future<LocalGlucoseRepository> _make() async {
  _db = HmmDatabase(NativeDatabase.memory());
  final authorId = await _db
      .into(_db.authors)
      .insert(AuthorsCompanion.insert(accountName: 'tester'));
  final author = await (_db.select(
    _db.authors,
  )..where((a) => a.id.equals(authorId))).getSingle();
  _notes = LocalHmmNoteRepository(_db, () async => author);
  _catalogs = LocalNoteCatalogRepository(_db);
  return LocalGlucoseRepository(_notes, _catalogs);
}

GlucoseReading _rd(String id) => GlucoseReading(
  id: id,
  takenAt: OffsetDateTime(DateTime.utc(2026, 11, 21, 12), Duration.zero),
  glucose: const GlucoseValue(112, GlucoseUnit.mgdl),
);

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

void main() {
  tearDown(() async => _db.close());

  runGlucoseRepositoryContract(_make);

  group('LocalGlucoseRepository', () {
    late LocalGlucoseRepository repo;
    setUp(() async => repo = await _make());

    Future<int> catalogId() async => (await _catalogs.getOrCreateCatalog(
      glucoseCatalogName,
      glucoseCatalogSchema,
    )).id;

    test('creates the catalog with the glucoseReading schema', () async {
      await repo.saveReading(_rd('g1'));
      final c = await _catalogs.getCatalogByName(glucoseCatalogName);
      expect(c?.schema, '{"type":"glucoseReading"}');
    });

    test('stores the subject as Glucose:<id>', () async {
      await repo.saveReading(_rd('a1'));
      final n = (await _notes.getNoteByUuid('a1'))!;
      expect(n.subject, 'Glucose:a1');
      expect(n.subject, glucoseSubjectFor('a1'));
    });

    test('a bad JSON note is skipped in lists and throws on get', () async {
      await repo.saveReading(_rd('good'));
      await _notes.createNote(
        HmmNoteCreate(
          subject: 'Glucose:bad',
          catalogId: await catalogId(),
          content: '{bad',
          uuid: 'bad',
        ),
      );
      final got = await repo.readingsBetween(
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 12, 1),
      );
      expect(got.map((r) => r.id), ['good']);
      await expectLater(
        repo.getReading('bad'),
        throwsA(isA<GlucoseUnreadable>()),
      );
    });

    test('existsIncludingDeleted ignores notes of another catalog', () async {
      final other = await _catalogs.getOrCreateCatalog('Hmm.Other', '{}');
      await _notes.createNote(
        HmmNoteCreate(
          subject: 'Mine',
          catalogId: other.id,
          content: 'x',
          uuid: 'foreign',
        ),
      );
      expect(await repo.existsIncludingDeleted('foreign'), isFalse);
    });

    test('an id owned by another catalog throws GlucoseIdCollision', () async {
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
        repo.saveReading(_rd('shared')),
        throwsA(isA<GlucoseIdCollision>()),
      );
      expect((await _notes.getNoteByUuid('shared'))!.content, 'keep me');
    });
  });

  group('glucoseRepositoryProvider', () {
    ProviderContainer c(DataMode m) => ProviderContainer(
      overrides: [
        dataModeProvider.overrideWith(() => _Mode(m)),
        localGlucoseRepositoryProvider.overrideWithValue(
          LocalGlucoseRepository(FakeNoteRepository(), FakeCatalogRepository()),
        ),
      ],
    );

    test('local and cloudStorage resolve the local repository', () {
      for (final m in [DataMode.local, DataMode.cloudStorage]) {
        final k = c(m);
        addTearDown(k.dispose);
        expect(
          k.read(glucoseRepositoryProvider),
          isA<LocalGlucoseRepository>(),
        );
      }
    });

    test('cloudApi throws GlucoseCloudApiUnavailable', () {
      final k = c(DataMode.cloudApi);
      addTearDown(k.dispose);
      Object? caught;
      try {
        k.read(glucoseRepositoryProvider);
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(isGlucoseCloudApiUnavailable(caught!), isTrue);
    });
  });
}
