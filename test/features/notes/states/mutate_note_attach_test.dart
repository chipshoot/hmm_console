import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HmmDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HmmDatabase(NativeDatabase.memory());
    await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await db.select(db.authors).getSingle();
    container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      localHmmNoteRepositoryProvider
          .overrideWithValue(LocalHmmNoteRepository(db, () async => author)),
    ]);
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('createGeneral with a parent sets parentNoteId', () async {
    final parentId = await db
        .into(db.notes)
        .insert(NotesCompanion.insert(subject: 'P', authorId: 1));
    final note = await container
        .read(mutateNoteProvider)
        .createGeneral(subject: 'child', parentNoteId: parentId);
    expect(note.parentNoteId, parentId);
  });

  test('attachExisting then detach', () async {
    final parentId = await db
        .into(db.notes)
        .insert(NotesCompanion.insert(subject: 'P', authorId: 1));
    final note =
        await container.read(mutateNoteProvider).createGeneral(subject: 'free');
    expect(note.parentNoteId, isNull);

    final attached = await container
        .read(mutateNoteProvider)
        .attachExisting(note.id, parentId);
    expect(attached.parentNoteId, parentId);

    final detached =
        await container.read(mutateNoteProvider).detachNote(note.id);
    expect(detached.parentNoteId, isNull);
  });
}
