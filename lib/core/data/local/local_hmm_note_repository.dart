import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/notes/data/mappers/hmm_note_mapper.dart';
import '../../../features/notes/data/models/hmm_note.dart';
import '../../auth/current_author_account_name_provider.dart';
import '../../network/pagination.dart';
import '../attachments/attachment_ref_codec.dart';
import '../hmm_note_input.dart';
import 'database.dart';

/// Repository contract for HmmNote. Mirrors the Hmm.ServiceApi
/// `HmmNoteController` shape (`/v{version}/notes`):
///
/// * Reads return [PageList] envelopes — same fields as the API's
///   `PageList<T>` (currentPage, pageSize, totalCount, totalPages).
/// * Reads return the [HmmNote] domain entity, not the Drift `Note` row.
///   The Drift row stays internal to this file.
/// * Writes use [HmmNoteCreate] / [HmmNoteUpdate] parameter objects that
///   mirror the API's `ApiNoteForCreate` / `ApiNoteForUpdate` DTOs.
///   `authorId` is never exposed: the implementation resolves it from the
///   signed-in user (matches the server's `CurrentUserAuthorProvider`).
/// * `authorId` and `catalogId` are immutable after create — `updateNote`
///   only accepts subject/content/description, matching the API's PUT/PATCH
///   contract.
/// * Delete is soft on both sides (`Notes.deletedAt` here ↔
///   `HmmNote.IsDeleted` on the server).
abstract interface class IHmmNoteRepository {
  Future<PageList<HmmNote>> getNotes({
    int? catalogId,
    int? parentNoteId,
    int page = 1,
    int pageSize = 20,
    bool includeDeleted = false,
  });

  Future<HmmNote?> getNoteById(int id);

  /// Stable cross-device identity. The local int [HmmNote.id] is per-device;
  /// [HmmNote.uuid] is what sync providers use to correlate with the server.
  Future<HmmNote?> getNoteByUuid(String uuid);

  Future<HmmNote> createNote(HmmNoteCreate input);

  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch);

  Future<void> deleteNote(int id);

  /// Streams the current author's live (non-deleted) notes, emitting a fresh
  /// list whenever the underlying Notes table changes — no matter which feature
  /// wrote it. This keeps the notes list in sync with notes created by domain
  /// features (e.g. gas logs) that don't go through the notes mutation path.
  Stream<List<HmmNote>> watchNotes();
}

class LocalHmmNoteRepository implements IHmmNoteRepository {
  LocalHmmNoteRepository(this._db, this._currentAuthor);

  final HmmDatabase _db;
  final Future<Author> Function() _currentAuthor;

  @override
  Future<PageList<HmmNote>> getNotes({
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

    final rows = await (_db.select(_db.notes)
          ..where(buildWhere)
          ..orderBy([(n) => OrderingTerm.desc(n.lastModifiedDate)])
          ..limit(pageSize, offset: (page - 1) * pageSize))
        .get();

    return PaginatedResponse(
      items: rows.map(HmmNoteMapper.fromDriftRow).toList(),
      meta: PaginationMeta(
        totalCount: totalCount,
        pageSize: pageSize,
        currentPage: page,
        totalPages: totalPages,
      ),
    );
  }

  @override
  Future<HmmNote?> getNoteById(int id) async {
    final author = await _currentAuthor();
    final row = await (_db.select(_db.notes)
          ..where((n) => n.id.equals(id) & n.authorId.equals(author.id)))
        .getSingleOrNull();
    return row == null ? null : HmmNoteMapper.fromDriftRow(row);
  }

  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async {
    final author = await _currentAuthor();
    final row = await (_db.select(_db.notes)
          ..where((n) => n.uuid.equals(uuid) & n.authorId.equals(author.id)))
        .getSingleOrNull();
    return row == null ? null : HmmNoteMapper.fromDriftRow(row);
  }

  @override
  Future<HmmNote> createNote(HmmNoteCreate input) async {
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
          // NoteAttachmentsCodec.encode returns null for an empty
          // payload (or for a null input), which is exactly the
          // SQL-NULL we want in the column.
          attachments: Value(
            input.attachments == null
                ? null
                : NoteAttachmentsCodec.encode(input.attachments!),
          ),
        ));
    return (await getNoteById(id))!;
  }

  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
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
      // null = "don't touch"; an empty payload encodes to null and
      // clears the column; a non-empty payload replaces it.
      attachments: patch.attachments != null
          ? Value(NoteAttachmentsCodec.encode(patch.attachments!))
          : const Value.absent(),
      lastModifiedDate: Value(now),
      version: Value(_versionStamp()),
    ));
    return (await getNoteById(id))!;
  }

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

  @override
  Stream<List<HmmNote>> watchNotes() async* {
    final author = await _currentAuthor();
    yield* (_db.select(_db.notes)
          ..where((n) => n.authorId.equals(author.id) & n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.createDate)]))
        .watch()
        .map((rows) => rows.map(HmmNoteMapper.fromDriftRow).toList());
  }

  Uint8List _versionStamp() => Uint8List.fromList(
      DateTime.now().microsecondsSinceEpoch.toRadixString(16).codeUnits);
}

final localHmmNoteRepositoryProvider = Provider<IHmmNoteRepository>((ref) {
  return LocalHmmNoteRepository(
    ref.watch(hmmDatabaseProvider),
    () => ref.read(currentAuthorProvider.future),
  );
});
