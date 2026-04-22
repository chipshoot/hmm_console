/// Value types shared by every `CloudSyncProvider` implementation.
///
/// Shape follows `docs/sync_contract.md` §3 and §9.
library;

/// One note's payload, ready to push or just pulled.
class NoteBlob {
  const NoteBlob({
    required this.id,
    required this.body,
    required this.updatedAt,
    required this.deleted,
  });

  /// Stable id (string form of `notes.id`).
  final String id;

  /// Full JSON body for the note. Shape mirrors the local `notes` row.
  final Map<String, dynamic> body;

  final DateTime updatedAt;
  final bool deleted;
}

/// One attachment, optionally carrying its binary bytes.
class AttachmentBlob {
  const AttachmentBlob({
    required this.id,
    required this.noteId,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.updatedAt,
    required this.deleted,
    this.bytes,
  });

  final String id;
  final String noteId;
  final String filename;
  final String mimeType;
  final int size;

  /// Binary content. Null when this blob references a remote file that hasn't
  /// been fetched yet (manifest-only entry).
  final List<int>? bytes;

  final DateTime updatedAt;
  final bool deleted;
}

/// Entry in the cloud-side `manifest.json`.
class ManifestEntry {
  const ManifestEntry({
    required this.id,
    required this.updatedAt,
    required this.deleted,
    this.noteId,
    this.filename,
  });

  final String id;
  final DateTime updatedAt;
  final bool deleted;

  /// Only set for attachment entries.
  final String? noteId;
  final String? filename;
}

class SyncManifest {
  const SyncManifest({
    required this.version,
    required this.generatedAt,
    required this.deviceId,
    required this.notes,
    required this.attachments,
  });

  final int version;
  final DateTime generatedAt;
  final String deviceId;
  final List<ManifestEntry> notes;
  final List<ManifestEntry> attachments;
}

class SyncRequest {
  const SyncRequest({
    required this.lastPushedAt,
    required this.locallyChangedNotes,
    required this.locallyChangedAttachments,
  });

  final DateTime lastPushedAt;
  final List<NoteBlob> locallyChangedNotes;
  final List<AttachmentBlob> locallyChangedAttachments;
}

class SyncError {
  const SyncError({
    required this.recordType,
    required this.recordId,
    required this.message,
  });

  /// 'note' | 'attachment' | 'manifest' | 'auth' | 'transport'
  final String recordType;
  final String recordId;
  final String message;

  @override
  String toString() => '[$recordType:$recordId] $message';
}

class SyncResult {
  const SyncResult({
    required this.pulledNotes,
    required this.pulledAttachments,
    required this.pushedNotes,
    required this.pushedAttachments,
    required this.completedAt,
    this.errors = const [],
  });

  factory SyncResult.failed({
    required DateTime at,
    required SyncError error,
  }) =>
      SyncResult(
        pulledNotes: 0,
        pulledAttachments: 0,
        pushedNotes: 0,
        pushedAttachments: 0,
        completedAt: at,
        errors: [error],
      );

  final int pulledNotes;
  final int pulledAttachments;
  final int pushedNotes;
  final int pushedAttachments;
  final DateTime completedAt;
  final List<SyncError> errors;

  bool get success => errors.isEmpty;
}
