// Real implementation of [CloudSyncProvider] against the Hmm REST API.
// Replaces the Phase 11.5 stub that threw `_notImplemented` on every
// method.
//
// Wire mapping
//   pullManifest   GET /v1/notes?includeDeleted=true (paginated; X-Pagination)
//   pullNoteBody   GET /v1/notes/by-uuid/{uuid}?includeDeleted=true
//   pushNoteBody   POST /v1/notes or PUT /v1/notes/{id} (existence check
//                  by uuid first) — DELETE /v1/notes/{id} when the
//                  pushed body carries deletedAt
//   pushManifest   no-op (server-side rows are the manifest; nothing
//                  to push)
//   restore        POST /v1/notes/{id}/restore before the PUT when the
//                  server row is soft-deleted but the pushed body is live
//   tags           GET|POST /v1/tags, DELETE /v1/tags/{id} (definitions);
//                  PUT /v1/notes/{id}/tags (membership, set-replace)
//   note states    GET /v1/notes/states, PUT /v1/notes/{id}/state
//                  (pins + flags; 404 on the GET = server too old)
//
// The provider stays stateful only for the duration of a single sync
// run — Riverpod rebuilds it on every container read so the per-
// session caches (author id, catalog name → id) start empty each
// cycle.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/api_client.dart';
import '../../network/idp_token_service.dart';
import 'cloud_sync_provider.dart';
import 'sync_models.dart';

/// Thrown when the server returns something the provider can't
/// reasonably translate to the orchestrator's body shape (missing
/// catalog, malformed envelope, etc.). Distinct from
/// [DioException] so the orchestrator can tell "transport failed"
/// from "server said something we don't understand."
class ApiSyncProviderException implements Exception {
  const ApiSyncProviderException(this.message);
  final String message;
  @override
  String toString() => 'ApiSyncProviderException: $message';
}

class ApiSyncProvider implements CloudSyncProvider {
  ApiSyncProvider({
    required ApiClient client,
    required IdpTokenService tokenService,
  }) : _dio = client.dio,
       _tokenService = tokenService;

  final Dio _dio;
  final IdpTokenService _tokenService;

  /// Lazy author-id cache. Filled on the first push (pulls don't
  /// need it). One author per JWT subject today; if the server ever
  /// grows multi-author-per-user, we'll add a `/authors/me` endpoint
  /// and key off that.
  int? _cachedAuthorId;

  /// Lazy catalogName → catalogId cache. The orchestrator's body
  /// uses catalog name as the cross-device-stable handle; the
  /// server still keys catalogs by int Id, so we translate here.
  final Map<String, int> _catalogIdByName = {};

  /// Lower-cased tag name → server tag id, filled by [pullTags] and used by
  /// [pushTags] in the same sync run (the orchestrator calls them in order).
  final Map<String, int> _serverTagIdByName = {};

  /// The server keeps no per-tag modification time; epoch 0 means a server
  /// tag only fills a gap locally and never overrides a local edit or
  /// tombstone in `TagSyncService`'s last-writer-wins merge.
  static final DateTime _tagEpoch = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  @override
  String get providerId => 'hmm_api';

  // ============================================================
  // Auth
  // ============================================================

  @override
  Future<bool> isAuthenticated() async {
    // The IdP token flow is shared with the rest of the app — the
    // sync provider just checks the storage already holds a valid
    // access token. No separate login flow for the sync provider.
    final claims = await _tokenService.getStoredClaims();
    return claims != null;
  }

  @override
  Future<void> signIn() {
    // Sync provider doesn't own the IdP login dance — the app's
    // standard login screen does. Surfacing this as an error
    // catches the (unlikely) caller that wires the cloud-sync
    // settings sheet to provider.signIn instead of the auth UI.
    throw UnsupportedError(
      'ApiSyncProvider.signIn — use the IdP login flow '
      '(authNotifier.signIn / login screen) instead. '
      'The sync provider only consumes existing tokens.',
    );
  }

  @override
  Future<void> signOut() async {
    // Intentional no-op. Clearing tokens here would sign the user
    // out of the entire app — too aggressive for a "disable cloud
    // sync" gesture. The app's auth flow owns sign-out.
  }

  // ============================================================
  // Pull
  // ============================================================

