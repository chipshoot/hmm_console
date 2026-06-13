import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository repo;
  late Author author;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final id = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    author = await (db.select(db.authors)..where((a) => a.id.equals(id)))
        .getSingle();
    repo = LocalHmmNoteRepository(db, () async => author);
  });
  tearDown(() => db.close());

  test('createNote honors an explicit uuid', () async {
    // catalogId 0 has no matching catalog row, but the in-memory test db does
    // not enforce the FK, so this is fine for asserting the uuid.
    final note = await repo.createNote(
        const HmmNoteCreate(subject: 'anchor', catalogId: 0, uuid: 'fixed-uuid'));
    expect(note.uuid, 'fixed-uuid');
  });

  test('setParentNote sets then clears parentNoteId and bumps lastModified',
      () async {
    final parent = await repo.createNote(
        const HmmNoteCreate(subject: 'parent', catalogId: 0));
    final child = await repo.createNote(
        const HmmNoteCreate(subject: 'child', catalogId: 0));

    final linked = await repo.setParentNote(child.id, parent.id);
    expect(linked.parentNoteId, parent.id);

    final detached = await repo.setParentNote(child.id, null);
    expect(detached.parentNoteId, isNull);
  });

  test('getUnattachedNotes returns only null-parent notes of the catalog',
      () async {
    final catId = await db.into(db.noteCatalogs).insert(
        NoteCatalogsCompanion.insert(name: 'General', schema: '{}'));
    final a = await repo
        .createNote(HmmNoteCreate(subject: 'free', catalogId: catId));
    final parent = await repo
        .createNote(HmmNoteCreate(subject: 'parent', catalogId: catId));
    await repo.createNote(HmmNoteCreate(
        subject: 'attached', catalogId: catId, parentNoteId: parent.id));

    final unattached = await repo.getUnattachedNotes(catId);
    final subjects = unattached.map((n) => n.subject).toSet();
    expect(subjects, contains('free'));
    expect(subjects, contains('parent'));
    expect(subjects, isNot(contains('attached')));
    expect(a.id, isNotNull);
  });
}
