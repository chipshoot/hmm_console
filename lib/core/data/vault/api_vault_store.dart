// ApiVaultStore — IVaultStore backed by the Hmm REST API.
//
// Routes every byte through the per-note vault endpoints (Phase 5,
// pushed 2026-05-18):
//   POST   /v1/notes/{noteId}/vault/{filename}
//   GET    /v1/notes/{noteId}/vault/{filename}
//   HEAD   /v1/notes/{noteId}/vault/{filename}
//   DELETE /v1/notes/{noteId}/vault/{filename}
//   GET    /v1/notes/{noteId}/vault              ← per-note list
//
// Vault relative paths on the wire are always of the form
// `attachments/note-{N}/{filename}` (three segments, validated by
// `vault_path.dart`). The store parses these into (noteId, filename)
// before issuing the request, matching the route shape on the .NET
// side (`NoteVaultController` joins them with `VaultPathUtil.Join`).

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/api_client.dart';
import 'vault_path.dart';
import 'vault_store.dart';

/// Dio-backed [IVaultStore]. Path translation only — the orchestrator
/// and the resolver call this the same way they call
/// [LocalVaultStore]; the store does the wire-level work.
class ApiVaultStore implements IVaultStore {
  ApiVaultStore({required ApiClient client}) : _dio = client.dio;

  final Dio _dio;

  /// Two layouts on the wire under the `/v1/` base path:
  ///   - per-file: `/notes/{N}/vault/{filename}`
  ///   - per-note list: `/notes/{N}/vault`
  ///
  /// `_dio.baseUrl` already includes `/v1`, so these are relative.
  /// Leading slash matches the rest of the codebase's datasource
  /// convention (see `AutomobileRemoteDataSource` et al.) — also
  /// what `http_mock_adapter`'s path matcher expects in tests.
  String _filePath(int noteId, String filename) =>
      '/notes/$noteId/vault/$filename';

  String _listPath(int noteId) => '/notes/$noteId/vault';

