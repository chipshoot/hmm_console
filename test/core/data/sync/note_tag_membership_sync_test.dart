import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';

// Verifies the membership wire contract at the repo level: names embedded in
// a body are reconstructed into NoteTagRefs via setTagsForNote, and dropping a
// name removes the ref (the set-replace the orchestrator does on pull).
void main() {
  late HmmDatabase db;
  late LocalTagRepository repo;
  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalTagRepository(db);
  });
  tearDown(() => db.close());

  test('note body tags expand into refs and set-replace on re-apply', () async {
    final authorId =
        await db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'a'));
    final noteId = await db.into(db.notes).insert(
          NotesCompanion.insert(subject: 's', authorId: authorId),
        );

    final body1 = {'tags': ['work', 'urgent']};
    await repo.setTagsForNote(
        noteId, (body1['tags'] as List).whereType<String>().toList());
    expect((await repo.tagNamesForNote(noteId)).toSet(), {'work', 'urgent'});

    final body2 = {'tags': ['work']};
    await repo.setTagsForNote(
        noteId, (body2['tags'] as List).whereType<String>().toList());
    expect((await repo.tagNamesForNote(noteId)).toSet(), {'work'});
  });
}
