import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';

void main() {
  late HmmDatabase db;
  late LocalTagRepository tags;

  setUp(() {
    db = HmmDatabase(NativeDatabase.memory());
    tags = LocalTagRepository(db);
  });
  tearDown(() => db.close());

  Future<int> tag(String name, {bool active = true, DateTime? deleted}) => db
      .into(db.tags)
      .insert(
        TagsCompanion.insert(
          name: name,
          isActivated: Value(active),
          deletedAt: Value(deleted),
        ),
      );

  test('watchNoteTags lists only active, live tags, by name', () async {
    final b = await tag('b');
    final a = await tag('a');
    final c = await tag('c', active: false);
    final d = await tag('d', deleted: DateTime.utc(2026, 1, 1));
    for (final t in [b, a, c, d]) {
      await db
          .into(db.noteTagRefs)
          .insert(NoteTagRefsCompanion.insert(noteId: 5, tagId: t));
    }
    final byNote = await tags.watchNoteTags().first;
    expect(byNote[5]!.map((t) => t.name), ['a', 'b']);
    expect(byNote[5]!.first.id, a);
  });

  test('watchLiveTagNames emits active tags only', () async {
    final a = await tag('alpha');
    await tag('off', active: false);
    await tag('gone', deleted: DateTime.utc(2026, 1, 1));
    expect(await tags.watchLiveTagNames().first, {a: 'alpha'});
  });
}