  /// Decompose a vault relative path into the route parts the
  /// per-note endpoint needs. Accepts only the three-segment shape
  /// the rest of the codebase produces: `attachments/note-{N}/{name}`.
  /// Anything else throws [ArgumentError] so the caller can't sneak
  /// a malformed path through and quietly hit a 404.
  static ({int noteId, String filename}) _decompose(String relativePath) {
    vaultRelativePathValidate(relativePath);
    final segs = relativePath.split('/');
    if (segs.length != 3 ||
        segs[0] != 'attachments' ||
        !segs[1].startsWith('note-')) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'expected attachments/note-{id}/{filename}',
      );
    }
    final noteIdRaw = segs[1].substring('note-'.length);
    final noteId = int.tryParse(noteIdRaw);
    if (noteId == null || noteId <= 0) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'invalid noteId in second segment: "$noteIdRaw"',
      );
    }
    return (noteId: noteId, filename: segs[2]);
  }

  @override
  Future<void> putBytes(
    String relativePath,
    Uint8List bytes, {
    String? contentType,
  }) async {
    final parts = _decompose(relativePath);
    // Inferred content-type when the caller omitted it — the server
    // demands a value in the v1 allow-list, so guessing from the
    // extension keeps the picker → store call site simple.
    final ct = contentType ?? _guessContentType(parts.filename);
    try {
      // Send the bytes directly (Dio handles a Uint8List as a
      // single Content-Length request). v1 caps uploads at 8 MB so
      // there's no streaming benefit; if that ever changes we
      // switch the data type here.
      await _dio.post<void>(
        _filePath(parts.noteId, parts.filename),
        data: bytes,
        options: Options(contentType: ct),
      );
    } on DioException catch (e) {
      throw _toStoreException(
        e,
        defaultMessage: 'upload failed',
        relativePath: relativePath,
      );
    }
  }

  @override
  Future<Uint8List> getBytes(String relativePath) async {
    final parts = _decompose(relativePath);
    try {
      final resp = await _dio.get<List<int>>(
        _filePath(parts.noteId, parts.filename),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = resp.data;
      if (data == null) {
        throw VaultStoreException('empty response body', relativePath);
      }
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw VaultStoreException('file not found', relativePath);
      }
      throw _toStoreException(
        e,
        defaultMessage: 'download failed',
        relativePath: relativePath,
      );
    }
  }

  @override
  Future<bool> exists(String relativePath) async {
    final parts = _decompose(relativePath);
    try {
      // HEAD is the cheap shape the server documents for existence
      // checks — no body, just the status line.
      await _dio.head<void>(_filePath(parts.noteId, parts.filename));
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      throw _toStoreException(
        e,
        defaultMessage: 'exists check failed',
        relativePath: relativePath,
      );
    }
  }

  @override
  Future<void> delete(String relativePath) async {
    final parts = _decompose(relativePath);
    try {
      await _dio.delete<void>(_filePath(parts.noteId, parts.filename));
    } on DioException catch (e) {
      // 204 is the normal path; 404 is also "deleted" by the
      // IVaultStore.delete contract (idempotent).
      if (e.response?.statusCode == 404) return;
      throw _toStoreException(
        e,
        defaultMessage: 'delete failed',
        relativePath: relativePath,
      );
    }
  }

  /// Only the per-note shape is supported. The .NET side will gain a
  /// `/v1/migration/manifest` endpoint for cross-note enumeration
  /// (documented but not yet built); until then, callers that want
  /// "everything" have to fan out across the notes themselves.
  @override
  Future<List<VaultEntry>> list(String prefix) async {
    if (prefix.isEmpty) {
      throw UnimplementedError(
        'ApiVaultStore.list("") is not supported — the API is per-note. '
        'Use prefix "attachments/note-{N}" for a single note, or wait '
        'for the future /v1/migration/manifest cross-note endpoint.',
      );
    }
    vaultRelativePathValidate(prefix);
    final segs = prefix.split('/');
    // Accept either "attachments/note-{N}" (folder) or
    // "attachments/note-{N}/file.jpg" (single file — defer to
    // exists+size).
    if (segs.length < 2 ||
        segs[0] != 'attachments' ||
        !segs[1].startsWith('note-')) {
      throw ArgumentError.value(
        prefix,
        'prefix',
        'expected attachments/note-{id} or attachments/note-{id}/{file}',
      );
    }
    final noteIdRaw = segs[1].substring('note-'.length);
    final noteId = int.tryParse(noteIdRaw);
    if (noteId == null || noteId <= 0) {
      throw ArgumentError.value(
        prefix,
        'prefix',
        'invalid noteId in second segment: "$noteIdRaw"',
      );
    }

    // Single-file prefix → fall back to HEAD so callers that pass a
    // full path get the same shape LocalVaultStore.list returns
    // (one entry or empty).
    if (segs.length == 3) {
      try {
        final resp = await _dio.head<void>(_filePath(noteId, segs[2]));
        final cl = resp.headers.value(Headers.contentLengthHeader);
        return [
          VaultEntry(
            relativePath: prefix,
            byteSize: cl == null ? 0 : int.tryParse(cl) ?? 0,
          ),
        ];
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) return const [];
        throw _toStoreException(
          e,
          defaultMessage: 'list failed',
          relativePath: prefix,
        );
      }
    }

    // Per-note folder list.
    try {
      final resp = await _dio.get<List<dynamic>>(_listPath(noteId));
      final entries = resp.data ?? const [];
      final out = <VaultEntry>[];
      for (final raw in entries) {
        if (raw is! Map) continue;
        final relPath = raw['relativePath'] as String?;
        final byteSize = raw['byteSize'];
        if (relPath == null) continue;
        out.add(VaultEntry(
          relativePath: relPath,
          byteSize: byteSize is int
              ? byteSize
              : (byteSize is num ? byteSize.toInt() : 0),
        ));
      }
      // Stable ordering so callers can rely on it (matches
      // LocalVaultStore.list).
      out.sort((a, b) => a.relativePath.compareTo(b.relativePath));
      return out;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      throw _toStoreException(
        e,
        defaultMessage: 'list failed',
        relativePath: prefix,
      );
    }
  }

  static VaultStoreException _toStoreException(
    DioException e, {
    required String defaultMessage,
    required String relativePath,
  }) {
    final status = e.response?.statusCode;
    final tail = status != null ? ' (HTTP $status)' : '';
    return VaultStoreException('$defaultMessage$tail: ${e.message}',
        relativePath);
  }

  static String _guessContentType(String filename) {
    final dot = filename.lastIndexOf('.');
    final ext = dot >= 0 ? filename.substring(dot + 1).toLowerCase() : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' || 'heif' => 'image/heic',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }
}

/// Riverpod provider for [ApiVaultStore]. Reuses the shared
/// [apiClientProvider] so the same auth + logging interceptors fire
/// on every vault request.
final apiVaultStoreProvider = Provider<IVaultStore>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiVaultStore(client: client);
});
