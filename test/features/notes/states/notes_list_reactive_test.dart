import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the "new gas log not visible in the notes list" bug.
///
/// A gas log is created through the SAME note repository the list reads from
/// (`LocalHmmNoteRepository.createNote`), but via the gas_log feature — which
/// never invalidates `notesListStateProvider`. The list must instead react to
/// the underlying Notes table so ANY writer's note appears without manual
/// invalidation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notes list reactively shows a note created by another feature',
      () async {
    SharedPreferences.setMockInitialValues({}); // -> DataMode.local
    final db = HmmDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed an author and pin the repo to it (bypasses Firebase currentUser).
    final authorId =
        await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author =
        await (db.select(db.authors)..where((a) => a.id.equals(authorId))).getSingle();

    final container = ProviderContainer(overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      localHmmNoteRepositoryProvider
          .overrideWithValue(LocalHmmNoteRepository(db, () async => author)),
      localNoteCatalogRepositoryProvider
          .overrideWithValue(LocalNoteCatalogRepository(db)),
    ]);
    addTearDown(container.dispose);

    // A domain catalog (as the gas_log feature would create).
    final gasCatalog = await container
        .read(noteCatalogRepositoryProvider)
        .createCatalog(NoteCatalogsCompanion.insert(
          name: 'Hmm.AutomobileMan.GasLog',
          schema: '{}',
          formatType: const Value(2),
        ));

    // Keep the provider alive and watch for the new note to surface.
    final completer = Completer<NotesListData>();
    final sub = container.listen<AsyncValue<NotesListData>>(
      notesListStateProvider,
      (prev, next) {
        final v = next.value;
        if (v != null &&
            v.all.any((n) => n.subject == 'Shell — May 1') &&
            !completer.isCompleted) {
          completer.complete(v);
        }
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    // Initial state: empty list.
    final initial = await container.read(notesListStateProvider.future);
    expect(initial.visible, isEmpty);

    // Another feature writes a note straight through the note repository —
    // NO notesListStateProvider invalidation anywhere.
    await container.read(hmmNoteRepositoryProvider).createNote(
          HmmNoteCreate(
            subject: 'Shell — May 1',
            catalogId: gasCatalog.id,
            content: '{"note":{"content":{"GasLog":{"station":"Shell"}}}}',
          ),
        );

    // The list must update reactively.
    final after = await completer.future.timeout(const Duration(seconds: 2));
    expect(after.visible.map((n) => n.subject), contains('Shell — May 1'));
  });
}
