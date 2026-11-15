import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';

/// A save that changes nothing is not an edit: it must not bump
/// lastModifiedDate, or last-writer-wins lets it undo a delete made on
/// another device (2026-11-14: an unchanged save on the iPad resurrected a
/// note deleted on the iPhone).
void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository repo;
  var writes = 0;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    writes = 0;
    repo = LocalHmmNoteRepository(
      db,
      () async => author,
      onLocalWrite: () => writes++,
    );
  });

  tearDown(() => db.close());

  Future<Note> row(int id) =>
      (db.select(db.notes)..where((n) => n.id.equals(id))).getSingle();

  /// Pushes the note's stamps into the past so a write is detectable.
  Future<int> seed() async {
    final n = await repo.createNote(
      const HmmNoteCreate(subject: 'Hi', catalogId: 1, content: 'body'),
    );
    await (db.update(db.notes)..where((r) => r.id.equals(n.id))).write(
      NotesCompanion(
        lastModifiedDate: Value(DateTime.utc(2026, 1, 1)),
        noteDate: Value(DateTime.utc(2026, 1, 1, 9, 30)),
      ),
    );
    writes = 0;
    return n.id;
  }

  test('an update with the stored values writes nothing', () async {
    final id = await seed();
    final before = await row(id);

    await repo.updateNote(
      id,
      HmmNoteUpdate(
        subject: 'Hi',
        content: 'body',
        noteDate: DateTime.utc(2026, 1, 1, 9, 30, 0, 400),
        location: NoteLocation.empty,
      ),
    );

    final after = await row(id);
    expect(after.lastModifiedDate, before.lastModifiedDate);
    expect(after.version, before.version);
    expect(writes, 0);
  });

  test('empty text and a missing body count as the same', () async {
    final n = await repo.createNote(
      const HmmNoteCreate(subject: 'Hi', catalogId: 1),
    );
    await (db.update(db.notes)..where((r) => r.id.equals(n.id))).write(
      NotesCompanion(lastModifiedDate: Value(DateTime.utc(2026, 1, 1))),
    );
    writes = 0;

    await repo.updateNote(n.id, const HmmNoteUpdate(content: ''));

    expect(
      (await row(
        n.id,
      )).lastModifiedDate!.isAtSameMomentAs(DateTime.utc(2026, 1, 1)),
      isTrue,
    );
    expect(writes, 0);
  });

  test('a real change still writes and notifies', () async {
    final id = await seed();

    await repo.updateNote(
      id,
      const HmmNoteUpdate(subject: 'Hi', content: 'edited'),
    );

    final after = await row(id);
    expect(after.content, 'edited');
    expect(after.lastModifiedDate!.isAfter(DateTime.utc(2026, 1, 1)), isTrue);
    expect(writes, 1);
  });

  test('a changed note date still writes', () async {
    final id = await seed();

    await repo.updateNote(
      id,
      HmmNoteUpdate(noteDate: DateTime.utc(2026, 1, 2, 9, 30)),
    );

    expect(writes, 1);
  });
}
