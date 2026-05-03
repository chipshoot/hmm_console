import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/pagination.dart';
import 'database.dart';

abstract interface class INoteRepository {
  Future<PaginatedResponse<Note>> getNotes({
    int? catalogId,
    int? parentNoteId,
    int page = 1,
    int pageSize = 20,
    bool includeDeleted = false,
  });

  Future<Note?> getNoteById(int id);

  Future<Note> createNote(NotesCompanion note);

  Future<Note> updateNote(int id, NotesCompanion note);

  Future<void> deleteNote(int id);
}

class LocalNoteRepository implements INoteRepository {
  LocalNoteRepository(this._db);

  final HmmDatabase _db;

  @override
  Future<PaginatedResponse<Note>> getNotes({
    int? catalogId,
    int? parentNoteId,
    int page = 1,
    int pageSize = 20,
    bool includeDeleted = false,
  }) async {
    Expression<bool> buildWhere($NotesTable n) {
      Expression<bool> expr = const Constant(true);
      if (!includeDeleted) expr = expr & n.deletedAt.isNull();
      if (catalogId != null) expr = expr & n.catalogId.equals(catalogId);
      if (parentNoteId != null) expr = expr & n.parentNoteId.equals(parentNoteId);
      return expr;
    }

    final totalCount = await (_db.select(_db.notes)..where(buildWhere))
        .get()
        .then((r) => r.length);
    final totalPages = (totalCount / pageSize).ceil();

    final items = await (_db.select(_db.notes)
          ..where(buildWhere)
          ..orderBy([(n) => OrderingTerm.desc(n.lastModifiedDate)])
          ..limit(pageSize, offset: (page - 1) * pageSize))
        .get();

    return PaginatedResponse(
      items: items,
      meta: PaginationMeta(
        totalCount: totalCount,
        pageSize: pageSize,
        currentPage: page,
        totalPages: totalPages,
      ),
    );
  }

  @override
  Future<Note?> getNoteById(int id) async {
    return await (_db.select(_db.notes)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<Note> createNote(NotesCompanion note) async {
    final now = DateTime.now().toUtc();
    final withTimestamps = note.copyWith(
      createDate: Value(now),
      lastModifiedDate: Value(now),
      version: Value(Uint8List.fromList(DateTime.now().microsecondsSinceEpoch.toRadixString(16).codeUnits)),
    );
    final id = await _db.into(_db.notes).insert(withTimestamps);
    return (await getNoteById(id))!;
  }

  @override
  Future<Note> updateNote(int id, NotesCompanion note) async {
    final withTimestamp = note.copyWith(
      lastModifiedDate: Value(DateTime.now().toUtc()),
      version: Value(Uint8List.fromList(DateTime.now().microsecondsSinceEpoch.toRadixString(16).codeUnits)),
    );
    await (_db.update(_db.notes)..where((n) => n.id.equals(id)))
        .write(withTimestamp);
    return (await getNoteById(id))!;
  }

  @override
  Future<void> deleteNote(int id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.notes)..where((n) => n.id.equals(id)))
        .write(NotesCompanion(
      deletedAt: Value(now),
      lastModifiedDate: Value(now),
    ));
  }

}

final localNoteRepositoryProvider = Provider<INoteRepository>((ref) {
  return LocalNoteRepository(ref.watch(hmmDatabaseProvider));
});
