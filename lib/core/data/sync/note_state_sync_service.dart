import '../../notes/note_state.dart';
import '../local/local_note_state_repository.dart';

/// Result of [NoteStateSyncService.merge].
class NoteStateMerge {
  const NoteStateMerge({required this.document, required this.localWins});

  /// Every surviving state at its winning version — the document to push.
  final Map<String, dynamic> document;

  /// Note uuids whose local state is strictly newer than the remote one, or
  /// absent remotely: what a per-row remote must receive.
  final Set<String> localWins;
}

/// Merges note states (pins + flags, Notes redesign G14) per entry, the
/// same way [TagSyncService] merges tag definitions: newer `lastModified`
/// wins, a tie keeps local. Entries for notes that no longer exist
/// ([knownNoteUuids] excludes them — purged notes, content-free tombstones)
/// are neither applied nor pushed, and their local rows are dropped.
class NoteStateSyncService {
  NoteStateSyncService(this._repo);

  final LocalNoteStateRepository _repo;

  Future<NoteStateMerge> merge(
    Map<String, dynamic>? remoteDoc, {
    required Set<String> knownNoteUuids,
    required String deviceId,
    required DateTime now,
  }) async {
    // 1. Drop local states whose note no longer exists anywhere.
    final local = await _repo.getAllStates();
    for (final uuid in local.keys.toList()) {
      if (!knownNoteUuids.contains(uuid)) {
        await _repo.deleteState(uuid);
        local.remove(uuid);
      }
    }

    // 2. Parse remote entries defensively; ignore unknown notes.
    final remote = <String, NoteState>{};
    for (final raw in (remoteDoc?['states'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final s = _parse(raw.cast<String, dynamic>());
      if (s != null && knownNoteUuids.contains(s.noteUuid)) {
        remote[s.noteUuid] = s;
      }
    }

    // 3. Remote-newer wins; a tie keeps local.
    for (final r in remote.values) {
      final l = local[r.noteUuid];
      if (l == null || r.lastModifiedDate.isAfter(l.lastModifiedDate)) {
        await _repo.putState(r);
      }
    }

    // 4. What the remote is missing or holds older.
    final localWins = <String>{
      for (final l in local.values)
        if (remote[l.noteUuid] == null ||
            l.lastModifiedDate.isAfter(remote[l.noteUuid]!.lastModifiedDate))
          l.noteUuid,
    };

    final merged = await _repo.getAllStates();
    final uuids = merged.keys.toList()..sort();
    return NoteStateMerge(
      document: {
        'version': 1,
        'device_id': deviceId,
        'generated_at': now.toUtc().toIso8601String(),
        'states': [
          for (final uuid in uuids)
            {
              'noteUuid': uuid,
              'isPinned': merged[uuid]!.isPinned,
              'flagColor': merged[uuid]!.flagColor,
              'lastModified': merged[uuid]!.lastModifiedDate
                  .toUtc()
                  .toIso8601String(),
            },
        ],
      },
      localWins: localWins,
    );
  }

  static NoteState? _parse(Map<String, dynamic> j) {
    final uuid = j['noteUuid'];
    final at = DateTime.tryParse(j['lastModified'] as String? ?? '');
    if (uuid is! String || uuid.isEmpty || at == null) return null;
    final flag = j['flagColor'];
    return NoteState(
      noteUuid: uuid,
      isPinned: j['isPinned'] is bool ? j['isPinned'] as bool : false,
      // Any int is kept verbatim (a newer client's colour shows grey).
      flagColor: flag is num ? flag.toInt() : null,
      lastModifiedDate: at.toUtc(),
    );
  }
}
