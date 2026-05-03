import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

abstract interface class IAttachmentRepository {
  /// Create an attachment: writes bytes to disk, inserts a row, returns the
  /// row with `localPath` populated.
  Future<Attachment> createAttachment({
    required int noteId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
  });

  Future<Attachment?> getAttachmentById(int id);

  Future<List<Attachment>> getAttachmentsByNote(
    int noteId, {
    bool includeDeleted = false,
  });

  /// Read the on-disk bytes for this attachment. Returns null if the row is
  /// missing, tombstoned, or has no `localPath`.
  Future<List<int>?> readAttachmentBytes(int id);

  /// Soft-delete: sets `deletedAt`, keeps the file on disk for later GC so the
  /// tombstone can still sync to peers.
  Future<void> deleteAttachment(int id);

  /// Hard-delete for GC: removes the row and the on-disk file. Safe no-op if
  /// the file is already gone.
  Future<void> purgeAttachment(int id);
}

class LocalAttachmentRepository implements IAttachmentRepository {
  LocalAttachmentRepository(this._db);

  final HmmDatabase _db;

  @override
  Future<Attachment> createAttachment({
    required int noteId,
    required String filename,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final now = DateTime.now().toUtc();

    // Insert first so we have a stable id for the on-disk filename.
    final id = await _db.into(_db.attachments).insert(
          AttachmentsCompanion.insert(
            noteId: noteId,
            filename: filename,
            mimeType: mimeType,
            size: bytes.length,
            localPath: const Value.absent(),
            remotePath: const Value.absent(),
            createDate: Value(now),
            lastModifiedDate: Value(now),
          ),
        );

    final localPath = await _resolvePath(id, filename);
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    await (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(
        localPath: Value(localPath),
        lastModifiedDate: Value(DateTime.now().toUtc()),
      ),
    );

    return (await getAttachmentById(id))!;
  }

  @override
  Future<Attachment?> getAttachmentById(int id) {
    return (_db.select(_db.attachments)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<Attachment>> getAttachmentsByNote(
    int noteId, {
    bool includeDeleted = false,
  }) {
    return (_db.select(_db.attachments)
          ..where((a) => includeDeleted
              ? a.noteId.equals(noteId)
              : a.noteId.equals(noteId) & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.desc(a.lastModifiedDate)]))
        .get();
  }

  @override
  Future<List<int>?> readAttachmentBytes(int id) async {
    final row = await getAttachmentById(id);
    if (row == null || row.deletedAt != null || row.localPath == null) {
      return null;
    }
    final file = File(row.localPath!);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> deleteAttachment(int id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(
        deletedAt: Value(now),
        lastModifiedDate: Value(now),
      ),
    );
  }

  @override
  Future<void> purgeAttachment(int id) async {
    final row = await getAttachmentById(id);
    if (row == null) return;
    if (row.localPath != null) {
      final file = File(row.localPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException {
          // Best-effort; GC tolerates missing or locked files.
        }
      }
    }
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
  }

  Future<String> _resolvePath(int id, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(filename);
    return p.join(dir.path, 'attachments', '$id$ext');
  }
}

final localAttachmentRepositoryProvider =
    Provider<IAttachmentRepository>((ref) {
  return LocalAttachmentRepository(ref.watch(hmmDatabaseProvider));
});
