import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';

/// Regression (2026-10-31, iPhone → iPad): sync wrote the pin into the
/// iPad's NoteStates table, but an already-loaded note detail kept showing
/// the note unpinned — the provider read the state once and was never told
/// the row changed. A sync write must reach a loaded detail.
void main() {
  late HmmDatabase db;
  late ProviderContainer container;
  late LocalNoteStateRepository states;
  late Author testAuthor;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    testAuthor = author;
    states = LocalNoteStateRepository(db);
    container = ProviderContainer(
      overrides: [
        hmmNoteRepositoryProvider.overrideWithValue(
          LocalHmmNoteRepository(db, () async => author),
        ),
        noteCatalogRepositoryProvider.overrideWithValue(
          LocalNoteCatalogRepository(db),
        ),
        noteStateRepositoryProvider.overrideWithValue(states),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a pin written by sync reaches an already-loaded note detail', () async {
    final repo = container.read(hmmNoteRepositoryProvider);
    final note = await repo.createNote(
      const HmmNoteCreate(subject: 's', catalogId: 1, content: 'c'),
    );

    final sub = container.listen(noteDetailProvider(note.id), (_, _) {});
    final before = await container.read(noteDetailProvider(note.id).future);
    expect(before.state.isPinned, isFalse);

    // What NoteStateSyncService does when the remote entry is newer.
    await states.putState(
      NoteState(
        noteUuid: note.uuid,
        isPinned: true,
        flagColor: 2,
        lastModifiedDate: DateTime.utc(2026, 10, 31, 23, 39, 18),
      ),
    );
    await pumpEventQueue();

    final after = await container.read(noteDetailProvider(note.id).future);
    expect(after.state.isPinned, isTrue);
    expect(after.state.flagColor, 2);
    sub.close();
  });

  test(
    'delete, restore and delete again from elsewhere reach a loaded detail',
    () async {
      final repo = container.read(hmmNoteRepositoryProvider);
      final note = await repo.createNote(
        const HmmNoteCreate(subject: 's', catalogId: 1, content: 'c'),
      );

      final sub = container.listen(noteDetailProvider(note.id), (_, _) {});
      Future<bool> deleted() async => (await container.read(
        noteDetailProvider(note.id).future,
      )).note.isDeleted;
      expect(await deleted(), isFalse);

      await repo.deleteNote(note.id);
      await pumpEventQueue();
      expect(await deleted(), isTrue, reason: 'banner appears');

      await repo.restoreNote(note.id);
      await pumpEventQueue();
      expect(await deleted(), isFalse, reason: 'banner clears');

      await repo.deleteNote(note.id);
      await pumpEventQueue();
      expect(await deleted(), isTrue, reason: 'banner reappears');
      sub.close();
    },
  );

  test('opening a live note loads it exactly once', () async {
    final counting = _CountingRepo(db, () async => testAuthor);
    final c = ProviderContainer(
      overrides: [
        hmmNoteRepositoryProvider.overrideWithValue(counting),
        noteCatalogRepositoryProvider.overrideWithValue(
          LocalNoteCatalogRepository(db),
        ),
        noteStateRepositoryProvider.overrideWithValue(states),
      ],
    );
    addTearDown(c.dispose);
    final note = await counting.createNote(
      const HmmNoteCreate(subject: 's', catalogId: 1, content: 'c'),
    );

    counting.getByIdCalls = 0; // createNote may read the row back itself
    final sub = c.listen(noteDetailProvider(note.id), (_, _) {});
    await c.read(noteDetailProvider(note.id).future);
    await pumpEventQueue(); // let deletedNoteIdsProvider emit its first set
    await c.read(noteDetailProvider(note.id).future);

    expect(counting.getByIdCalls, 1);
    sub.close();
  });
}

class _CountingRepo extends LocalHmmNoteRepository {
  _CountingRepo(super.db, super.author);
  int getByIdCalls = 0;

  @override
  Future<HmmNote?> getNoteById(int id) {
    getByIdCalls++;
    return super.getNoteById(id);
  }
}
