import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

abstract interface class ITagRepository {
  Future<List<Tag>> getTags();

  Future<Tag?> getTagById(int id);

  Future<Tag?> getTagByName(String name);

  Future<Tag> createTag(TagsCompanion tag);

  Future<Tag> updateTag(int id, TagsCompanion tag);

  Future<void> deactivateTag(int id);

  Future<List<Tag>> getTagsForNote(int noteId);

  Future<void> applyTagToNote(int noteId, int tagId);

  Future<void> removeTagFromNote(int noteId, int tagId);
}

class LocalTagRepository implements ITagRepository {
  LocalTagRepository(this._db);

  final HmmDatabase _db;

  @override
  Future<List<Tag>> getTags() async {
    return await (_db.select(_db.tags)
          ..where((t) => t.isActivated.equals(true)))
        .get();
  }

  @override
  Future<Tag?> getTagById(int id) async {
    return await (_db.select(_db.tags)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<Tag?> getTagByName(String name) async {
    return await (_db.select(_db.tags)
          ..where((t) => t.name.lower().equals(name.toLowerCase().trim())))
        .getSingleOrNull();
  }

  @override
  Future<Tag> createTag(TagsCompanion tag) async {
    final id = await _db.into(_db.tags).insert(tag);
    return (await getTagById(id))!;
  }

  @override
  Future<Tag> updateTag(int id, TagsCompanion tag) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(tag);
    return (await getTagById(id))!;
  }

  @override
  Future<void> deactivateTag(int id) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id)))
        .write(const TagsCompanion(isActivated: Value(false)));
  }

  @override
  Future<List<Tag>> getTagsForNote(int noteId) async {
    final refs = await (_db.select(_db.noteTagRefs)
          ..where((r) => r.noteId.equals(noteId)))
        .get();
    if (refs.isEmpty) return [];

    final tagIds = refs.map((r) => r.tagId).toList();
    return await (_db.select(_db.tags)
          ..where((t) => t.id.isIn(tagIds) & t.isActivated.equals(true)))
        .get();
  }

  @override
  Future<void> applyTagToNote(int noteId, int tagId) async {
    await _db.into(_db.noteTagRefs).insertOnConflictUpdate(
      NoteTagRefsCompanion.insert(noteId: noteId, tagId: tagId),
    );
  }

  @override
  Future<void> removeTagFromNote(int noteId, int tagId) async {
    await (_db.delete(_db.noteTagRefs)
          ..where((r) => r.noteId.equals(noteId) & r.tagId.equals(tagId)))
        .go();
  }
}

final localTagRepositoryProvider = Provider<ITagRepository>((ref) {
  return LocalTagRepository(ref.watch(hmmDatabaseProvider));
});
