import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_controller.dart';
import '../sync/sync_orchestrator.dart';
import 'database.dart';
import 'local_hmm_note_repository.dart' show restoreStamp;

/// A tag as the notes list shows it.
typedef NoteTagLabel = ({int id, String name});

/// A live tag with the number of live (not soft-deleted) notes carrying it.
typedef TagUsage = ({int id, String name, int noteCount});

/// A rename's new name is already held by another live tag
/// (case-insensitive). The UI offers to merge into [existingId] instead.
class TagNameTaken implements Exception {
  const TagNameTaken(this.existingId);
  final int existingId;

  @override
  String toString() => 'TagNameTaken($existingId)';
}

/// Longest tag name the UI accepts (the table allows 200).
const int maxTagNameLength = 50;

/// The trimmed, whitespace-collapsed tag name, or null if that is empty or
/// longer than [maxTagNameLength] characters.
String? normalizeTagName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty || name.length > maxTagNameLength) return null;
  return name;
}

abstract interface class ITagRepository {
  /// Note id -> its active, non-deleted tags sorted by name; re-emits when
  /// tags or tag references change.
  Stream<Map<int, List<NoteTagLabel>>> watchNoteTags();

  /// Active, non-deleted tag id -> name, whether or not any note carries it.
  Stream<Map<int, String>> watchLiveTagNames();

  Future<List<Tag>> getTags();

  Future<Tag?> getTagById(int id);

  Future<Tag?> getTagByName(String name);

  Future<Tag> createTag(TagsCompanion tag);

  Future<Tag> updateTag(int id, TagsCompanion tag);

  Future<void> deactivateTag(int id);

  Future<List<Tag>> getTagsForNote(int noteId);

  Future<void> applyTagToNote(int noteId, int tagId);

  Future<void> removeTagFromNote(int noteId, int tagId);

  /// Live tags (activated, not tombstoned) sorted case-insensitively by
  /// name, each with its count of live notes; tags with 0 notes included.
  Stream<List<TagUsage>> watchTagUsage();

  /// The live tag named [name] (normalized, case-insensitive); else revives
  /// a dead row with that name; else creates one. Throws [ArgumentError]
  /// when [normalizeTagName] rejects [name].
  Future<Tag> ensureTag(String name);

  /// Set-replace the note's tags. A changed set is a note edit: it bumps the
  /// note's lastModifiedDate and version so the note re-syncs. An unchanged
  /// set writes nothing.
  Future<void> setNoteTags(int noteId, Set<int> tagIds);

  /// Rename keeping the local id. A live tag already holding the name throws
  /// [TagNameTaken]; a dead one gives the name up. Unless the change is
  /// case-only, the old name is left behind as a sync tombstone. Carrier
  /// notes (soft-deleted ones too) are bumped.
  Future<void> renameTag(int id, String newName);

  /// Move [mergeId]'s notes onto [keepId] and tombstone [mergeId].
  Future<void> mergeTags({required int keepId, required int mergeId});

  /// Remove the tag from every note and tombstone it.
  Future<void> deleteTag(int id);
}

class LocalTagRepository implements ITagRepository {
  LocalTagRepository(this._db, {void Function()? onLocalWrite})
    : _onLocalWrite = onLocalWrite;

  final HmmDatabase _db;
  final void Function()? _onLocalWrite;

  static bool _isLive(Tag t) => t.isActivated && t.deletedAt == null;

  static DateTime _now() => DateTime.now().toUtc();

  Uint8List _versionStamp() => Uint8List.fromList(
    DateTime.now().microsecondsSinceEpoch.toRadixString(16).codeUnits,
  );

  /// All rows whose name matches [name] case-insensitively (at most one
  /// while the one-row-per-normalized-name invariant holds).
  Future<List<Tag>> _rowsNamed(String name) => (_db.select(
    _db.tags,
  )..where((t) => t.name.lower().equals(name.toLowerCase()))).get();

  Future<Tag> _requireTag(int id) async {
    final row = await getTagById(id);
    if (row == null) throw StateError('Tag $id not found');
    return row;
  }

