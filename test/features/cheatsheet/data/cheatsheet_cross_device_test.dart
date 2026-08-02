import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/features/cheatsheet/data/cheatsheet_resolver.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_row.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_source.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';

/// The whole reference model rests on "uuid is stable, the local int id is
/// not". A fake repository cannot prove that, so this exercises two real
/// databases and deliberately arranges for the same logical note to carry a
/// *different* local int id on each. A failure here is a design failure.
const _autoCatalog = 'Hmm.AutomobileMan.AutomobileInfo';
const _plateContent =
    '{"note":{"content":{"AutomobileInfo":{"plate":"ABC123"}}}}';

class _Device {
  _Device(this.db, this.notes, this.catalogs, this.cheatsheets);

  final HmmDatabase db;
  final LocalHmmNoteRepository notes;
  final LocalNoteCatalogRepository catalogs;
  final LocalCheatsheetRepository cheatsheets;

  static Future<_Device> create() async {
    final db = HmmDatabase(NativeDatabase.memory());
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(aid)))
            .getSingle();
    final notes = LocalHmmNoteRepository(db, () async => author);
    final catalogs = LocalNoteCatalogRepository(db);
    return _Device(
        db, notes, catalogs, LocalCheatsheetRepository(notes, catalogs));
  }

  Future<int> autoCatalogId() async =>
      (await catalogs.getOrCreateCatalog(_autoCatalog, '{}')).id;

  Future<int> cheatsheetCatalogId() async =>
      (await catalogs.getOrCreateCatalog(cheatsheetCatalogName, '{}')).id;

  Future<List<HmmNote>> notesIn(int catalogId) async =>
      (await notes.getNotes(catalogId: catalogId, pageSize: 100)).items;
}

/// Replays one note onto another device the way a sync provider does: subject,
/// content and the stable uuid cross the wire; the local int id does not.
Future<HmmNote> _replay(HmmNote source, _Device target, int catalogId) =>
    target.notes.createNote(HmmNoteCreate(
      subject: source.subject,
      catalogId: catalogId,
      content: source.content,
      description: source.description,
      uuid: source.uuid,
    ));

void main() {
  // Drift warns when it sees two HmmDatabase instances, because sharing one
  // QueryExecutor between them races. Each _Device here owns a separate
  // NativeDatabase.memory() — two independent databases is the whole point.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a reference resolves on a fresh device where the int id differs',
      () async {
    final a = await _Device.create();
    final b = await _Device.create();
    addTearDown(a.db.close);
    addTearDown(b.db.close);

    // Filler notes first, so the source note on A is NOT id 1.
    final aAutoCatalog = await a.autoCatalogId();
    for (var i = 0; i < 3; i++) {
      await a.notes.createNote(
          HmmNoteCreate(subject: 'filler$i', catalogId: aAutoCatalog));
    }
    final srcA = await a.notes.createNote(HmmNoteCreate(
      subject: 'Auto',
      catalogId: aAutoCatalog,
      content: _plateContent,
    ));
    expect(srcA.id, greaterThan(1), reason: 'guards the premise of the test');

    await a.cheatsheets.saveCard(CheatsheetCard(
      id: 'c1',
      title: 'Claim',
      walletGroup: 'Vehicle',
      tags: const [],
      templateId: 'blank',
      rows: [
        CheatsheetRow(
          label: 'Plate',
          source: CheatsheetSource(
            noteUuid: srcA.uuid,
            kind: SourceGranularity.field,
            locator: 'AutomobileInfo.plate',
          ),
        ),
      ],
    ));

    // Transfer to B in the opposite order, so int ids cannot line up: the
    // cheatsheet note lands first, its source second.
    final cardNoteA = (await a.notesIn(await a.cheatsheetCatalogId())).single;
    await _replay(cardNoteA, b, await b.cheatsheetCatalogId());
    final srcB = await _replay(srcA, b, await b.autoCatalogId());

    expect(srcB.id, isNot(srcA.id),
        reason: 'different local identity, same uuid');
    expect(srcB.uuid, srcA.uuid);

    final reloaded = await b.cheatsheets.getCard('c1');
    expect(reloaded, isNotNull);

    final v = await CheatsheetResolver(b.notes).resolve(reloaded!.rows.first);
    expect(v.text, 'ABC123', reason: 'resolved by uuid, not by int id');
  });

  test('a late-arriving source resolves once it lands', () async {
    final b = await _Device.create();
    addTearDown(b.db.close);

    const row = CheatsheetRow(
      label: 'Plate',
      source: CheatsheetSource(
        noteUuid: 'not-here-yet',
        kind: SourceGranularity.field,
        locator: 'AutomobileInfo.plate',
      ),
    );
    final resolver = CheatsheetResolver(b.notes);

    expect((await resolver.resolve(row)).missing, isTrue,
        reason: 'before the source syncs');

    await b.notes.createNote(HmmNoteCreate(
      subject: 'Auto',
      catalogId: await b.autoCatalogId(),
      uuid: 'not-here-yet',
      content: '{"note":{"content":{"AutomobileInfo":{"plate":"XYZ789"}}}}',
    ));

    expect((await resolver.resolve(row)).text, 'XYZ789',
        reason: 'after the source syncs');
  });

  test('a permanently missing source degrades, never throws', () async {
    final b = await _Device.create();
    addTearDown(b.db.close);

    final v = await CheatsheetResolver(b.notes).resolve(const CheatsheetRow(
      label: 'x',
      source: CheatsheetSource(noteUuid: 'gone', kind: SourceGranularity.whole),
    ));
    expect(v.missing, isTrue);
  });
}
