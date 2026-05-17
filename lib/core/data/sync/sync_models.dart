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

// `AttachmentBlob` was retired in Phase 11.5 (2026-05-17) along with
// the CloudSyncProvider attachment-byte methods. Attachment refs now
// live in `Notes.attachments`; bytes travel out-of-band (OS sync
// client for cloudStorage; future ApiVaultStore for cloudApi).

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
