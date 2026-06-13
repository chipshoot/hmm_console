import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/states/attached_notes_state.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('attachedNotesProvider lists General notes under a parent', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 't'));
    final author = await db.select(db.authors).getSingle();
    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      localHmmNoteRepositoryProvider
          .overrideWithValue(LocalHmmNoteRepository(db, () async => author)),
    ]);
    addTearDown(container.dispose);

    final parentId = await db
        .into(db.notes)
        .insert(NotesCompanion.insert(subject: 'parent', authorId: 1));
    await container
        .read(mutateNoteProvider)
        .createGeneral(subject: 'attached', parentNoteId: parentId);
    await container.read(mutateNoteProvider).createGeneral(subject: 'free');

    final attached =
        await container.read(attachedNotesProvider(parentId).future);
    expect(attached.map((n) => n.subject), ['attached']);
  });
}
