import 'dart:io' show HandshakeException, HttpException, SocketException;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/idp_token_service.dart';
import 'cloud_sync_provider.dart' show LargeUploadSessionGone;
import 'onedrive_auth.dart';
import 'sync_models.dart';

class OneDriveGraphException implements Exception {
  const OneDriveGraphException({
    required this.statusCode,
    required this.message,
    this.responseBody,
    this.request,
  });

  final int statusCode;
  final String message;
  final String? responseBody;

  /// `METHOD url` of the Graph call that failed, or null when the failure
  /// happened before any request went out (e.g. not signed in). Graph's own
  /// body can be as vague as `invalidRequest: Invalid request`, which names
  /// neither the reason nor the request — this says what was sent.
  final String? request;

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() =>
      'OneDriveGraphException($statusCode): $message'
      '${request == null ? '' : '\n$request'}'
      '${responseBody == null ? '' : '\n$responseBody'}';
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
    Dio? uploadDio,
    Duration transportRetryDelay = const Duration(milliseconds: 400),
  }) : _uploadDio = uploadDio ?? Dio(BaseOptions(validateStatus: (_) => true)),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: 'https://graph.microsoft.com/v1.0',
               responseType: ResponseType.json,
               // Let us branch on status ourselves.
               validateStatus: (_) => true,
             ),
           ) {
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
    _dio.interceptors.add(
      _TransportRetryInterceptor(_dio, transportRetryDelay),
    );
  }

  final OneDriveAuth _auth;
  final CurrentUserSubResolver _currentUserSub;
  final Dio _dio;

  /// For pre-authenticated upload-session URLs: no auth interceptor, because
  /// sending a Bearer token to `uploadUrl` is wrong.
  final Dio _uploadDio;

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

  /// Fetch the user's note-state document from `users/{sub}/note-states.json`
  /// (pins + flags), or null when the file doesn't exist yet.
  Future<Map<String, dynamic>?> getNoteStates() async {
    final path = await _userPath('note-states.json', action: 'content');
    final resp = await _dio.get<Map<String, dynamic>>(path);
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data;
  }

  /// Push the user's note-state document to `users/{sub}/note-states.json`.
  Future<void> putNoteStates(Map<String, dynamic> body) async {
    final path = await _userPath('note-states.json', action: 'content');
    final resp = await _dio.put(
      path,
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }

  // ---- Attachments (vault bytes) ----
  //
  // Re-introduced for cloudStorage byte sync: the orchestrator's
  // _reconcileVault pushes/pulls individual vault files here so media
  // replicates across devices via Graph (works on iOS, unlike the
  // OS-folder-sync assumption Phase 11.5 made). Paths are immutable
  // (UUID in the name), so a PUT is always an idempotent overwrite.

  Future<void> putAttachment(String relativePath, Uint8List bytes) async {
    final path = await _userPath('vault/$relativePath', action: 'content');
    // Stream the bytes as a raw octet-stream body. This is the canonical Dio
    // way to upload binary: passing a Uint8List as `data` would be
    // JSON-encoded by the default transformer (corrupting the bytes), so we
    // send a single-chunk stream with an explicit content length. (Not
    // unit-testable via http_mock_adapter, which can't route a streamed
    // request body — byte fidelity is covered by the two-device round-trip.)
    final resp = await _dio.put(
      path,
      data: Stream.fromIterable([bytes]),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {Headers.contentLengthHeader: bytes.length},
      ),
    );
    _throwIfBad(resp);
  }

  /// Whether the remote vault holds [relativePath] (metadata GET only).
  Future<bool> attachmentExists(String relativePath) async {
    final path = await _userPath('vault/$relativePath');
    final resp = await _dio.get(path);
    if (resp.statusCode == 404) return false;
    _throwIfBad(resp);
    return true;
  }

  /// Streams the vault file at [relativePath] to [savePath]; never holds the
  /// whole file in memory.
  Future<void> downloadAttachmentTo(
    String relativePath,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final path = await _userPath('vault/$relativePath', action: 'content');
    final resp = await _dio.download(
      path,
      savePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
    _throwIfBad(resp);
  }

  // ---- Upload sessions (large files) ----

  /// Opens a resumable upload session for [relativePath]; returns the
  /// pre-authenticated `uploadUrl`.
  Future<String> createUploadSession(String relativePath) async {
    final path = await _userPath(
      'vault/$relativePath',
      action: 'createUploadSession',
    );
    final resp = await _dio.post(
      path,
      data: {
        'item': {'@microsoft.graph.conflictBehavior': 'replace'},
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
    final url = (resp.data as Map?)?['uploadUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw OneDriveGraphException(
        statusCode: resp.statusCode ?? 0,
        message: 'Graph returned no uploadUrl',
        request: _describeRequest(resp),
      );
    }
    return url;
  }

  /// The next byte the session expects, or null if the session is gone.
  Future<int?> uploadSessionNextOffset(String uploadUrl) async {
    final resp = await _uploadDio.get(uploadUrl);
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    final ranges = (resp.data as Map?)?['nextExpectedRanges'] as List?;
    if (ranges == null || ranges.isEmpty) return null;
    return int.parse((ranges.first as String).split('-').first);
  }

  /// Sends one fragment. True when the upload is complete (200/201), false
  /// when more is expected (202). Throws [LargeUploadSessionGone] on 404.
  Future<bool> putUploadFragment(
    String uploadUrl,
    Uint8List chunk,
    int offset,
    int total,
  ) async {
    final resp = await _uploadDio.put(
      uploadUrl,
      data: Stream.fromIterable([chunk]),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {
          Headers.contentLengthHeader: chunk.length,
          'Content-Range': 'bytes $offset-${offset + chunk.length - 1}/$total',
        },
      ),
    );
    if (resp.statusCode == 404) throw const LargeUploadSessionGone();
    _throwIfBad(resp);
    return resp.statusCode != 202;
  }

  /// Cancels the session; one that is already gone is success.
  Future<void> deleteUploadSession(String uploadUrl) async {
    final resp = await _uploadDio.delete(uploadUrl);
    if (resp.statusCode == 404) return;
    _throwIfBad(resp);
  }

  Future<Uint8List?> getAttachment(String relativePath) async {
    final path = await _userPath('vault/$relativePath', action: 'content');
    final resp = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data == null ? null : Uint8List.fromList(resp.data!);
  }

  /// Vault-relative file paths currently present under the remote `vault/`
  /// subtree. Recurses folders; follows @odata.nextLink paging. Returns empty
  /// when the vault folder doesn't exist yet (first sync).
  Future<Set<String>> listAttachments() async {
    final out = <String>{};
    await _listInto(out, 'vault', '');
    return out;
  }

  /// Walks one folder and every folder beneath it.
  ///
  /// Sibling folders are listed CONCURRENTLY. The vault is laid out as
  /// `attachments/note-<id>/...`, one folder per note with an attachment, so
  /// a sequential walk cost one full Graph round-trip per such note, in
  /// series — measured at 2.1s of a 2.8s sync on device, and growing with
  /// every scan added. Siblings have no dependency on each other, so their
  /// requests all go out together; a level of 20 note folders now costs one
  /// round-trip's worth of wall-clock, not twenty.
  ///
  /// Pagination within ONE folder stays sequential: each page's URL comes
  /// from the previous page's `@odata.nextLink`.
  Future<void> _listInto(
    Set<String> out,
    String graphRel,
    String vaultRel,
  ) async {
    var url = await _userPath(graphRel, action: 'children');
    final subfolders = <Future<void>>[];
    while (true) {
      final resp = await _dio.get<Map<String, dynamic>>(url);
      if (resp.statusCode == 404) break; // folder absent → nothing here
      _throwIfBad(resp);
      final value = (resp.data?['value'] as List?) ?? const [];
      for (final raw in value) {
        final item = raw as Map<String, dynamic>;
        final name = item['name'] as String;
        final childVaultRel = vaultRel.isEmpty ? name : '$vaultRel/$name';
        if (item['folder'] != null) {
          // Started now, awaited together below.
          subfolders.add(_listInto(out, '$graphRel/$name', childVaultRel));
        } else {
          out.add(childVaultRel);
        }
      }
      final next = resp.data?['@odata.nextLink'] as String?;
      if (next == null) break;
      url = next; // absolute follow-up URL from Graph
    }
    // eagerError: one bad subfolder fails the whole listing, exactly as the
    // sequential walk did — the orchestrator treats a listing failure as
    // "do not reconcile this run", which is safer than a partial set that
    // would make missing files look deleted.
    await Future.wait(subfolders, eagerError: true);
  }

  Future<void> deleteAttachment(String relativePath) async {
    final path = await _userPath('vault/$relativePath');
    final resp = await _dio.delete<void>(path);
    if (resp.statusCode == 404) return; // already gone
    _throwIfBad(resp);
  }

  // ---- Legacy (pre per-user) data access for one-time migration ----
  //
  // These read the OLD unscoped paths so the orchestrator can copy them
  // into the current user's subtree on first post-upgrade sync. After
  // the migration marker is written they're never called again. None of
  // these write back to the legacy paths — legacy data is left in place
  // as a rollback safety net.

  /// Manifest from the legacy unscoped path (`approot/manifest.json`).
  Future<SyncManifest?> getLegacyManifest() async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$_approot:/manifest.json:/content',
    );
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return _decodeManifest(resp.data!);
  }

  /// Note body from the legacy unscoped path (`approot/notes/{id}.json`).
  Future<Map<String, dynamic>?> getLegacyNoteBlob(String id) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$_approot:/notes/$id.json:/content',
    );
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
    final error = OneDriveGraphException(
      statusCode: code,
      message: resp.statusMessage ?? 'Graph request failed',
      responseBody: resp.data?.toString(),
      request: _describeRequest(resp),
    );
    debugPrint('OneDriveGraphClient: $error');
    throw error;
  }

  /// `METHOD url`, plus where a redirect landed if it did. A `:/content`
  /// GET is answered with a redirect to a download host, so a failure there
  /// may not be Graph's at all. No query is ever kept, on the sent or the
  /// landing URL: either may be a pre-authenticated link (an upload session's
  /// `uploadUrl`), and this text is logged and shown to be copied.
  static String _describeRequest(Response resp) {
    final options = resp.requestOptions;
    final u = options.uri;
    final sent = '${options.method} ${u.origin}${u.path}';
    final landed = resp.realUri;
    if (landed.host == options.uri.host) return sent;
    return '$sent\n(redirected to ${landed.origin}${landed.path})';
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

/// Retries a Graph request once when it failed at the transport level with
/// no HTTP response at all — a connection dropped when the app was
/// interrupted, or resumed on a stale keep-alive socket ("read failed",
/// "Connection closed before full header was received", "Connection
/// terminated during handshake"). One quick retry
/// opens a fresh connection; without it a single drop failed the whole
/// sync step.
///
/// Never retries an HTTP status (4xx/5xx keep their own handling), a
/// cancellation, or a streamed request body (a stream cannot be replayed).
/// Only on the main Graph Dio: upload-session chunks need offset handling.
class _TransportRetryInterceptor extends Interceptor {
  _TransportRetryInterceptor(this._dio, this._delay);

  final Dio _dio;
  final Duration _delay;

  static const _retriedKey = 'hmm.transportRetried';

  static bool _isTransportFailure(DioException e) {
    if (e.response != null) return false;
    return switch (e.type) {
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown =>
        e.error is HttpException ||
            e.error is SocketException ||
            e.error is HandshakeException,
      _ => false,
    };
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isTransportFailure(err) ||
        options.extra[_retriedKey] == true ||
        options.data is Stream ||
        (options.cancelToken?.isCancelled ?? false)) {
      handler.next(err);
      return;
    }
    options.extra[_retriedKey] = true;
    await Future<void>.delayed(_delay);
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
