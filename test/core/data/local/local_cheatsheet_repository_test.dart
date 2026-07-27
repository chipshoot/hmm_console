import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository noteRepo;
  late LocalNoteCatalogRepository catalogRepo;
  late LocalCheatsheetRepository repo;

  Future<void> setup() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid)))
            .getSingle();
    noteRepo = LocalHmmNoteRepository(db, () async => author);
    catalogRepo = LocalNoteCatalogRepository(db);
    repo = LocalCheatsheetRepository(noteRepo, catalogRepo);
  }

  CheatsheetCard sample(String id) => CheatsheetCard(
        id: id,
        title: 'Claim',
        walletGroup: 'Vehicle',
        tags: const [],
        templateId: 'blank',
        rows: const [
          CheatsheetRow(
            label: 'Plate',
            source: CheatsheetSource(
              noteUuid: 'n',
              kind: SourceGranularity.whole,
            ),
          ),
        ],
      );

  /// Reads the catalog's notes directly, paging to exhaustion, so the test
  /// never depends on the behaviour it is checking.
  Future<List<HmmNote>> allCheatsheetNotes() async {
    final catalog =
        await catalogRepo.getOrCreateCatalog(cheatsheetCatalogName, '{}');
    final out = <HmmNote>[];
    var page = 1;
    while (true) {
      final res = await noteRepo.getNotes(
        catalogId: catalog.id,
        page: page,
        pageSize: 100,
      );
      out.addAll(res.items);
      if (res.items.isEmpty || page >= res.meta.totalPages) break;
      page++;
    }
    return out;
  }

  test('save creates, getCard reloads, getCards lists', () async {
    await setup();
    addTearDown(db.close);

    expect((await repo.saveCard(sample('c1'))).id, 'c1');
    expect((await repo.getCard('c1'))!.title, 'Claim');
    expect((await repo.getCards()).length, 1);
  });

  test('save upserts by id (no duplicate note)', () async {
    await setup();
    addTearDown(db.close);

    await repo.saveCard(sample('c1'));
    await repo.saveCard(sample('c1').copyWith(title: 'Updated'));

    expect((await repo.getCards()).length, 1);
    expect((await repo.getCard('c1'))!.title, 'Updated');
  });

  test('subject is the stable Cheatsheet:{id}, unchanged by a rename',
      () async {
    await setup();
    addTearDown(db.close);

    await repo.saveCard(sample('c1'));
    expect((await allCheatsheetNotes()).single.subject, 'Cheatsheet:c1');

    await repo.saveCard(sample('c1').copyWith(title: 'Renamed'));

    // The subject is an identity, not a label: titles are mutable and
    // non-unique, so they live only inside the card JSON.
    expect((await allCheatsheetNotes()).single.subject, 'Cheatsheet:c1');
    expect((await repo.getCard('c1'))!.title, 'Renamed');
  });

  test('rows and bindings survive a round-trip through Drift', () async {
    await setup();
    addTearDown(db.close);

    final card = sample('c1').copyWith(
      tags: const ['legal', 'car'],
      rows: const [
        CheatsheetRow(
          label: 'Plate',
          source: CheatsheetSource(
            noteUuid: 'auto1',
            kind: SourceGranularity.field,
            locator: 'AutomobileInfo.plate',
          ),
          valueAction: ValueAction.call,
          openSource: false,
        ),
        CheatsheetRow(label: 'Unbound', source: null),
      ],
    );
    await repo.saveCard(card);

    expect(await repo.getCard('c1'), equals(card));
  });

  test('getCards returns every card across page boundaries', () async {
    await setup();
    addTearDown(db.close);

    // More than the 20-per-page default, so a fixed page size would hide some.
    for (var i = 0; i < 45; i++) {
      await repo.saveCard(sample('c$i'));
    }

    expect((await repo.getCards()).length, 45);
    expect(await repo.getCard('c44'), isNotNull);
  });

  test('getCard returns null for an unknown id', () async {
    await setup();
    addTearDown(db.close);

    await repo.saveCard(sample('c1'));
    expect(await repo.getCard('nope'), isNull);
  });

  test('delete removes it', () async {
    await setup();
    addTearDown(db.close);

    await repo.saveCard(sample('c1'));
    await repo.deleteCard('c1');

    expect(await repo.getCard('c1'), isNull);
    expect(await repo.getCards(), isEmpty);
  });

  test('deleting an unknown id is a no-op', () async {
    await setup();
    addTearDown(db.close);

    await repo.saveCard(sample('c1'));
    await repo.deleteCard('nope');

    expect((await repo.getCards()).length, 1);
  });
}
