import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_note_catalog_repository.dart';
import 'package:hmm_console/core/data/local/local_note_state_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/features/notes/states/note_delete_policy.dart';

void main() {
  late HmmDatabase db;
  late ProviderContainer container;
  late LocalHmmNoteRepository notes;
  late LocalNoteCatalogRepository catalogs;

  setUp(() async {
    db = HmmDatabase(NativeDatabase.memory());
    final authorId = await db
        .into(db.authors)
        .insert(AuthorsCompanion.insert(accountName: 'tester'));
    final author = await (db.select(
      db.authors,
    )..where((a) => a.id.equals(authorId))).getSingle();
    notes = LocalHmmNoteRepository(db, () async => author);
    catalogs = LocalNoteCatalogRepository(db);
    container = ProviderContainer(
      overrides: [
        hmmNoteRepositoryProvider.overrideWithValue(notes),
        noteCatalogRepositoryProvider.overrideWithValue(catalogs),
        noteStateRepositoryProvider.overrideWithValue(
          LocalNoteStateRepository(db),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> noteIn(String catalogName) async {
    final catalog = await catalogs.getOrCreateCatalog(catalogName, '{}');
    return (await notes.createNote(
      HmmNoteCreate(subject: 's', catalogId: catalog.id),
    )).id;
  }

  test('delete soft-deletes an ordinary note', () async {
    final id = await noteIn('General');

    await container.read(mutateNoteProvider).delete(id);

    expect((await notes.getNoteById(id))!.deletedAt, isNotNull);
  });

  test('delete refuses an entity note and leaves it live', () async {
    final id = await noteIn('Hmm.ContactMan.Contact');

    await expectLater(
      container.read(mutateNoteProvider).delete(id),
      throwsA(
        isA<EntityNoteDeleteRefused>().having(
          (e) => e.place,
          'place',
          NoteManagePlace.contacts,
        ),
      ),
    );
    expect((await notes.getNoteById(id))!.deletedAt, isNull);
  });

  test('restore brings a deleted note back', () async {
    final id = await noteIn('General');
    final mutate = container.read(mutateNoteProvider);
    await mutate.delete(id);

    final restored = await mutate.restore(id);

    expect(restored.deletedAt, isNull);
  });

  test('pin and flag work on every note, entity notes included', () async {
    final id = await noteIn('Hmm.AutomobileMan.GasLog');
    final mutate = container.read(mutateNoteProvider);

    expect((await mutate.setPinned(id, true)).isPinned, isTrue);
    expect((await mutate.setFlagColor(id, 0)).flagColor, 0);
    expect((await mutate.setFlagColor(id, null)).flagColor, isNull);
  });

  test('pin and flag write the state row, never the note', () async {
    final id = await noteIn('General');
    final before = (await notes.getNoteById(id))!;
    final mutate = container.read(mutateNoteProvider);

    final state = await mutate.setPinned(id, true);
    await mutate.setFlagColor(id, 4);

    expect(state.noteUuid, before.uuid);
    final after = (await notes.getNoteById(id))!;
    expect(after.version, before.version);
    expect(after.lastModifiedDate, before.lastModifiedDate);
  });
}
