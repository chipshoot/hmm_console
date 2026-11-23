import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/notes/catalog_palette.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Notes list opens on General, not All', () async {
    SharedPreferences.setMockInitialValues({});
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    final container = ProviderContainer(
      overrides: [
        hmmDatabaseProvider.overrideWithValue(db),
        localHmmNoteRepositoryProvider.overrideWithValue(
          LocalHmmNoteRepository(db, () async => author),
        ),
        localNoteCatalogRepositoryProvider.overrideWithValue(
          LocalNoteCatalogRepository(db),
        ),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(notesListStateProvider, (_, _) {});
    addTearDown(sub.close);
    final data = await container.read(notesListStateProvider.future);

    expect(data.query.source, const DomainSource(key: kGeneralCatalogName));
  });
}
