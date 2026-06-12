import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/idp_token_service.dart';
import 'onedrive_auth.dart';
import 'sync_models.dart';

class OneDriveGraphException implements Exception {
  const OneDriveGraphException({
    required this.statusCode,
    required this.message,
    this.responseBody,
  });

  final int statusCode;
  final String message;
  final String? responseBody;

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() =>
      'OneDriveGraphException($statusCode): $message${responseBody == null ? '' : '\n$responseBody'}';
}

/// Returns the Hmm IDP `sub` claim of the currently-signed-in user, or
/// null when nobody is signed in. Extracted as a typedef so tests can pass
/// a fake without dragging the full `IdpTokenService` (and its token
/// storage + JWT decoding) into the test harness.
typedef CurrentUserSubResolver = Future<String?> Function();

/// Thin Microsoft Graph REST client scoped to the app folder
/// (`/drive/special/approot`). Pairs with [OneDriveAuth]; a request-time
/// interceptor attaches a fresh bearer token.
///
/// **Per-user namespacing.** All notes + manifest live under
/// `approot/users/{sub}/`, where `{sub}` is the Hmm IDP user's `sub`
/// claim. Two Hmm users signed in to the same Microsoft / OneDrive
/// account therefore get separate subtrees and cannot clobber each
/// other. The legacy single-user layout (notes at `approot/notes/`) is
/// preserved in place; the orchestrator migrates it into the current
/// user's subtree on first post-upgrade sync (see
/// [OneDriveSyncProvider.migrateLegacyIfNeeded]).
///
/// Endpoint shape reference (after this layout change):
/// - `PUT /me/drive/special/approot:/users/{sub}/notes/{id}.json:/content`
/// - `GET /me/drive/special/approot:/users/{sub}/manifest.json:/content`
class OneDriveGraphClient {
  OneDriveGraphClient(
    this._auth,
    this._currentUserSub, {
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://graph.microsoft.com/v1.0',
              responseType: ResponseType.json,
              validateStatus: (_) => true, // Let us branch on status ourselves.
            )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _auth.getAccessToken();
          if (token == null) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: const OneDriveGraphException(
                  statusCode: 401,
                  message: 'Not signed in to OneDrive.',
                ),
              ),
            );
            return;
          }
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
  }

  final OneDriveAuth _auth;
  final CurrentUserSubResolver _currentUserSub;
  final Dio _dio;

  /// Top of the Microsoft Graph "special app folder" addressing scheme.
  /// The `:` is the delimiter between the special-folder selector and
  /// the relative path that follows; per-call helpers below append the
  /// rest. Kept as a single constant so the legacy + user-scoped paths
  /// stay textually consistent.
  static const _approot = '/me/drive/special/approot';

  // ---- Per-user path builders ----

  /// Builds a path of the form
  ///   `/me/drive/special/approot:/users/{sub}/{rel}[:/action]`
  /// for the currently-signed-in Hmm user. Throws
  /// [OneDriveGraphException] (401) if no user is signed in — callers
  /// must surface this as an "auth" sync error rather than fall through
  /// to an unscoped path.
  Future<String> _userPath(String relative, {String? action}) async {
    final sub = await _currentUserSub();
    if (sub == null || sub.isEmpty) {
      throw const OneDriveGraphException(
        statusCode: 401,
        message:
            'Cannot sync to OneDrive: no authenticated Hmm user (sub claim '
            'missing). Sign back in to the app and retry.',
      );
    }
    // URL-encode the sub even though current IDP issues hex-only claims —
    // a future change to UUID-with-dashes or anything else would otherwise
    // silently traverse outside the intended namespace.
    final safeSub = Uri.encodeComponent(sub);
    final actionSuffix = action != null ? ':/$action' : '';
    return '$_approot:/users/$safeSub/$relative$actionSuffix';
  }

  // ---- Manifest ----

  /// Returns the remote manifest for the current user, or `null` if none
  /// exists yet (fresh per-user folder OR not-yet-migrated install).
  Future<SyncManifest?> getManifest() async {
    final path = await _userPath('manifest.json', action: 'content');
    final resp = await _dio.get<Map<String, dynamic>>(path);
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return _decodeManifest(resp.data!);
  }

  Future<void> putManifest(SyncManifest manifest) async {
    final path = await _userPath('manifest.json', action: 'content');
    final resp = await _dio.put(
      path,
      data: _encodeManifest(manifest),
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }

  // ---- Notes ----

  Future<Map<String, dynamic>?> getNoteBlob(String id) async {
    final path = await _userPath('notes/$id.json', action: 'content');
    final resp = await _dio.get<Map<String, dynamic>>(path);
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data;
  }

  Future<void> putNoteBlob(String id, Map<String, dynamic> body) async {
    final path = await _userPath('notes/$id.json', action: 'content');
    final resp = await _dio.put(
      path,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }

  Future<void> deleteNoteBlob(String id) async {
    final path = await _userPath('notes/$id.json');
    final resp = await _dio.delete<void>(path);
    if (resp.statusCode == 404) return; // Already gone — GC tolerates it.
    _throwIfBad(resp);
  }

  // ---- Settings ----

  /// Fetch the user's settings JSON blob from `users/{sub}/settings.json`,
  /// or null when the file doesn't exist yet (first sync).
  Future<Map<String, dynamic>?> getSettings() async {
    final path = await _userPath('settings.json', action: 'content');
    final resp = await _dio.get<Map<String, dynamic>>(path);
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data;
  }

  /// Push the user's settings JSON blob to `users/{sub}/settings.json`.
  /// Single-file LWW — callers (orchestrator) compare timestamps before
  /// deciding to write.
  Future<void> putSettings(Map<String, dynamic> body) async {
    final path = await _userPath('settings.json', action: 'content');
    final resp = await _dio.put(
      path,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }

  /// Fetch the user's tag-definitions blob from `users/{sub}/tags.json`,
  /// or null when the file doesn't exist yet.
  Future<Map<String, dynamic>?> getTags() async {
    final path = await _userPath('tags.json', action: 'content');
    final resp = await _dio.get<Map<String, dynamic>>(path);
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data;
  }

  /// Push the user's tag-definitions blob to `users/{sub}/tags.json`.
  Future<void> putTags(Map<String, dynamic> body) async {
    final path = await _userPath('tags.json', action: 'content');
    final resp = await _dio.put(
      path,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }

  // Attachment-byte uploads / downloads were removed in Phase 11.5.
  // cloudStorage replicates bytes via the OS-level OneDrive client
  // (the vault root lives inside the user's OneDrive folder); we no
  // longer need Graph API endpoints for individual attachment files.

  // ---- Legacy (pre per-user) data access for one-time migration ----
  //
  // These read the OLD unscoped paths so the orchestrator can copy them
  // into the current user's subtree on first post-upgrade sync. After
  // the migration marker is written they're never called again. None of
  // these write back to the legacy paths — legacy data is left in place
  // as a rollback safety net.

  /// Manifest from the legacy unscoped path (`approot/manifest.json`).
  Future<SyncManifest?> getLegacyManifest() async {
    final resp = await _dio
        .get<Map<String, dynamic>>('$_approot:/manifest.json:/content');
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return _decodeManifest(resp.data!);
  }

  /// Note body from the legacy unscoped path (`approot/notes/{id}.json`).
  Future<Map<String, dynamic>?> getLegacyNoteBlob(String id) async {
    final resp = await _dio
        .get<Map<String, dynamic>>('$_approot:/notes/$id.json:/content');
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data;
  }

  // ---- Legacy-migration marker ----
  //
  // A single JSON file at `approot/users/.legacy_migrated.json` marks
  // that migration has been attempted globally for this Microsoft
  // account. Single marker (not per-user) because only one user can
  // "own" the pre-upgrade single-user data — once migration runs, every
  // other Hmm user signing in on the same Microsoft account starts with
  // a clean per-user subtree.

  Future<bool> hasLegacyMigrationMarker() async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$_approot:/users/.legacy_migrated.json:/content',
    );
    if (resp.statusCode == 404) return false;
    _throwIfBad(resp);
    return true;
  }

  /// Writes the marker with audit info (when, for which sub, how many
  /// note files were copied). Body is intentionally tiny — this is a
  /// flag, not a journal.
  Future<void> writeLegacyMigrationMarker({
    required String forSub,
    required int copiedNoteCount,
  }) async {
    final resp = await _dio.put(
      '$_approot:/users/.legacy_migrated.json:/content',
      data: {
        'migrated_at': DateTime.now().toUtc().toIso8601String(),
        'for_sub': forSub,
        'copied_note_count': copiedNoteCount,
        '_v': 1,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }

  // ---- Helpers ----

  void _throwIfBad(Response resp) {
    final code = resp.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    throw OneDriveGraphException(
      statusCode: code,
      message: resp.statusMessage ?? 'Graph request failed',
      responseBody: resp.data?.toString(),
    );
  }

  SyncManifest _decodeManifest(Map<String, dynamic> json) {
    return SyncManifest(
      version: json['version'] as int? ?? 1,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      deviceId: json['device_id'] as String? ?? 'unknown',
      notes: ((json['notes'] as List?) ?? const [])
          .map((e) => _decodeEntry(e as Map<String, dynamic>))
          .toList(),
      attachments: ((json['attachments'] as List?) ?? const [])
          .map((e) => _decodeEntry(e as Map<String, dynamic>))
          .toList(),
    );
  }

  ManifestEntry _decodeEntry(Map<String, dynamic> json) {
    return ManifestEntry(
      id: json['id'].toString(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      deleted: json['deleted'] as bool? ?? false,
      noteId: json['note_id']?.toString(),
      filename: json['filename'] as String?,
    );
  }

  Map<String, dynamic> _encodeManifest(SyncManifest m) {
    return {
      'version': m.version,
      'generated_at': m.generatedAt.toUtc().toIso8601String(),
      'device_id': m.deviceId,
      'notes': m.notes.map(_encodeEntry).toList(),
      'attachments': m.attachments.map(_encodeEntry).toList(),
    };
  }

  Map<String, dynamic> _encodeEntry(ManifestEntry e) {
    return {
      'id': e.id,
      'updated_at': e.updatedAt.toUtc().toIso8601String(),
      'deleted': e.deleted,
      if (e.noteId != null) 'note_id': e.noteId,
      if (e.filename != null) 'filename': e.filename,
    };
  }
}

final oneDriveGraphClientProvider = Provider<OneDriveGraphClient>((ref) {
  final tokenService = ref.watch(idpTokenServiceProvider);
  return OneDriveGraphClient(
    ref.watch(oneDriveAuthProvider),
    () async => (await tokenService.getStoredClaims())?['sub'] as String?,
  );
});
