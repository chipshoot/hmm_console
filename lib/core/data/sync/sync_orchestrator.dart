import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_mode.dart';
import '../local/database.dart';
import 'api_sync_provider.dart';
import 'cloud_sync_provider.dart';
import 'onedrive_sync_provider.dart';
import 'sync_meta_repository.dart';
import 'sync_models.dart';

/// Glue between DataMode/CloudProvider and the active [CloudSyncProvider].
///
/// Responsibilities:
///   1. Collect notes (and attachments, once wired) changed since the
///      per-provider cursor.
///   2. Hand them to the provider's [CloudSyncProvider.sync] call.
///   3. Advance the cursor on success.
///
/// The provider itself handles the network layout (blobs + manifest) — see
/// `docs/sync_contract.md` §4–§5.
class SyncOrchestrator {
  SyncOrchestrator({
    required this.provider,
    required HmmDatabase db,
    required SyncMetaRepository meta,
  })  : _db = db,
        _meta = meta;

  /// Null when the current DataMode is Local — no sync.
  final CloudSyncProvider? provider;

  final HmmDatabase _db;
  final SyncMetaRepository _meta;

  bool get isActive => provider != null;

  Future<SyncResult> syncNow() async {
    final p = provider;
    if (p == null) {
      final now = DateTime.now().toUtc();
      return SyncResult.failed(
        at: now,
        error: const SyncError(
          recordType: 'auth',
          recordId: 'none',
          message:
              'No sync provider is active. Switch to Cloud Storage or Cloud (API) in Settings.',
        ),
      );
    }

    final cursor = await _meta.getLastPushedAt(p.providerId) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final changedNotes = await _collectChangedNotes(cursor);
    final changedAttachments = await _collectChangedAttachments(cursor);
    final request = SyncRequest(
      lastPushedAt: cursor,
      locallyChangedNotes: changedNotes,
      locallyChangedAttachments: changedAttachments,
    );

    final result = await p.sync(request);

    if (result.success) {
      await _meta.setLastPushedAt(p.providerId, result.completedAt);
    }
    return result;
  }

  Future<List<NoteBlob>> _collectChangedNotes(DateTime cursor) async {
    final rows = await (_db.select(_db.notes)
          ..where((n) => n.lastModifiedDate.isBiggerThanValue(cursor)))
        .get();
    return rows.map(_rowToBlob).toList();
  }

  Future<List<AttachmentBlob>> _collectChangedAttachments(
      DateTime cursor) async {
    final rows = await (_db.select(_db.attachments)
          ..where((a) => a.lastModifiedDate.isBiggerThanValue(cursor)))
        .get();
    final blobs = <AttachmentBlob>[];
    for (final row in rows) {
      // Don't read bytes for tombstones — they carry no payload.
      List<int>? bytes;
      if (row.deletedAt == null && row.localPath != null) {
        final file = File(row.localPath!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }
      blobs.add(AttachmentBlob(
        id: row.id.toString(),
        noteId: row.noteId.toString(),
        filename: row.filename,
        mimeType: row.mimeType,
        size: row.size,
        updatedAt: (row.lastModifiedDate ?? row.createDate).toUtc(),
        deleted: row.deletedAt != null,
        bytes: bytes,
      ));
    }
    return blobs;
  }

  NoteBlob _rowToBlob(Note n) {
    final updatedAt = n.lastModifiedDate ?? n.createDate;
    return NoteBlob(
      id: n.id.toString(),
      body: {
        'id': n.id,
        'subject': n.subject,
        'content': n.content,
        'authorId': n.authorId,
        'catalogId': n.catalogId,
        'parentNoteId': n.parentNoteId,
        'description': n.description,
        'createDate': n.createDate.toUtc().toIso8601String(),
        'lastModifiedDate': updatedAt.toUtc().toIso8601String(),
        'deletedAt': n.deletedAt?.toUtc().toIso8601String(),
      },
      updatedAt: updatedAt.toUtc(),
      deleted: n.deletedAt != null,
    );
  }

}

final syncOrchestratorProvider = Provider<SyncOrchestrator>((ref) {
  final mode = ref.watch(dataModeProvider);
  final db = ref.watch(hmmDatabaseProvider);
  final meta = ref.watch(syncMetaRepositoryProvider);

  CloudSyncProvider? provider;
  switch (mode) {
    case DataMode.local:
      provider = null;
      break;
    case DataMode.cloudApi:
      provider = ref.watch(apiSyncProviderProvider);
      break;
    case DataMode.cloudStorage:
      final cp = ref.watch(cloudProviderProvider);
      provider = switch (cp) {
        CloudProvider.onedrive => ref.watch(oneDriveSyncProviderProvider),
      };
      break;
  }
  return SyncOrchestrator(provider: provider, db: db, meta: meta);
});