  @override
  Future<SyncManifest?> pullManifest() async {
    // Paginate through every note (including soft-deleted, so
    // tombstones propagate to other devices). The collection
    // endpoint wraps the array in { value, links } and ships a
    // JSON `X-Pagination` header with currentPage / totalPages.
    final entries = <ManifestEntry>[];
    var page = 1;
    while (true) {
      final resp = await _dio.get<dynamic>(
        '/notes',
        queryParameters: {
          'includeDeleted': true,
          'PageNumber': page,
          'PageSize': 100,
        },
      );
      final value = _unwrapValueList(resp.data);
      for (final raw in value) {
        if (raw is! Map) continue;
        final entry = _manifestEntryFrom(raw);
        if (entry != null) entries.add(entry);
      }
      final pageInfo = _readPaginationHeader(resp.headers);
      final totalPages = pageInfo?['totalPages'] as int? ?? 1;
      if (page >= totalPages) break;
      page++;
    }

    // First-ever sync: no notes on the server. Returning null
    // (rather than an empty manifest) matches what the OneDrive
    // provider does for a fresh cloud namespace.
    if (entries.isEmpty) return null;

    return SyncManifest(
      version: 1,
      generatedAt: DateTime.now().toUtc(),
      // We don't get a device id back from the API for the
      // manifest itself — the orchestrator's pushManifest stays a
      // no-op for this provider, so the value isn't authoritative.
      deviceId: 'hmm-api',
      notes: entries,
      attachments: const [],
    );
  }

