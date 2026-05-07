import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/current_author_account_name_provider.dart';
import '../../network/pagination.dart';
import '../note_input.dart';
import 'database.dart';

/// Repository contract for HmmNotes. Mirrors the Hmm.ServiceApi
/// `HmmNoteController` shape (`/v{version}/notes`):
///
/// * Reads return [PageList] envelopes — same fields as the API's
///   `PageList<T>` (currentPage, pageSize, totalCount, totalPages).
/// * Writes use [NoteCreate] / [NoteUpdate] parameter objects that mirror
///   the API's `ApiNoteForCreate` / `ApiNoteForUpdate` DTOs. `authorId` is
///   never exposed: the implementation resolves it from the signed-in user
///   (matches the server's `CurrentUserAuthorProvider` flow).
/// * `authorId` and `catalogId` are immutable after create — `updateNote`
///   only accepts the subject/content/description fields, matching the
///   API's PUT/PATCH contract.
/// * Delete is soft on both sides (`Notes.deletedAt` here ↔
///   `HmmNote.IsDeleted` on the server).
abstract interface class INoteRepository {
  Future<PageList<Note>> getNotes({
    int? catalogId,
    int? parentNoteId,
    int page = 1,
    int pageSize = 20,
    bool includeDeleted = false,
  });

  Future<Note?> getNoteById(int id);

  /// Stable cross-device identity. The local int [Note.id] is per-device;
  /// [Note.uuid] is what sync providers use to correlate with the server.
  Future<Note?> getNoteByUuid(String uuid);

  Future<Note> createNote(NoteCreate input);

  Future<Note> updateNote(int id, NoteUpdate patch);

  Future<void> deleteNote(int id);
}

class LocalNoteRepository implements INoteRepository {
  LocalNoteRepository(this._db, this._currentAuthor);

  final HmmDatabase _db;
  final Future<Author> Function() _currentAuthor;

  @override
  Future<PageList<Note>> getNotes({
    int? catalogId,
    int? parentNoteId,
    int page = 1,
    int pageSize = 20,
    bool includeDeleted = false,
  }) async {
    final author = await _currentAuthor();

    Expression<bool> buildWhere($NotesTable n) {
      Expression<bool> expr = n.authorId.equals(author.id);
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
    final author = await _currentAuthor();
    return await (_db.select(_db.notes)
          ..where((n) => n.id.equals(id) & n.authorId.equals(author.id)))
        .getSingleOrNull();
  }

  @override
  Future<Note?> getNoteByUuid(String uuid) async {
    final author = await _currentAuthor();
    return await (_db.select(_db.notes)
          ..where((n) => n.uuid.equals(uuid) & n.authorId.equals(author.id)))
        .getSingleOrNull();
  }

  @override
  Future<Note> createNote(NoteCreate input) async {
    final author = await _currentAuthor();
    final now = DateTime.now().toUtc();
    final id = await _db.into(_db.notes).insert(NotesCompanion.insert(
          subject: input.subject,
          content: Value(input.content),
          authorId: author.id,
          catalogId: Value(input.catalogId),
          parentNoteId: Value(input.parentNoteId),
          description: Value(input.description),
          createDate: Value(now),
          lastModifiedDate: Value(now),
          version: Value(_versionStamp()),
        ));
    return (await getNoteById(id))!;
  }

  @override
  Future<Note> updateNote(int id, NoteUpdate patch) async {
    if (patch.isEmpty) return (await getNoteById(id))!;
    final author = await _currentAuthor();
    final now = DateTime.now().toUtc();
    await (_db.update(_db.notes)
          ..where((n) => n.id.equals(id) & n.authorId.equals(author.id)))
        .write(NotesCompanion(
      subject: patch.subject != null ? Value(patch.subject!) : const Value.absent(),
      content: patch.content != null ? Value(patch.content) : const Value.absent(),
      description: patch.description != null
          ? Value(patch.description)
          : const Value.absent(),
      lastModifiedDate: Value(now),
      version: Value(_versionStamp()),
    ));
    return (await getNoteById(id))!;
  }

  Uint8List _versionStamp() => Uint8List.fromList(
      DateTime.now().microsecondsSinceEpoch.toRadixString(16).codeUnits);

  @override
  Future<void> deleteNote(int id) async {
    final author = await _currentAuthor();
    final now = DateTime.now().toUtc();
    await (_db.update(_db.notes)
          ..where((n) => n.id.equals(id) & n.authorId.equals(author.id)))
        .write(NotesCompanion(
      deletedAt: Value(now),
      lastModifiedDate: Value(now),
    ));
  }

}

final localNoteRepositoryProvider = Provider<INoteRepository>((ref) {
  return LocalNoteRepository(
    ref.watch(hmmDatabaseProvider),
    () => ref.read(currentAuthorProvider.future),
  );
});
