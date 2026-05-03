import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_sync_provider.dart';
import 'sync_models.dart';

/// Stub implementation — real REST wiring lands next.
///
/// Target endpoints (see `docs/SYSTEM_DESIGN.md`):
///   GET/POST/PUT/DELETE /api/v1/notes
///   GET                 /api/v1/notecatalogs
///   GET                 /api/v1/tags
///   GET/POST            /api/v1/authors
///
/// Auth piggybacks on the existing `IdpTokenService` (Firebase JWT → Hmm JWT).
class ApiSyncProvider implements CloudSyncProvider {
  const ApiSyncProvider();

  static UnsupportedError _notImplemented(String op) => UnsupportedError(
        'ApiSyncProvider.$op not yet implemented — wire to the Hmm REST API.',
      );

  @override
  String get providerId => 'hmm_api';

  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<void> signIn() async => throw _notImplemented('signIn');

  @override
  Future<void> signOut() async => throw _notImplemented('signOut');

  @override
  Future<SyncManifest?> pullManifest() async =>
      throw _notImplemented('pullManifest');

  @override
  Future<void> pushManifest(SyncManifest manifest) async =>
      throw _notImplemented('pushManifest');

  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) async =>
      throw _notImplemented('pullNoteBody');

  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) async =>
      throw _notImplemented('pushNoteBody');

  @override
  Future<List<int>?> pullAttachmentBytes({
    required String id,
    required String filename,
  }) async =>
      throw _notImplemented('pullAttachmentBytes');

  @override
  Future<void> pushAttachmentBytes({
    required String id,
    required String filename,
    required String mimeType,
    required List<int> bytes,
  }) async =>
      throw _notImplemented('pushAttachmentBytes');
}

final apiSyncProviderProvider =
    Provider<CloudSyncProvider>((ref) => const ApiSyncProvider());
