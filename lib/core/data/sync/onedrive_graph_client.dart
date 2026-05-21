import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Thin Microsoft Graph REST client scoped to the app folder
/// (`/drive/special/approot`). Pairs with [OneDriveAuth]; a request-time
/// interceptor attaches a fresh bearer token.
///
/// Endpoint shape reference:
/// - `PUT /me/drive/special/approot:/notes/{id}.json:/content`
/// - `GET /me/drive/special/approot:/manifest.json:/content`
class OneDriveGraphClient {
  OneDriveGraphClient(this._auth, {Dio? dio})
      : _dio = dio ??
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
  final Dio _dio;

  static const _approot = '/me/drive/special/approot';

  // ---- Manifest ----

  /// Returns the remote manifest, or `null` if none exists yet (fresh app
  /// folder).
  Future<SyncManifest?> getManifest() async {
    final resp = await _dio.get<Map<String, dynamic>>('$_approot:/manifest.json:/content');
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return _decodeManifest(resp.data!);
  }

  Future<void> putManifest(SyncManifest manifest) async {
    final resp = await _dio.put(
      '$_approot:/manifest.json:/content',
      data: _encodeManifest(manifest),
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }

  // ---- Notes ----

  Future<Map<String, dynamic>?> getNoteBlob(String id) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$_approot:/notes/$id.json:/content',
    );
    if (resp.statusCode == 404) return null;
    _throwIfBad(resp);
    return resp.data;
  }

  Future<void> putNoteBlob(String id, Map<String, dynamic> body) async {
    final resp = await _dio.put(
      '$_approot:/notes/$id.json:/content',
      data: body,
      options: Options(contentType: Headers.jsonContentType),
    );
    _throwIfBad(resp);
  }

  Future<void> deleteNoteBlob(String id) async {
    final resp = await _dio.delete<void>('$_approot:/notes/$id.json');
    if (resp.statusCode == 404) return; // Already gone — GC tolerates it.
    _throwIfBad(resp);
  }

  // Attachment-byte uploads / downloads were removed in Phase 11.5.
  // cloudStorage replicates bytes via the OS-level OneDrive client
  // (the vault root lives inside the user's OneDrive folder); we no
  // longer need Graph API endpoints for individual attachment files.

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
  return OneDriveGraphClient(ref.watch(oneDriveAuthProvider));
});
