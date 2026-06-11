import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';

void main() {
  late HmmDatabase db;
  late LocalTagRepository repo;

  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    repo = LocalTagRepository(db);
  });
  tearDown(() => db.close());

  Future<int> _note() async => db.into(db.notes).insert(
        NotesCompanion.insert(subject: 's', authorId: await _author(db)),
      );

  test('getTagsWithMeta returns all tags including inactive/deleted', () async {
    await repo.upsertTagByName('a',
        isActivated: true, lastModified: DateTime.utc(2026, 1, 1));
    await repo.upsertTagByName('b',
        isActivated: false, lastModified: DateTime.utc(2026, 1, 1));
    await repo.tombstoneTagByName('b', DateTime.utc(2026, 1, 2));
    final all = await repo.getTagsWithMeta();
    expect(all.map((t) => t.name).toSet(), {'a', 'b'});
  });

  test('upsertTagByName creates then updates by normalized name', () async {
    await repo.upsertTagByName('  Work ',
        description: 'd1', isActivated: true,
        lastModified: DateTime.utc(2026, 1, 1));
    await repo.upsertTagByName('work',
        description: 'd2', isActivated: false,
        lastModified: DateTime.utc(2026, 1, 2));
    final tags = await repo.getTagsWithMeta();
    expect(tags.length, 1);
    expect(tags.single.description, 'd2');
    expect(tags.single.isActivated, false);
  });

  test('setTagsForNote set-replaces refs and auto-creates tags', () async {
    final noteId = await _note();
    await repo.setTagsForNote(noteId, ['work', 'urgent']);
    expect((await repo.tagNamesForNote(noteId)).toSet(), {'work', 'urgent'});

    // Drop 'urgent', add 'home'.
    await repo.setTagsForNote(noteId, ['work', 'home']);
    expect((await repo.tagNamesForNote(noteId)).toSet(), {'work', 'home'});
  });
}

Future<int> _author(HmmDatabase db) async =>
    db.into(db.authors).insert(AuthorsCompanion.insert(accountName: 'tester'));
