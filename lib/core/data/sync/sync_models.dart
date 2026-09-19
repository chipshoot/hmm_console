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

/// The phases of one sync run, in the order they execute. Timed
/// individually so "sync is slow" can be answered with a phase name rather
/// than a guess.
enum SyncPhase {
  adoptOrphans,
  migrateLegacy,
  settings,
  tags,
  collectLocal,
  pullManifest,
  pullNotes,
  pushNotes,
  pushManifest,
  attachments,
}

/// Where a sync's time went.
class SyncTiming {
  const SyncTiming({required this.phases, required this.total});

  /// Wall-clock duration of each phase. Every [SyncPhase] is present, so a
  /// reader never has to wonder whether a missing phase ran at all.
  final Map<SyncPhase, Duration> phases;

  /// End to end, including anything between phases.
  final Duration total;

  /// The phase that took longest — the first thing to look at.
  SyncPhase get slowest =>
      phases.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

class SyncResult {
  const SyncResult({
    required this.pulledNotes,
    required this.pulledAttachments,
    required this.pushedNotes,
    required this.pushedAttachments,
    required this.completedAt,
    this.errors = const [],
    this.timing,
  });

  factory SyncResult.failed({
    required DateTime at,
    required SyncError error,
    SyncTiming? timing,
  }) =>
      SyncResult(
        pulledNotes: 0,
        pulledAttachments: 0,
        pushedNotes: 0,
        pushedAttachments: 0,
        completedAt: at,
        errors: [error],
        timing: timing,
      );

  final int pulledNotes;
  final int pulledAttachments;
  final int pushedNotes;
  final int pushedAttachments;
  final DateTime completedAt;
  final List<SyncError> errors;

  /// Null only for results built where no run happened (e.g. the
  /// no-provider case). Every real run reports its timing, failed or not.
  final SyncTiming? timing;

  bool get success => errors.isEmpty;
}
