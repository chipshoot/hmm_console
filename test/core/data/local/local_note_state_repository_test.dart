import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/notes/note_flag.dart';
import 'package:hmm_console/core/notes/note_state.dart';

void main() {
  late HmmDatabase db;
  late LocalHmmNoteRepository notes;
  late LocalNoteStateRepository states;
  var noteWrites = 0;
  var stateWrites = 0;

  setUp(() async {
    noteWrites = 0;
    stateWrites = 0;
    db = HmmDatabase(NativeDatabase.memory());
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(db.authors)
          ..where((a) => a.id.equals(authorId)))
        .getSingle();
    notes = LocalHmmNoteRepository(db, () async => author,
        onLocalWrite: () => noteWrites++);
    states = LocalNoteStateRepository(db, onLocalWrite: () => stateWrites++);
  });

  tearDown(() => db.close());

  test('a note without a row is unpinned and unflagged', () async {
    final s = await states.getState('nobody');
    expect(s.noteUuid, 'nobody');
    expect(s.isPinned, isFalse);
    expect(s.flagColor, isNull);
    expect(s.flag, isNull);
    expect(await states.getAllStates(), isEmpty);
  });

  test('setPinned and setFlagColor never touch the note row', () async {
    final created = await notes.createNote(
        const HmmNoteCreate(subject: 'keep me', catalogId: 1, content: 'body'));
    final before = (await notes.getNoteById(created.id))!;
    noteWrites = 0;

    await states.setPinned(created.uuid, true);
    await states.setFlagColor(created.uuid, 3);

    final after = (await notes.getNoteById(created.id))!;
    expect(after.version, before.version, reason: 'not a note edit (G14)');
    expect(after.lastModifiedDate, before.lastModifiedDate);
    expect(after.subject, 'keep me');
    expect(after.content, 'body');
    expect(noteWrites, 0, reason: 'the note is not marked for sync');
    expect(stateWrites, 2, reason: 'each state write asks for a sync');
  });

  test('a pin change keeps the flag and a flag change keeps the pin', () async {
    await states.setFlagColor('n1', 5);
    final pinned = await states.setPinned('n1', true);
    expect(pinned.flagColor, 5);
    final flagged = await states.setFlagColor('n1', 1);
    expect(flagged.isPinned, isTrue);
    expect(flagged.flag, NoteFlagColor.orange);
  });

  test('unpin writes a row with false, never deletes it', () async {
    await states.setPinned('n1', true);
    await states.setPinned('n1', false);
    await states.setFlagColor('n1', 2);
    await states.setFlagColor('n1', null);

    final rows = await db.select(db.noteStates).get();
    expect(rows, hasLength(1));
    expect(rows.single.isPinned, isFalse);
    expect(rows.single.flagColor, isNull);
  });

  test('an unknown flag value is kept verbatim and shows as grey', () async {
    final s = await states.setFlagColor('n1', 42);
    expect(s.flagColor, 42);
    expect(s.flag, NoteFlagColor.grey);
  });

  test('a second write in the same second still gets a later stamp', () async {
    final first = await states.setPinned('n1', true);
    final second = await states.setPinned('n1', false); // same wall-clock second
    expect(second.lastModifiedDate.isAfter(first.lastModifiedDate), isTrue,
        reason: 'Drift keeps whole seconds; a tie would lose the unpin on peers');
  });

  test('putState and deleteState write verbatim without asking for a sync',
      () async {
    final at = DateTime.utc(2026, 10, 18, 9);
    await states.putState(
        NoteState(noteUuid: 'n1', isPinned: true, flagColor: 4, lastModifiedDate: at));
    final s = await states.getState('n1');
    expect(s.isPinned, isTrue);
    expect(s.flagColor, 4);
    expect(s.lastModifiedDate.toUtc(), at);

    await states.deleteState('n1');
    expect(await states.getAllStates(), isEmpty);
    expect(stateWrites, 0);
  });
}