  /// Note ids carrying [tagId], soft-deleted notes included.
  Future<Set<int>> _carriersOf(int tagId) async => (await (_db.select(
    _db.noteTagRefs,
  )..where((r) => r.tagId.equals(tagId))).get()).map((r) => r.noteId).toSet();

  /// A tag change is a note edit: stamp strictly later than the note's last
  /// change (whole-second storage) and give it a fresh version.
  Future<void> _bumpNotes(Iterable<int> noteIds, DateTime now) async {
    for (final id in noteIds) {
      final row = await (_db.select(
        _db.notes,
      )..where((n) => n.id.equals(id))).getSingleOrNull();
      if (row == null) continue;
      await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(
          lastModifiedDate: Value(
            restoreStamp(row.lastModifiedDate ?? row.createDate, now),
          ),
          version: Value(_versionStamp()),
        ),
      );
    }
  }

  Future<void> _tombstone(Tag row, DateTime now) async {
    final stamp = restoreStamp(row.lastModified, now);
    await (_db.update(_db.tags)..where((t) => t.id.equals(row.id))).write(
      TagsCompanion(deletedAt: Value(stamp), lastModified: Value(stamp)),
    );
  }

  @override
  Stream<List<TagUsage>> watchTagUsage() {
    return _db
        .customSelect(
          'SELECT t.id AS id, t.name AS name, COUNT(n.id) AS note_count '
          'FROM tags t '
          'LEFT JOIN note_tag_refs r ON r.tag_id = t.id '
          'LEFT JOIN notes n ON n.id = r.note_id AND n.deleted_at IS NULL '
          'WHERE t.is_activated = 1 AND t.deleted_at IS NULL '
          'GROUP BY t.id, t.name',
          readsFrom: {_db.tags, _db.noteTagRefs, _db.notes},
        )
        .watch()
        .map((rows) {
          final usage = [
            for (final r in rows)
              (
                id: r.read<int>('id'),
                name: r.read<String>('name'),
                noteCount: r.read<int>('note_count'),
              ),
          ];
          usage.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return usage;
        });
  }

  @override
  Future<Tag> ensureTag(String name) async {
    final normalized = normalizeTagName(name);
    if (normalized == null) {
      throw ArgumentError.value(name, 'name', 'not a valid tag name');
    }
    var wrote = false;
    final tag = await _db.transaction(() async {
      final rows = await _rowsNamed(normalized);
      for (final r in rows) {
        if (_isLive(r)) return r;
      }
      final now = _now();
      if (rows.isNotEmpty) {
        // Decision 4: revive the dead row (a newer live record beats the
        // tombstone under per-name LWW, and the unique name stays intact).
        final dead = rows.first;
        await (_db.update(_db.tags)..where((t) => t.id.equals(dead.id))).write(
          TagsCompanion(
            name: Value(normalized),
            isActivated: const Value(true),
            deletedAt: const Value(null),
            lastModified: Value(restoreStamp(dead.lastModified, now)),
          ),
        );
        wrote = true;
        return _requireTag(dead.id);
      }
      final id = await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(name: normalized, lastModified: Value(now)),
          );
      wrote = true;
      return _requireTag(id);
    });
    if (wrote) _onLocalWrite?.call();
    return tag;
  }

  @override
  Future<void> setNoteTags(int noteId, Set<int> tagIds) async {
    final changed = await _db.transaction(() async {
      final current =
          (await (_db.select(
                _db.noteTagRefs,
              )..where((r) => r.noteId.equals(noteId))).get())
              .map((r) => r.tagId)
              .toSet();
      final toRemove = current.difference(tagIds);
      final toAdd = tagIds.difference(current);
      if (toRemove.isEmpty && toAdd.isEmpty) return false;
      if (toRemove.isNotEmpty) {
        await (_db.delete(
          _db.noteTagRefs,
        )..where((r) => r.noteId.equals(noteId) & r.tagId.isIn(toRemove))).go();
      }
      for (final tagId in toAdd) {
        await _db
            .into(_db.noteTagRefs)
            .insertOnConflictUpdate(
              NoteTagRefsCompanion.insert(noteId: noteId, tagId: tagId),
            );
      }
      await _bumpNotes([noteId], _now());
      return true;
    });
    if (changed) _onLocalWrite?.call();
  }

  @override
  Future<void> renameTag(int id, String newName) async {
    final normalized = normalizeTagName(newName);
    if (normalized == null) {
      throw ArgumentError.value(newName, 'newName', 'not a valid tag name');
    }
    final changed = await _db.transaction(() async {
      final row = await _requireTag(id);
      if (row.name == normalized) return false;
      final now = _now();
      final stamp = restoreStamp(row.lastModified, now);
      final caseOnly = row.name.toLowerCase() == normalized.toLowerCase();

      if (!caseOnly) {
        for (final other in await _rowsNamed(normalized)) {
          if (other.id == id) continue;
          if (_isLive(other)) throw TagNameTaken(other.id);
          // Decision 4: a dead row gives its name up. Our renamed record is
          // newer than its tombstone, so LWW lets the new name win anyway.
          await (_db.delete(
            _db.noteTagRefs,
          )..where((r) => r.tagId.equals(other.id))).go();
          await (_db.delete(
            _db.tags,
          )..where((t) => t.id.equals(other.id))).go();
        }
      }

      await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
        TagsCompanion(name: Value(normalized), lastModified: Value(stamp)),
      );
      if (!caseOnly) {
        // Leave the old name behind as a tombstone so peers drop it.
        await _db
            .into(_db.tags)
            .insert(
              TagsCompanion.insert(
                name: row.name,
                description: Value(row.description),
                isActivated: Value(row.isActivated),
                lastModified: Value(stamp),
                deletedAt: Value(stamp),
              ),
            );
      }
      await _bumpNotes(await _carriersOf(id), now);
      return true;
    });
    if (changed) _onLocalWrite?.call();
  }

  @override
  Future<void> mergeTags({required int keepId, required int mergeId}) async {
    if (keepId == mergeId) {
      throw ArgumentError.value(mergeId, 'mergeId', 'must differ from keepId');
    }
    await _db.transaction(() async {
      await _requireTag(keepId);
      final merged = await _requireTag(mergeId);
      final carriers = await _carriersOf(mergeId);
      for (final noteId in carriers) {
        await _db
            .into(_db.noteTagRefs)
            .insertOnConflictUpdate(
              NoteTagRefsCompanion.insert(noteId: noteId, tagId: keepId),
            );
      }
      await (_db.delete(
        _db.noteTagRefs,
      )..where((r) => r.tagId.equals(mergeId))).go();
      final now = _now();
      await _tombstone(merged, now);
      await _bumpNotes(carriers, now);
    });
    _onLocalWrite?.call();
  }

  @override
  Future<void> deleteTag(int id) async {
    await _db.transaction(() async {
      final row = await _requireTag(id);
      final carriers = await _carriersOf(id);
      await (_db.delete(
        _db.noteTagRefs,
      )..where((r) => r.tagId.equals(id))).go();
      final now = _now();
      await _tombstone(row, now);
      await _bumpNotes(carriers, now);
    });
    _onLocalWrite?.call();
  }

  @override
  Stream<Map<int, List<NoteTagLabel>>> watchNoteTags() {
    final query = _db.select(_db.noteTagRefs).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.noteTagRefs.tagId)),
    ])..where(_db.tags.isActivated.equals(true) & _db.tags.deletedAt.isNull());
    return query.watch().map((rows) {
      final byNote = <int, List<NoteTagLabel>>{};
      for (final r in rows) {
        final tag = r.readTable(_db.tags);
        byNote.putIfAbsent(r.readTable(_db.noteTagRefs).noteId, () => []).add((
          id: tag.id,
          name: tag.name,
        ));
      }
      for (final l in byNote.values) {
        l.sort((a, b) => a.name.compareTo(b.name));
      }
      return byNote;
    });
  }

  @override
  Stream<Map<int, String>> watchLiveTagNames() {
    final query = _db.select(_db.tags)
      ..where((t) => t.isActivated.equals(true) & t.deletedAt.isNull());
    return query.watch().map((rows) => {for (final t in rows) t.id: t.name});
  }

  @override
  Future<List<Tag>> getTags() async {
    return await (_db.select(
      _db.tags,
    )..where((t) => t.isActivated.equals(true))).get();
  }

  @override
  Future<Tag?> getTagById(int id) async {
    return await (_db.select(
      _db.tags,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
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
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
      const TagsCompanion(isActivated: Value(false)),
    );
  }

  @override
  Future<List<Tag>> getTagsForNote(int noteId) async {
    final refs = await (_db.select(
      _db.noteTagRefs,
    )..where((r) => r.noteId.equals(noteId))).get();
    if (refs.isEmpty) return [];

    final tagIds = refs.map((r) => r.tagId).toList();
    return await (_db.select(
      _db.tags,
    )..where((t) => t.id.isIn(tagIds) & t.isActivated.equals(true))).get();
  }

  @override
  Future<void> applyTagToNote(int noteId, int tagId) async {
    await _db
        .into(_db.noteTagRefs)
        .insertOnConflictUpdate(
          NoteTagRefsCompanion.insert(noteId: noteId, tagId: tagId),
        );
  }

  @override
  Future<void> removeTagFromNote(int noteId, int tagId) async {
    await (_db.delete(
      _db.noteTagRefs,
    )..where((r) => r.noteId.equals(noteId) & r.tagId.equals(tagId))).go();
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
      await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(
              name: name.trim(),
              description: Value(description),
              isActivated: Value(isActivated),
              lastModified: Value(lastModified),
              deletedAt: Value(deletedAt),
            ),
          );
    } else {
      await (_db.update(
        _db.tags,
      )..where((t) => t.id.equals(existing.id))).write(
        TagsCompanion(
          description: Value(description),
          isActivated: Value(isActivated),
          lastModified: Value(lastModified),
          deletedAt: Value(deletedAt),
        ),
      );
    }
  }

  /// Set the sync tombstone for a tag by name (no-op if it doesn't exist).
  Future<void> tombstoneTagByName(String name, DateTime deletedAt) async {
    final existing = await getTagByName(name);
    if (existing == null) return;
    await (_db.update(_db.tags)..where((t) => t.id.equals(existing.id))).write(
      TagsCompanion(
        deletedAt: Value(deletedAt),
        lastModified: Value(deletedAt),
      ),
    );
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
      final tag =
          await getTagByName(name) ??
          await createTag(
            TagsCompanion.insert(
              name: name,
              // Auto-created from a note body before its real definition has
              // synced: stamp at epoch 0 so any real tags.json definition
              // (with a real timestamp) always wins the merge.
              lastModified: Value(
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              ),
            ),
          );
      desiredIds.add(tag.id);
    }

    final currentRefs = await (_db.select(
      _db.noteTagRefs,
    )..where((r) => r.noteId.equals(noteId))).get();
    final currentIds = currentRefs.map((r) => r.tagId).toSet();

    final toRemove = currentIds.difference(desiredIds);
    if (toRemove.isNotEmpty) {
      await (_db.delete(
        _db.noteTagRefs,
      )..where((r) => r.noteId.equals(noteId) & r.tagId.isIn(toRemove))).go();
    }
    for (final tagId in desiredIds.difference(currentIds)) {
      await _db
          .into(_db.noteTagRefs)
          .insertOnConflictUpdate(
            NoteTagRefsCompanion.insert(noteId: noteId, tagId: tagId),
          );
    }
  }
}

final localTagRepositoryProvider = Provider<ITagRepository>((ref) {
  return LocalTagRepository(
    ref.watch(hmmDatabaseProvider),
    // Same debounced auto-sync gate as LocalHmmNoteRepository: read (not
    // watch) both providers since this closure runs later, at write time.
    onLocalWrite: () {
      if (ref.read(syncOrchestratorProvider).isActive) {
        ref.read(syncControllerProvider).notifyLocalChange();
      }
    },
  );
});
