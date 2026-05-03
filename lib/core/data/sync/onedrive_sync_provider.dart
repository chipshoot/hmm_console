import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_sync_provider.dart';
import 'onedrive_auth.dart';
import 'onedrive_graph_client.dart';
import 'sync_models.dart';

/// OneDrive implementation of [CloudSyncProvider]. Delegates I/O to
/// [OneDriveGraphClient]; the orchestrator owns the sync algorithm.
class OneDriveSyncProvider implements CloudSyncProvider {
  OneDriveSyncProvider(this._auth, this._graph);

  final OneDriveAuth _auth;
  final OneDriveGraphClient _graph;

  OneDriveAuth get auth => _auth;

  @override
  String get providerId => 'onedrive';

  @override
  Future<bool> isAuthenticated() => _auth.hasToken();

  @override
  Future<void> signIn() => _auth.signIn();

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<SyncManifest?> pullManifest() => _graph.getManifest();

  @override
  Future<void> pushManifest(SyncManifest manifest) =>
      _graph.putManifest(manifest);

  @override
  Future<Map<String, dynamic>?> pullNoteBody(String id) =>
      _graph.getNoteBlob(id);

  @override
  Future<void> pushNoteBody(String id, Map<String, dynamic> body) =>
      _graph.putNoteBlob(id, body);

  @override
  Future<List<int>?> pullAttachmentBytes({
    required String id,
    required String filename,
  }) =>
      _graph.getAttachment(id: id, filename: filename);

  @override
  Future<void> pushAttachmentBytes({
    required String id,
    required String filename,
    required String mimeType,
    required List<int> bytes,
  }) =>
      _graph.putAttachment(
        id: id,
        filename: filename,
        mimeType: mimeType,
        bytes: bytes,
      );
}

final oneDriveSyncProviderProvider = Provider<CloudSyncProvider>((ref) {
  return OneDriveSyncProvider(
    ref.watch(oneDriveAuthProvider),
    ref.watch(oneDriveGraphClientProvider),
  );
});
