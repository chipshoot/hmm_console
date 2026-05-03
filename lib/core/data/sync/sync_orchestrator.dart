import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data_mode.dart';
import '../local/database.dart';
import 'api_sync_provider.dart';
import 'cloud_sync_provider.dart';
import 'onedrive_sync_provider.dart';
import 'sync_meta_repository.dart';
import 'sync_models.dart';

/// Drives the full sync algorithm (see `docs/sync_contract.md` §4–§6).
///
/// Record identity is the per-row **UUID** (stable across devices). Local
/// int PKs are never sent to the cloud. Cross-table references travel as:
///   - `catalogName` (resolved via `note_catalogs.name`, which is unique)
///   - `parentNoteUuid` (resolved via `notes.uuid`, requires a two-pass pull)
///   - `noteUuid` on attachment entries (resolved via `notes.uuid`)
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
    final startedAt = DateTime.now().toUtc();
    if (p == null) {
      return SyncResult.failed(
        at: startedAt,
        error: const SyncError(
          recordType: 'auth',
          recordId: 'none',
          message:
              'No sync provider is active. Switch to Cloud Storage or Cloud (API) in Settings.',
        ),
      );
    }

    final errors = <SyncError>[];
    int pulledNotes = 0;
    int pulledAttachments = 0;
    int pushedNotes = 0;
    int pushedAttachments = 0;

    // -------- 0. Snapshot local deltas BEFORE pull --------
    // Avoids re-uploading rows that the pull is about to overwrite.
    final cursor = await _meta.getLastPushedAt(p.providerId) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final localNoteBlobs = await _collectChangedNotes(cursor);
    final localAttachmentBlobs = await _collectChangedAttachments(cursor);

    // -------- 1. PULL: manifest --------
    SyncManifest? remote;
    try {
      remote = await p.pullManifest();
    } catch (e) {
      return SyncResult.failed(
        at: startedAt,
        error: SyncError(
          recordType: 'manifest',
          recordId: '-',
          message: 'Failed to pull manifest: $e',
        ),
      );
    }

    // Queue of (childLocalId, parentUuid) for pass 2 resolution.
    final pendingParents = <({int childId, String parentUuid})>[];

    // -------- 2. PULL: notes --------
    if (remote != null) {
      for (final entry in remote.notes) {
        try {
          final applied = await _maybePullNote(p, entry, pendingParents);
          if (applied) pulledNotes++;
        } catch (e) {
          errors.add(SyncError(
            recordType: 'note',
            recordId: entry.id,
            message: 'Pull failed: $e',
          ));
        }
      }

      // Pass 2: resolve parentNoteUuid references now that every note is
      // local.
      for (final pending in pendingParents) {
        try {
          final parent = await (_db.select(_db.notes)
                ..where((n) => n.uuid.equals(pending.parentUuid)))
              .getSingleOrNull();
          if (parent != null) {
            await (_db.update(_db.notes)
                  ..where((n) => n.id.equals(pending.childId)))
                .write(NotesCompanion(parentNoteId: Value(parent.id)));
          }
          // Parent not found — leave parentNoteId null; next sync will retry.
        } catch (e) {
          errors.add(SyncError(
            recordType: 'note',
            recordId: pending.parentUuid,
            message: 'Parent resolution failed: $e',
          ));
        }
      }

      // -------- 3. PULL: attachments --------
      for (final entry in remote.attachments) {
        try {
          final applied = await _maybePullAttachment(p, entry);
          if (applied) pulledAttachments++;
        } catch (e) {
          errors.add(SyncError(
            recordType: 'attachment',
            recordId: entry.id,
            message: 'Pull failed: $e',
          ));
        }
      }
    }

    // -------- 4. PUSH: local changes collected before pull --------
    for (final blob in localNoteBlobs) {
      try {
        await p.pushNoteBody(blob.id, blob.body);
        pushedNotes++;
      } catch (e) {
        errors.add(SyncError(
          recordType: 'note',
          recordId: blob.id,
          message: 'Push failed: $e',
        ));
      }
    }

    for (final blob in localAttachmentBlobs) {
      if (blob.deleted) {
        pushedAttachments++;
        continue;
      }
      if (blob.bytes == null) {
        errors.add(SyncError(
          recordType: 'attachment',
          recordId: blob.id,
          message: 'Local binary missing; skipping push.',
        ));
        continue;
      }
      try {
        await p.pushAttachmentBytes(
          id: blob.id,
          filename: blob.filename,
          mimeType: blob.mimeType,
          bytes: blob.bytes!,
        );
        pushedAttachments++;
      } catch (e) {
        errors.add(SyncError(
          recordType: 'attachment',
          recordId: blob.id,
          message: 'Push failed: $e',
        ));
      }
    }

    // -------- 5. PUSH: rewritten manifest --------
    try {
      final freshManifest = await _buildManifest();
      await p.pushManifest(freshManifest);
    } catch (e) {
      errors.add(SyncError(
        recordType: 'manifest',
        recordId: '-',
        message: 'Failed to push manifest: $e',
      ));
    }

    // -------- 6. Advance cursor on a clean run --------
    final completedAt = DateTime.now().toUtc();
    final result = SyncResult(
      pulledNotes: pulledNotes,
      pulledAttachments: pulledAttachments,
      pushedNotes: pushedNotes,
      pushedAttachments: pushedAttachments,
      completedAt: completedAt,
      errors: errors,
    );
    if (result.success) {
      await _meta.setLastPushedAt(p.providerId, completedAt);
    }
    return result;
  }

  // ==================== PULL helpers ====================

  Future<bool> _maybePullNote(
    CloudSyncProvider provider,
    ManifestEntry entry,
    List<({int childId, String parentUuid})> pendingParents,
  ) async {
    final uuid = entry.id;

    final local =
        await (_db.select(_db.notes)..where((n) => n.uuid.equals(uuid)))
            .getSingleOrNull();
    final localUpdatedAt = local?.lastModifiedDate ?? local?.createDate;
    if (local != null &&
        localUpdatedAt != null &&
        !entry.updatedAt.isAfter(localUpdatedAt.toUtc())) {
      return false; // LWW: local wins.
    }

    if (entry.deleted) {
      if (local != null) {
        await (_db.update(_db.notes)..where((n) => n.id.equals(local.id)))
            .write(NotesCompanion(
          deletedAt: Value(entry.updatedAt),
          lastModifiedDate: Value(entry.updatedAt),
        ));
      } else {
        // Insert tombstone so it can propagate to this device's peers.
        await _db.into(_db.notes).insert(NotesCompanion.insert(
              uuid: Value(uuid),
              subject: '(deleted)',
              authorId: await _defaultAuthorId(),
              deletedAt: Value(entry.updatedAt),
              lastModifiedDate: Value(entry.updatedAt),
              createDate: Value(entry.updatedAt),
            ));
      }
      return true;
    }

    final body = await provider.pullNoteBody(uuid);
    if (body == null) return false; // Manifest claims it exists, blob gone.

    await _applyPulledNote(uuid, entry, body, local, pendingParents);
    return true;
  }

  Future<void> _applyPulledNote(
    String uuid,
    ManifestEntry entry,
    Map<String, dynamic> body,
    Note? existing,
    List<({int childId, String parentUuid})> pendingParents,
  ) async {
    // Resolve catalog by name (name is unique; ids are device-local).
    int? catalogId;
    final catalogName = body['catalogName'] as String?;
    if (catalogName != null && catalogName.isNotEmpty) {
      final existingCat = await (_db.select(_db.noteCatalogs)
            ..where((c) => c.name.equals(catalogName)))
          .getSingleOrNull();
      if (existingCat != null) {
        catalogId = existingCat.id;
      } else {
        catalogId = await _db.into(_db.noteCatalogs).insert(
              NoteCatalogsCompanion.insert(name: catalogName, schema: '{}'),
            );
      }
    }

    final createDateRaw = body['createDate'] as String?;
    final createDate = createDateRaw != null
        ? DateTime.tryParse(createDateRaw) ?? entry.updatedAt
        : (existing?.createDate ?? entry.updatedAt);

    final parentUuid = body['parentNoteUuid'] as String?;

    int childId;
    if (existing != null) {
      await (_db.update(_db.notes)..where((n) => n.id.equals(existing.id)))
          .write(NotesCompanion(
        subject: Value(body['subject'] as String? ?? existing.subject),
        content: Value(body['content'] as String?),
        catalogId: Value(catalogId),
        parentNoteId: const Value(null), // resolved in pass 2
        description: Value(body['description'] as String?),
        lastModifiedDate: Value(entry.updatedAt),
        deletedAt: Value(entry.deleted ? entry.updatedAt : null),
      ));
      childId = existing.id;
    } else {
      final authorId = await _defaultAuthorId();
      childId = await _db.into(_db.notes).insert(
            NotesCompanion.insert(
              uuid: Value(uuid),
              subject: body['subject'] as String? ?? '(untitled)',
              content: Value(body['content'] as String?),
              authorId: authorId,
              catalogId: Value(catalogId),
              description: Value(body['description'] as String?),
              createDate: Value(createDate),
              lastModifiedDate: Value(entry.updatedAt),
              deletedAt: Value(entry.deleted ? entry.updatedAt : null),
            ),
          );
    }

    if (parentUuid != null && parentUuid.isNotEmpty) {
      pendingParents.add((childId: childId, parentUuid: parentUuid));
    }
  }

  Future<bool> _maybePullAttachment(
    CloudSyncProvider provider,
    ManifestEntry entry,
  ) async {
    final uuid = entry.id;

    final local =
        await (_db.select(_db.attachments)..where((a) => a.uuid.equals(uuid)))
            .getSingleOrNull();
    final localUpdatedAt = local?.lastModifiedDate ?? local?.createDate;
    if (local != null &&
        localUpdatedAt != null &&
        !entry.updatedAt.isAfter(localUpdatedAt.toUtc())) {
      return false;
    }

    // Resolve noteUuid → local noteId. If parent note isn't local yet, skip.
    int? noteId;
    if (entry.noteId != null) {
      final parentNote = await (_db.select(_db.notes)
            ..where((n) => n.uuid.equals(entry.noteId!)))
          .getSingleOrNull();
      noteId = parentNote?.id;
    }
    noteId ??= local?.noteId;
    if (noteId == null) return false;

    if (entry.deleted) {
      if (local != null) {
        await (_db.update(_db.attachments)
              ..where((a) => a.id.equals(local.id)))
            .write(AttachmentsCompanion(
          deletedAt: Value(entry.updatedAt),
          lastModifiedDate: Value(entry.updatedAt),
        ));
      } else {
        await _db.into(_db.attachments).insert(AttachmentsCompanion.insert(
              uuid: Value(uuid),
              noteId: noteId,
              filename: entry.filename ?? '',
              mimeType: 'application/octet-stream',
              size: 0,
              deletedAt: Value(entry.updatedAt),
              lastModifiedDate: Value(entry.updatedAt),
              createDate: Value(entry.updatedAt),
            ));
      }
      return true;
    }

    final filename = entry.filename ?? local?.filename;
    if (filename == null || filename.isEmpty) return false;

    final bytes = await provider.pullAttachmentBytes(
      id: uuid,
      filename: filename,
    );
    if (bytes == null) return false;

    final localPath = await _resolveAttachmentPath(uuid, filename);
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    if (local != null) {
      await (_db.update(_db.attachments)..where((a) => a.id.equals(local.id)))
          .write(AttachmentsCompanion(
        noteId: Value(noteId),
        filename: Value(filename),
        mimeType: Value(local.mimeType),
        size: Value(bytes.length),
        localPath: Value(localPath),
        lastModifiedDate: Value(entry.updatedAt),
        deletedAt: const Value(null),
      ));
    } else {
      await _db.into(_db.attachments).insert(AttachmentsCompanion.insert(
            uuid: Value(uuid),
            noteId: noteId,
            filename: filename,
            mimeType: _guessMime(filename),
            size: bytes.length,
            localPath: Value(localPath),
            lastModifiedDate: Value(entry.updatedAt),
            createDate: Value(entry.updatedAt),
          ));
    }
    return true;
  }

  Future<String> _resolveAttachmentPath(String uuid, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(filename);
    return p.join(dir.path, 'attachments', '$uuid$ext');
  }

  String _guessMime(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.pdf' => 'application/pdf',
      '.txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  Future<int> _defaultAuthorId() async {
    final any = await (_db.select(_db.authors)..limit(1)).getSingleOrNull();
    if (any != null) return any.id;
    return _db.into(_db.authors).insert(
          AuthorsCompanion.insert(accountName: 'local-user'),
        );
  }

  // ==================== PUSH collection ====================

  Future<List<NoteBlob>> _collectChangedNotes(DateTime cursor) async {
    final rows = await (_db.select(_db.notes)
          ..where((n) => n.lastModifiedDate.isBiggerThanValue(cursor)))
        .get();
    if (rows.isEmpty) return [];

    // Batch resolve catalog names and parent uuids.
    final catalogIds = rows.map((r) => r.catalogId).whereType<int>().toSet();
    final parentIds = rows.map((r) => r.parentNoteId).whereType<int>().toSet();

    final catalogNames = <int, String>{};
    if (catalogIds.isNotEmpty) {
      final cats = await (_db.select(_db.noteCatalogs)
            ..where((c) => c.id.isIn(catalogIds)))
          .get();
      for (final c in cats) {
        catalogNames[c.id] = c.name;
      }
    }

    final parentUuids = <int, String>{};
    if (parentIds.isNotEmpty) {
      final parents = await (_db.select(_db.notes)
            ..where((n) => n.id.isIn(parentIds)))
          .get();
      for (final parent in parents) {
        final u = parent.uuid;
        if (u != null) parentUuids[parent.id] = u;
      }
    }

    final blobs = <NoteBlob>[];
    for (final n in rows) {
      if (n.uuid == null) continue; // Shouldn't happen post-migration.
      blobs.add(_noteRowToBlob(n, catalogNames, parentUuids));
    }
    return blobs;
  }

  NoteBlob _noteRowToBlob(
    Note n,
    Map<int, String> catalogNames,
    Map<int, String> parentUuids,
  ) {
    final updatedAt = (n.lastModifiedDate ?? n.createDate).toUtc();
    final uuid = n.uuid!;
    final catalogName =
        n.catalogId != null ? catalogNames[n.catalogId!] : null;
    final parentUuid =
        n.parentNoteId != null ? parentUuids[n.parentNoteId!] : null;
    return NoteBlob(
      id: uuid,
      body: {
        'uuid': uuid,
        'subject': n.subject,
        'content': n.content,
        'catalogName': catalogName,
        'parentNoteUuid': parentUuid,
        'description': n.description,
        'createDate': n.createDate.toUtc().toIso8601String(),
        'lastModifiedDate': updatedAt.toIso8601String(),
        'deletedAt': n.deletedAt?.toUtc().toIso8601String(),
      },
      updatedAt: updatedAt,
      deleted: n.deletedAt != null,
    );
  }

  Future<List<AttachmentBlob>> _collectChangedAttachments(
    DateTime cursor,
  ) async {
    final rows = await (_db.select(_db.attachments)
          ..where((a) => a.lastModifiedDate.isBiggerThanValue(cursor)))
        .get();
    if (rows.isEmpty) return [];

    // Batch resolve parent-note uuids for the attachment's noteId.
    final noteIds = rows.map((r) => r.noteId).toSet();
    final noteUuids = <int, String>{};
    if (noteIds.isNotEmpty) {
      final noteRows = await (_db.select(_db.notes)
            ..where((n) => n.id.isIn(noteIds)))
          .get();
      for (final n in noteRows) {
        final u = n.uuid;
        if (u != null) noteUuids[n.id] = u;
      }
    }

    final blobs = <AttachmentBlob>[];
    for (final row in rows) {
      if (row.uuid == null) continue;
      final noteUuid = noteUuids[row.noteId];
      if (noteUuid == null) continue;

      List<int>? bytes;
      if (row.deletedAt == null && row.localPath != null) {
        final file = File(row.localPath!);
        if (await file.exists()) bytes = await file.readAsBytes();
      }
      blobs.add(AttachmentBlob(
        id: row.uuid!,
        noteId: noteUuid,
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

  // ==================== Manifest build ====================

  Future<SyncManifest> _buildManifest() async {
    final deviceId = await _meta.getOrCreateDeviceId();
    final allNotes = await _db.select(_db.notes).get();
    final allAttachments = await _db.select(_db.attachments).get();

    // noteId → note.uuid for attachment entries.
    final noteUuidById = <int, String>{};
    for (final n in allNotes) {
      final u = n.uuid;
      if (u != null) noteUuidById[n.id] = u;
    }

    return SyncManifest(
      version: 1,
      generatedAt: DateTime.now().toUtc(),
      deviceId: deviceId,
      notes: allNotes
          .where((n) => n.uuid != null)
          .map((n) {
        final updatedAt = (n.lastModifiedDate ?? n.createDate).toUtc();
        return ManifestEntry(
          id: n.uuid!,
          updatedAt: updatedAt,
          deleted: n.deletedAt != null,
        );
      }).toList(),
      attachments: allAttachments
          .where((a) => a.uuid != null && noteUuidById.containsKey(a.noteId))
          .map((a) {
        final updatedAt = (a.lastModifiedDate ?? a.createDate).toUtc();
        return ManifestEntry(
          id: a.uuid!,
          updatedAt: updatedAt,
          deleted: a.deletedAt != null,
          noteId: noteUuidById[a.noteId],
          filename: a.filename,
        );
      }).toList(),
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
