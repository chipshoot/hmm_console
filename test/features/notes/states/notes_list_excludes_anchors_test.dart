import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('general notes list excludes subsystem anchor notes', () async {
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
    container.listen(notesListStateProvider, (_, __) {});

    // Seed the Automobile anchor (an anchor-catalog note) + a real general note.
    await container.read(automobileAnchorProvider.future);
    final general = await db.into(db.noteCatalogs).insert(
        NoteCatalogsCompanion.insert(name: 'General', schema: '{}'));
    await db.into(db.notes).insert(NotesCompanion.insert(
        subject: 'grocery', authorId: 1, catalogId: Value(general)));

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final data = await container.read(notesListStateProvider.future);
    final subjects = data.all.map((n) => n.subject).toSet();
    expect(subjects, contains('grocery'));
    expect(subjects, isNot(contains('Automobile'))); // anchor excluded
  });
}
