import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository repo;
  var writes = 0;

  setUp(() async {
    writes = 0;
    db = HmmDatabase(NativeDatabase.memory());
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();
    repo = LocalHmmNoteRepository(db, () async => author,
        onLocalWrite: () => writes++);
  });

  tearDown(() => db.close());

  test('restoreNote clears deletedAt with a stamp strictly after the tombstone',
      () async {
    final created =
        await repo.createNote(const HmmNoteCreate(subject: 's', catalogId: 1));
    await repo.deleteNote(created.id);
    final tombstone = (await repo.getNoteById(created.id))!;
    expect(tombstone.deletedAt, isNotNull);
    writes = 0;

    final restored = await repo.restoreNote(created.id);

    expect(restored.deletedAt, isNull);
    expect(
        restored.lastModifiedDate!
            .difference(tombstone.lastModifiedDate!)
            .inSeconds,
        greaterThanOrEqualTo(1),
        reason: 'the store keeps whole seconds; a same-second restore would tie');
    expect(writes, 1);
  });

  test('delete and restore leave the note state alone', () async {
    final created =
        await repo.createNote(const HmmNoteCreate(subject: 's', catalogId: 1));
    final states = LocalNoteStateRepository(db);
    await states.setPinned(created.uuid, true);

    await repo.deleteNote(created.id);
    expect((await states.getState(created.uuid)).isPinned, isTrue);
    await repo.restoreNote(created.id);
    expect((await states.getState(created.uuid)).isPinned, isTrue,
        reason: 'a restored note comes back pinned');
  });

  test('restoreNote on a live note is a no-op', () async {
    final created =
        await repo.createNote(const HmmNoteCreate(subject: 's', catalogId: 1));
    writes = 0;
    final same = await repo.restoreNote(created.id);
    expect(same.deletedAt, isNull);
    expect(same.version, created.version);
    expect(writes, 0);
  });

  test('restoreNote throws for a missing note', () async {
    expect(() => repo.restoreNote(999), throwsStateError);
  });

  test('watchDeletedNotes emits soft-deleted notes newest first, never live ones',
      () async {
    final a =
        await repo.createNote(const HmmNoteCreate(subject: 'a', catalogId: 1));
    final b =
        await repo.createNote(const HmmNoteCreate(subject: 'b', catalogId: 1));
    await repo.createNote(const HmmNoteCreate(subject: 'live', catalogId: 1));
    await repo.deleteNote(a.id);
    // deletedAt keeps whole seconds; make b's strictly later.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await repo.deleteNote(b.id);

    final deleted = await repo.watchDeletedNotes().first;

    expect(deleted.map((n) => n.subject), ['b', 'a']);
  });

  group('restoreStamp', () {
    final prev = DateTime.utc(2026, 10, 18, 9, 0, 0);
    test('a clock in the same second moves to the next whole second', () {
      expect(restoreStamp(prev, DateTime.utc(2026, 10, 18, 9, 0, 0, 700)),
          DateTime.utc(2026, 10, 18, 9, 0, 1));
    });
    test('a clock behind the tombstone still moves past it', () {
      expect(restoreStamp(prev, DateTime.utc(2026, 10, 18, 8, 59, 0)),
          DateTime.utc(2026, 10, 18, 9, 0, 1));
    });
    test('a clock well ahead is used as is', () {
      final now = DateTime.utc(2026, 10, 18, 9, 5, 0);
      expect(restoreStamp(prev, now), now);
    });
    test('a sub-second previous value is floored first', () {
      expect(
          restoreStamp(DateTime.utc(2026, 10, 18, 9, 0, 0, 900),
              DateTime.utc(2026, 10, 18, 9, 0, 0, 950)),
          DateTime.utc(2026, 10, 18, 9, 0, 1));
    });
  });
}