  @override
  Future<Map<String, dynamic>?> pullNoteBody(String uuid) async {
    if (uuid.isEmpty) return null;
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/notes/by-uuid/$uuid',
        queryParameters: {'includeDeleted': true},
      );
      final data = resp.data;
      if (data == null) return null;
      return _orchestratorBodyFromApiNote(data);
    } on DioException catch (e) {
      // 404 maps cleanly to "no such note" — the orchestrator
      // treats null as "manifest claimed it but body is gone,"
      // which is exactly the right behaviour here too.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ============================================================
  // Push
  // ============================================================

  @override
  Future<void> pushNoteBody(String uuid, Map<String, dynamic> body) async {
    if (uuid.isEmpty) {
      throw const ApiSyncProviderException(
        'pushNoteBody requires a non-empty uuid.',
      );
    }

    // Existence check first — the orchestrator hands us the same
    // method for creates and updates, and the server splits the
    // two onto different routes. by-uuid is a single indexed
    // probe, cheap enough to do per push at v1 volumes.
    Map<String, dynamic>? existing;
    try {
      final probe = await _dio.get<Map<String, dynamic>>(
        '/notes/by-uuid/$uuid',
        queryParameters: {'includeDeleted': true},
      );
      existing = probe.data;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
      existing = null;
    }

    final deletedAtRaw = body['deletedAt'] as String?;
    final isDeletedPush = deletedAtRaw != null && deletedAtRaw.isNotEmpty;

    if (existing == null) {
      // Server-side delete-only with no row to delete is a no-op —
      // pushing a tombstone for a note the server never saw would
      // create it just to delete it.
      if (isDeletedPush) return;
      await _createNote(uuid, body);
      return;
    }

    final existingId = existing['id'] as int?;
    if (existingId == null) {
      throw const ApiSyncProviderException(
        'Server returned a note without an id during push existence check.',
      );
    }
    final serverDeleted = (existing['isDeleted'] as bool?) ?? false;

    if (isDeletedPush) {
      // Already a tombstone on the server: nothing to do (re-deleting used
      // to 500 because the controller cannot load a deleted note).
      if (serverDeleted) return;
      await _dio.delete<void>('/notes/$existingId');
      return;
    }

    if (serverDeleted) {
      // A restore (Recently Deleted → Undo/Restore). The server refuses a
      // PUT on a soft-deleted note, so flip IsDeleted back first.
      await _restoreNote(existingId);
    }
    await _updateNote(existingId, uuid, body);
    await _pushTagMembership(existingId, body);
  }

  @override
  Future<void> pushManifest(SyncManifest manifest) async {
    // Intentional no-op. On the API tier the server-side rows ARE
    // the manifest — there's no separate manifest blob to write.
    // Keeping the method as a no-op (rather than throwing) lets
    // the orchestrator's existing pushManifest call site stay
    // uniform across providers.
  }

  // ============================================================
  // Helpers
  // ============================================================

  Future<int> _resolveAuthorId() async {
    final cached = _cachedAuthorId;
    if (cached != null) return cached;
    final resp = await _dio.get<dynamic>(
      '/authors',
      queryParameters: {'PageSize': 1},
    );
    final list = _unwrapValueList(resp.data);
    if (list.isEmpty) {
      throw const ApiSyncProviderException(
        'No author returned from /v1/authors for the current user.',
      );
    }
    final id = (list.first as Map)['id'] as int?;
    if (id == null) {
      throw const ApiSyncProviderException(
        '/v1/authors response missing "id" field.',
      );
    }
    _cachedAuthorId = id;
    return id;
  }

  Future<int> _resolveCatalogId(String name) async {
    if (_catalogIdByName.isEmpty) {
      // Catalogs are a small, slow-changing table — one fetch per
      // sync session is cheap insurance against per-note round
      // trips.
      final resp = await _dio.get<dynamic>(
        '/notecatalogs',
        queryParameters: {'PageSize': 200},
      );
      final list = _unwrapValueList(resp.data);
      for (final raw in list) {
        if (raw is! Map) continue;
        final n = raw['name'] as String?;
        final id = raw['id'] as int?;
        if (n != null && id != null) _catalogIdByName[n] = id;
      }
    }
    final id = _catalogIdByName[name];
    if (id == null) {
      throw ApiSyncProviderException(
        'Catalog "$name" not found on server. '
        'Create it via /v1/notecatalogs before syncing notes that reference it.',
      );
    }
    return id;
  }

  Future<void> _createNote(String uuid, Map<String, dynamic> body) async {
    final authorId = await _resolveAuthorId();
    final catalogName = body['catalogName'] as String?;
    final catalogId = catalogName != null && catalogName.isNotEmpty
        ? await _resolveCatalogId(catalogName)
        : 0;
    final payload = <String, dynamic>{
      'uuid': uuid,
      'subject': body['subject'] ?? '(untitled)',
      'content': body['content'] ?? '',
      'authorId': authorId,
      'catalogId': catalogId,
      'description': body['description'],
    };
    final resp = await _dio.post<dynamic>('/notes', data: payload);
    final data = resp.data;
    final newId = data is Map ? data['id'] as int? : null;
    if (newId != null) await _pushTagMembership(newId, body);
  }

  Future<void> _updateNote(
    int existingId,
    String uuid,
    Map<String, dynamic> body,
  ) async {
    final payload = <String, dynamic>{
      'uuid': uuid,
      'subject': body['subject'] ?? '(untitled)',
      'content': body['content'] ?? '',
      'description': body['description'],
    };
    await _dio.put<void>('/notes/$existingId', data: payload);
  }

  Future<void> _restoreNote(int id) async {
    try {
      await _dio.post<void>('/notes/$id/restore');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405) {
        throw const ApiSyncProviderException(
          'The server cannot restore deleted notes yet (no /notes/{id}/restore). '
          'Deploy the latest Hmm API, then sync again.',
        );
      }
      rethrow;
    }
  }

  /// Set-replace the note's tags on the server when the body carries a
  /// `tags` list (the complete set, as in cloudStorage).
  Future<void> _pushTagMembership(int noteId, Map<String, dynamic> body) async {
    if (!body.containsKey('tags')) return;
    final names =
        (body['tags'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    try {
      await _dio.put<void>('/notes/$noteId/tags', data: {'names': names});
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405) {
        // Server predates note tags. The note itself synced; its tags follow
        // once the server is updated (the note is re-pushed on its next edit).
        debugPrint(
          'ApiSyncProvider: no note-tags endpoint ($code) for note $noteId',
        );
        return;
      }
      rethrow;
    }
  }

  /// Decode the server's `X-Pagination` header value. Returns null
  /// if missing / malformed — the caller treats that as "single
  /// page."
  static Map<String, dynamic>? _readPaginationHeader(Headers headers) {
    final raw = headers.value('x-pagination');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// The collection endpoints (`/notes`, `/authors`, `/notecatalogs`)
  /// wrap their array in `{ value: [...], links: [...] }` via the
  /// server's CollectionResultFilter. This unwraps that shape and
  /// returns the inner list; also tolerates a bare array in case a
  /// caller hits an endpoint that doesn't wrap.
  static List<dynamic> _unwrapValueList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final v = data['value'];
      if (v is List) return v;
    }
    return const [];
  }

  /// Build a [ManifestEntry] for the orchestrator from a raw ApiNote
  /// map. Notes without a uuid (legacy rows pre-Phase-15b) are
  /// skipped — the orchestrator can't key them.
  static ManifestEntry? _manifestEntryFrom(Map raw) {
    final uuid = raw['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) return null;
    final isDeleted = (raw['isDeleted'] as bool?) ?? false;
    final modifiedRaw =
        raw['lastModifiedDate'] as String? ?? raw['createDate'] as String?;
    final modified = modifiedRaw != null
        ? DateTime.tryParse(modifiedRaw)?.toUtc() ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();
    return ManifestEntry(id: uuid, updatedAt: modified, deleted: isDeleted);
  }

  /// Translate the server's ApiNote shape to the orchestrator's
  /// note-body shape. Mostly a rename: ApiNote.catalogName →
  /// catalogName (already lined up since the server addition).
  /// parentNoteUuid stays null because the server doesn't model
  /// note threading.
  static Map<String, dynamic> _orchestratorBodyFromApiNote(
    Map<String, dynamic> apiNote,
  ) {
    final isDeleted = (apiNote['isDeleted'] as bool?) ?? false;
    final modifiedRaw = apiNote['lastModifiedDate'] as String?;
    return <String, dynamic>{
      'uuid': apiNote['uuid'],
      'subject': apiNote['subject'],
      'content': apiNote['content'],
      'catalogName': apiNote['catalogName'],
      'parentNoteUuid': null,
      'description': apiNote['description'],
      'createDate': apiNote['createDate'],
      'lastModifiedDate': modifiedRaw,
      'deletedAt': isDeleted ? modifiedRaw : null,
      // Only what the server actually sent: an older server has no
      // tagNames, and an absent `tags` key makes the orchestrator keep the
      // local membership instead of wiping it. Pin/flag never ride the note
      // body (G14) — see pullNoteStates.
      if (apiNote['tagNames'] is List)
        'tags': (apiNote['tagNames'] as List).whereType<String>().toList(),
    };
  }

  // ---- Settings (Phase D.2) ----
  //
  // Bundle sync against the server's `/v1/profile/settings` endpoint
  // (Phase P1/P2). The bundle is the same `SyncableSettings` shape the
  // OneDrive tier file-syncs; the server stores it opaquely and the
  // orchestrator's step-0b LWW logic drives both legs unchanged. A 204
  // ("cloud has nothing yet") maps to null → orchestrator seeds local.

  @override
  Future<Map<String, dynamic>?> pullSettings() async {
    try {
      final resp = await _dio.get<dynamic>('/profile/settings');
      if (resp.statusCode == 204) return null;
      final data = resp.data;
      return data is Map<String, dynamic> ? data : null;
    } on DioException catch (e) {
      // The server returns 204 (not 404) for absence, but treat a 404
      // as "nothing stored yet" defensively rather than failing sync.
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> pushSettings(Map<String, dynamic> body) async {
    await _dio.put<void>('/profile/settings', data: body);
  }

  // ---- Tags ----
  //
  // Definitions come from /v1/tags (no per-tag timestamps on the server, see
  // [_tagEpoch]); membership rides each note push (PUT /notes/{id}/tags) and
  // pull (ApiNote.tagNames).

  @override
  Future<Map<String, dynamic>?> pullTags() async {
    _serverTagIdByName.clear();
    final tags = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final resp = await _dio.get<dynamic>(
        '/tags',
        queryParameters: {'PageNumber': page, 'PageSize': 100},
      );
      for (final raw in _unwrapValueList(resp.data)) {
        if (raw is! Map) continue;
        final name = (raw['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        final id = raw['id'] as int?;
        if (id != null) _serverTagIdByName[name.toLowerCase()] = id;
        tags.add({
          'name': name,
          'description': raw['description'],
          'is_activated': (raw['isActivated'] as bool?) ?? true,
          'last_modified': _tagEpoch.toIso8601String(),
          'deleted': false,
        });
      }
      final totalPages =
          _readPaginationHeader(resp.headers)?['totalPages'] as int? ?? 1;
      if (page >= totalPages) break;
      page++;
    }
    return {'version': 1, 'tags': tags};
  }

  @override
  Future<void> pushTags(Map<String, dynamic> doc) async {
    final rawTags = (doc['tags'] as List?) ?? const [];
    var failed = 0;
    for (final raw in rawTags) {
      if (raw is! Map) continue;
      final name = (raw['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final key = name.toLowerCase();
      final deleted = (raw['deleted'] as bool?) ?? false;
      final serverId = _serverTagIdByName[key];
      try {
        if (deleted) {
          if (serverId == null) continue;
          await _dio.delete<void>('/tags/$serverId'); // deactivates server-side
          _serverTagIdByName.remove(key);
        } else if (serverId == null) {
          final resp = await _dio.post<dynamic>(
            '/tags',
            data: {'name': name, 'description': raw['description']},
          );
          final data = resp.data;
          final id = data is Map ? data['id'] as int? : null;
          if (id != null) _serverTagIdByName[key] = id;
        }
      } on DioException catch (e) {
        // One bad tag (e.g. a deactivated server tag whose name is taken)
        // must not stop the rest. Log status only, never the tag name.
        debugPrint(
          'ApiSyncProvider: tag push failed (${e.response?.statusCode})',
        );
        failed++;
      }
    }
    if (failed > 0) {
      throw ApiSyncProviderException(
        '$failed tag(s) failed to push; retrying next sync.',
      );
    }
  }

  // ---- Note states (pins + flags, G14) ----
  //
  // GET /v1/notes/states returns the caller's rows; PUT
  // /v1/notes/{id}/state upserts one (the server keeps the newer
  // lastModifiedDate). The orchestrator merges, then hands us the uuids
  // whose local state won.

  /// note uuid → server note id, filled by [pullNoteStates] and used by
  /// [pushNoteStates] in the same sync run.
  final Map<String, int> _serverNoteIdByUuid = {};

  @override
  Future<Map<String, dynamic>?> pullNoteStates() async {
    _serverNoteIdByUuid.clear();
    final Response<dynamic> resp;
    try {
      resp = await _dio.get<dynamic>('/notes/states');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405) {
        // A server older than the notes redesign: keep local state.
        throw const NoteStatesUnsupportedException();
      }
      rethrow;
    }
    final states = <Map<String, dynamic>>[];
    for (final raw in _unwrapValueList(resp.data)) {
      if (raw is! Map) continue;
      final uuid = raw['noteUuid'] as String?;
      final id = raw['noteId'] as int?;
      final at = DateTime.tryParse(raw['lastModifiedDate'] as String? ?? '');
      if (uuid == null || uuid.isEmpty || at == null) continue;
      if (id != null) _serverNoteIdByUuid[uuid] = id;
      states.add({
        'noteUuid': uuid,
        'isPinned': (raw['isPinned'] as bool?) ?? false,
        'flagColor': (raw['flagColor'] as num?)?.toInt(),
        'lastModified': at.toUtc().toIso8601String(),
      });
    }
    return {'version': 1, 'states': states};
  }

  @override
  Future<void> pushNoteStates(
    Map<String, dynamic> doc, {
    required Set<String> changed,
  }) async {
    if (changed.isEmpty) return;
    final byUuid = <String, Map>{
      for (final raw in (doc['states'] as List?) ?? const [])
        if (raw is Map && raw['noteUuid'] is String)
          raw['noteUuid'] as String: raw,
    };
    var failed = 0;
    for (final uuid in changed) {
      final s = byUuid[uuid];
      if (s == null) continue;
      try {
        final id = _serverNoteIdByUuid[uuid] ?? await _serverIdForUuid(uuid);
        if (id == null) continue; // not on the server yet; retried next sync
        await _dio.put<dynamic>(
          '/notes/$id/state',
          data: {
            'isPinned': (s['isPinned'] as bool?) ?? false,
            'flagColor': s['flagColor'],
            'lastModifiedDate': s['lastModified'],
          },
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) continue; // note gone meanwhile
        failed++;
      }
    }
    if (failed > 0) {
      throw ApiSyncProviderException(
        '$failed note state(s) failed to push; retrying next sync.',
      );
    }
  }

  Future<int?> _serverIdForUuid(String uuid) async {
    try {
      final probe = await _dio.get<Map<String, dynamic>>(
        '/notes/by-uuid/$uuid',
        queryParameters: {'includeDeleted': true},
      );
      final id = probe.data?['id'] as int?;
      if (id != null) _serverNoteIdByUuid[uuid] = id;
      return id;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ---- Attachments ----
  // cloudApi bytes route through the future ApiVaultStore (Phase 15), not the
  // sync provider. No-ops keep _reconcileVault inert for this provider.

  @override
  bool get supportsAttachments => false;

  @override
  Future<void> pushAttachment(String path, Uint8List bytes) async {}

  @override
  Future<Uint8List?> pullAttachment(String path) async => null;

  @override
  Future<Set<String>> listAttachmentPaths() async => const {};
}

/// Riverpod provider for [ApiSyncProvider]. Fresh per container read
/// — caches reset every sync cycle.
final apiSyncProviderProvider = Provider<CloudSyncProvider>((ref) {
  return ApiSyncProvider(
    client: ref.watch(apiClientProvider),
    tokenService: ref.watch(idpTokenServiceProvider),
  );
});
