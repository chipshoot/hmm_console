import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_sync_provider.dart';
import 'onedrive_auth.dart';
import 'sync_models.dart';

/// Skeleton implementation — real Microsoft Graph wiring lands next.
///
/// Planned layout (see `docs/sync_contract.md` §3):
///   `/notes/{id}.json`
///   `/attachments/{id}.{ext}`
///   `/manifest.json`
/// all under the app folder (`/drive/special/approot`).
class OneDriveSyncProvider implements CloudSyncProvider {
  OneDriveSyncProvider(this._auth);

  final OneDriveAuth _auth;

  @override
  String get providerId => 'onedrive';

  @override
  Future<bool> isAuthenticated() => _auth.hasToken();

  @override
  Future<void> signIn() => _auth.signIn();

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<SyncResult> sync(SyncRequest request) async {
    final now = DateTime.now().toUtc();
    return SyncResult.failed(
      at: now,
      error: const SyncError(
        recordType: 'transport',
        recordId: 'onedrive',
        message: 'OneDriveSyncProvider.sync not yet implemented. '
            'See docs/sync_contract.md §4–§5 and docs/cloud_storage_setup.md §1.',
      ),
    );
  }
}

final oneDriveSyncProviderProvider = Provider<CloudSyncProvider>((ref) {
  return OneDriveSyncProvider(ref.watch(oneDriveAuthProvider));
});
