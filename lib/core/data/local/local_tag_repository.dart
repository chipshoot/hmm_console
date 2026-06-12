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

  // ---- Sync support (cloudStorage tag sync) ----

  /// All tags including inactive and tombstoned ones (for definition merge).
  Future<List<Tag>> getTagsWithMeta() => _db.select(_db.tags).get();

  /// Create or update a tag by normalized name.
  Future<void> upsertTagByName(
    String name, {
    String? description,
    required bool isActivated,
    required DateTime lastModified,
    DateTime? deletedAt,
  }) async {
    final existing = await getTagByName(name);
    if (existing == null) {
      await _db.into(_db.tags).insert(TagsCompanion.insert(
            name: name.trim(),
            description: Value(description),
            isActivated: Value(isActivated),
            lastModified: Value(lastModified),
            deletedAt: Value(deletedAt),
          ));
    } else {
      await (_db.update(_db.tags)..where((t) => t.id.equals(existing.id)))
          .write(TagsCompanion(
        description: Value(description),
        isActivated: Value(isActivated),
        lastModified: Value(lastModified),
        deletedAt: Value(deletedAt),
      ));
    }
  }

  /// Set the sync tombstone for a tag by name (no-op if it doesn't exist).
  Future<void> tombstoneTagByName(String name, DateTime deletedAt) async {
    final existing = await getTagByName(name);
    if (existing == null) return;
    await (_db.update(_db.tags)..where((t) => t.id.equals(existing.id)))
        .write(TagsCompanion(
      deletedAt: Value(deletedAt),
      lastModified: Value(deletedAt),
    ));
  }

  /// Active (non-deleted, activated) tag names applied to a note.
  Future<List<String>> tagNamesForNote(int noteId) async {
    final tags = await getTagsForNote(noteId); // already filters isActivated
    return tags.where((t) => t.deletedAt == null).map((t) => t.name).toList();
  }

  /// Set-replace the note's tag refs to exactly [names], creating any missing
  /// tags by name. Membership has no sync metadata — the note body is the
  /// source of truth, so absence means removal.
  Future<void> setTagsForNote(int noteId, List<String> names) async {
    final desiredIds = <int>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final tag = await getTagByName(name) ??
          await createTag(TagsCompanion.insert(
            name: name,
            // Auto-created from a note body before its real definition has
            // synced: stamp at epoch 0 so any real tags.json definition
            // (with a real timestamp) always wins the merge.
            lastModified: Value(
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
          ));
      desiredIds.add(tag.id);
    }

    final currentRefs = await (_db.select(_db.noteTagRefs)
          ..where((r) => r.noteId.equals(noteId)))
        .get();
    final currentIds = currentRefs.map((r) => r.tagId).toSet();

    final toRemove = currentIds.difference(desiredIds);
    if (toRemove.isNotEmpty) {
      await (_db.delete(_db.noteTagRefs)
            ..where((r) => r.noteId.equals(noteId) & r.tagId.isIn(toRemove)))
          .go();
    }
    for (final tagId in desiredIds.difference(currentIds)) {
      await _db.into(_db.noteTagRefs).insertOnConflictUpdate(
            NoteTagRefsCompanion.insert(noteId: noteId, tagId: tagId),
          );
    }
  }
}

final localTagRepositoryProvider = Provider<ITagRepository>((ref) {
  return LocalTagRepository(ref.watch(hmmDatabaseProvider));
});
