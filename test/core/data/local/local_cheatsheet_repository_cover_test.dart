import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_cheatsheet_repository.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/vault/vault_gc.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';

// The cover's bytes stay alive only while some note's `attachments` column
// names them — that column is all VaultGc reads. These tests pin that the
// card note's column always holds exactly the current cover and nothing else.
void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository notes;
  late LocalNoteCatalogRepository catalogs;
  late LocalCheatsheetRepository repo;

  const cover = VaultRef(
    path: 'attachments/note-1/cover.jpg',
    contentType: 'image/jpeg',
    byteSize: 100,
  );
  const otherCover = VaultRef(
    path: 'attachments/note-1/other.jpg',
    contentType: 'image/jpeg',
    byteSize: 200,
  );

  const plain = CheatsheetCard(
    id: 'c1',
    title: 'Claim',
    walletGroup: 'Vehicle',
    tags: [],
    templateId: 'accidentClaim',
    rows: [],
  );

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final aid = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'cover-tester'));
    final author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();
    notes = LocalHmmNoteRepository(db, () async => author);
    catalogs = LocalNoteCatalogRepository(db);
    repo = LocalCheatsheetRepository(notes, catalogs);
  });

  tearDown(() async => db.close());

  Future<Note> row() async => (await db.select(db.notes).get()).single;

  Future<int> catalogId() async =>
      (await catalogs.getOrCreateCatalog(cheatsheetCatalogName, '{}')).id;

  String envelope(Map<String, dynamic> card) => jsonEncode({
        'note': {
          'content': {'Cheatsheet': card},
        },
      });

  test('noteIdFor is null before the first save and the note id after',
      () async {
    expect(await repo.noteIdFor('c1'), isNull);
    await repo.saveCard(plain);
    expect(await repo.noteIdFor('c1'), (await row()).id);
  });

  test('the cover ref lives in the attachments column, content holds its path',
      () async {
    await repo.saveCard(plain.withCover(cover));

    expect(await collectReferencedVaultPaths(db), {cover.path});
    final content = (await row()).content!;
    expect(content, contains('"cover":"attachments/note-1/cover.jpg"'));
    expect(content, isNot(contains('byteSize')));
  });

  test('getCard projects the cover from the attachments column', () async {
    await repo.saveCard(plain.withCover(cover));
    final card = await repo.getCard('c1');
    expect(card!.cover, cover);
    expect(card.style.coverPath, cover.path);
  });

  test('replacing the cover leaves only the new one referenced', () async {
    await repo.saveCard(plain.withCover(cover));
    await repo.saveCard(plain.withCover(otherCover));
    expect(await collectReferencedVaultPaths(db), {otherCover.path});
  });

  test('removing the cover clears the column', () async {
    await repo.saveCard(plain.withCover(cover));
    await repo.saveCard(plain.withCover(cover).withCover(null));
    expect(await collectReferencedVaultPaths(db), isEmpty);
    expect((await repo.getCard('c1'))!.cover, isNull);
  });

  test('deleteCard releases the cover so VaultGc no longer counts it',
      () async {
    await repo.saveCard(plain.withCover(cover));
    await repo.deleteCard('c1');

    // deleteNote is a soft delete and VaultGc counts soft-deleted notes, so
    // only an explicit release frees the bytes.
    expect(await collectReferencedVaultPaths(db), isEmpty);
    expect(await repo.getCard('c1'), isNull);
  });

  test('an untouched card is written back byte-identical', () async {
    final stored = envelope({
      'schemaVersion': 1,
      'id': 'c1',
      'title': 'Vim',
      'walletGroup': 'Reference',
      'tags': [],
      'templateId': 'document',
      'protected': false,
      'rows': [
        {
          'label': 'Motions',
          'valueAction': 'none',
          'openSource': true,
          'emoji': '\u{1F440}',
        },
      ],
      'style': {'theme': 'turquoise', 'sparkle': true},
      'future': 1,
    });
    await notes.createNote(HmmNoteCreate(
      subject: cheatsheetSubjectFor('c1'),
      catalogId: await catalogId(),
      content: stored,
    ));

    await repo.saveCard((await repo.getCard('c1'))!);

    expect((await row()).content, stored);
  });

  test('a card saved by an older app version shows no cover and the next '
      'save releases it', () async {
    // An older app rewrote the content without `style` (it did not know the
    // key) and never touched the attachments column, so the cover ref is
    // still there with nothing pointing at it.
    await notes.createNote(HmmNoteCreate(
      subject: cheatsheetSubjectFor('c1'),
      catalogId: await catalogId(),
      content: envelope({
        'schemaVersion': 1,
        'id': 'c1',
        'title': 'Claim',
        'walletGroup': 'Vehicle',
        'tags': [],
        'templateId': 'accidentClaim',
        'protected': false,
        'rows': [],
      }),
      attachments: NoteAttachments(images: const [cover]),
    ));

    final card = (await repo.getCard('c1'))!;
    expect(card.cover, isNull);
    expect(card.look.theme, CardThemeId.blue);

    await repo.saveCard(card.copyWith(title: 'Claim 2'));
    expect(await collectReferencedVaultPaths(db), isEmpty);
  });

  test('a cover path whose attachment is missing keeps its path', () async {
    await notes.createNote(HmmNoteCreate(
      subject: cheatsheetSubjectFor('c1'),
      catalogId: await catalogId(),
      content: envelope({
        'schemaVersion': 1,
        'id': 'c1',
        'title': 'Claim',
        'walletGroup': 'Vehicle',
        'tags': [],
        'templateId': 'accidentClaim',
        'protected': false,
        'rows': [],
        'style': {'cover': 'attachments/note-9/elsewhere.jpg'},
      }),
    ));

    final card = (await repo.getCard('c1'))!;
    expect(card.cover, isNull);
    await repo.saveCard(card);
    expect((await row()).content,
        contains('"cover":"attachments/note-9/elsewhere.jpg"'));
  });
}
