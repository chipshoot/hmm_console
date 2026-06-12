import '../local/local_tag_repository.dart';

/// Merges tag *definitions* for cloudStorage sync. Membership is handled
/// separately (it rides with the note sync — see SyncOrchestrator).
class TagSyncService {
  TagSyncService(this._repo);

  final LocalTagRepository _repo;

  String _norm(String s) => s.toLowerCase().trim();

  /// Apply remote-newer definitions to the local store, then return the merged
  /// document (every name at its winning version) to push back.
  Future<Map<String, dynamic>> mergeDefinitions(
    Map<String, dynamic>? remoteDoc, {
    required String deviceId,
    required DateTime now,
  }) async {
    final local = await _repo.getTagsWithMeta();
    final localByName = {for (final t in local) _norm(t.name): t};

    // Parse remote records defensively.
    final remote = <String, _RemoteTag>{};
    final rawTags = (remoteDoc?['tags'] as List?) ?? const [];
    for (final raw in rawTags) {
      if (raw is! Map) continue;
      final t = _RemoteTag.tryParse(raw.cast<String, dynamic>());
      if (t != null) remote[_norm(t.name)] = t;
    }

    // Apply remote-wins.
    for (final r in remote.values) {
      final l = localByName[_norm(r.name)];
      final isNewer = l == null || r.lastModified.isAfter(l.lastModified);
      if (!isNewer) continue;
      if (r.deleted) {
        if (l != null) await _repo.tombstoneTagByName(r.name, r.lastModified);
      } else {
        await _repo.upsertTagByName(
          r.name,
          description: r.description,
          isActivated: r.isActivated,
          lastModified: r.lastModified,
        );
      }
    }

    // Merged local state == every name at its winning version.
    final merged = await _repo.getTagsWithMeta();
    return {
      'version': 1,
      'device_id': deviceId,
      'generated_at': now.toUtc().toIso8601String(),
      'tags': [
        for (final t in merged)
          {
            'name': t.name,
            'description': t.description,
            'is_activated': t.isActivated,
            'last_modified': t.lastModified.toUtc().toIso8601String(),
            'deleted': t.deletedAt != null,
          },
      ],
    };
  }
}

class _RemoteTag {
  _RemoteTag({
    required this.name,
    required this.description,
    required this.isActivated,
    required this.lastModified,
    required this.deleted,
  });

  final String name;
  final String? description;
  final bool isActivated;
  final DateTime lastModified;
  final bool deleted;

  static _RemoteTag? tryParse(Map<String, dynamic> j) {
    final name = j['name'];
    final lm = DateTime.tryParse(j['last_modified'] as String? ?? '');
    if (name is! String || name.trim().isEmpty || lm == null) return null;
    return _RemoteTag(
      name: name,
      description: j['description'] as String?,
      isActivated: j['is_activated'] as bool? ?? true,
      lastModified: lm,
      deleted: j['deleted'] as bool? ?? false,
    );
  }
}
