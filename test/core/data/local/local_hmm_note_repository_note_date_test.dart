// Phase 2a: editable noteDate round-trip through LocalHmmNoteRepository
// against an in-memory Drift db. createDate stays the immutable audit.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';

void main() {
  late HmmDatabase db;
  late Author author;
  late int catalogId;
  late LocalHmmNoteRepository repo;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());

    final aid = await db.into(db.authors).insert(
          AuthorsCompanion.insert(accountName: 'tester'),
        );
    author = await (db.select(db.authors)..where((a) => a.id.equals(aid)))
        .getSingle();

    catalogId = await db.into(db.noteCatalogs).insert(
          NoteCatalogsCompanion.insert(name: 'TestCatalog', schema: '{}'),
        );

    repo = LocalHmmNoteRepository(db, () async => author);
  });

  tearDown(() async {
    await db.close();
  });

  test('createNote stamps noteDate when none supplied', () async {
    final note = await repo.createNote(
        HmmNoteCreate(subject: 's', catalogId: catalogId));
    expect(note.noteDate, isNotNull);
    expect(note.createDate, isNotNull);
  });

  test('createNote honors an explicit noteDate', () async {
    final chosen = DateTime.utc(2020, 5, 6, 7, 8);
    final note = await repo.createNote(
        HmmNoteCreate(subject: 's', catalogId: catalogId, noteDate: chosen));
    // Drift round-trips the instant but reads back in the local zone, so
    // compare moments rather than the isUtc-sensitive DateTime.==.
    expect(note.noteDate!.isAtSameMomentAs(chosen), isTrue);
  });

  test('updateNote changes noteDate but never createDate', () async {
    final created = await repo.createNote(
        HmmNoteCreate(subject: 's', catalogId: catalogId));
    final newDate = DateTime.utc(2019, 1, 1);
    final updated =
        await repo.updateNote(created.id, HmmNoteUpdate(noteDate: newDate));
    expect(updated.noteDate!.isAtSameMomentAs(newDate), isTrue);
    expect(updated.createDate, created.createDate); // audit untouched
  });
}
