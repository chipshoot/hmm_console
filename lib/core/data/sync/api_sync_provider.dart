import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_sync_provider.dart';
import 'sync_models.dart';

/// Skeleton implementation — real REST wiring lands next.
///
/// Target endpoints (see `docs/SYSTEM_DESIGN.md`):
///   GET/POST/PUT/DELETE /api/v1/notes
///   GET               /api/v1/notecatalogs
///   GET               /api/v1/tags
///   GET/POST          /api/v1/authors
///
/// Auth is handled by the existing `IdpTokenService` (Firebase JWT → Hmm JWT).
class ApiSyncProvider implements CloudSyncProvider {
  const ApiSyncProvider();

  @override
  String get providerId => 'hmm_api';

  @override
  Future<bool> isAuthenticated() async {
    // TODO: delegate to IdpTokenService once sync is wired.
    return false;
  }

  @override
  Future<void> signIn() async {
    throw UnimplementedError(
      'ApiSyncProvider.signIn — the Hmm backend reuses Firebase/IDP auth. '
      'Wire this to IdpTokenService when the real sync lands.',
    );
  }

  @override
  Future<void> signOut() async {
    throw UnimplementedError('ApiSyncProvider.signOut not yet wired.');
  }

  @override
  Future<SyncResult> sync(SyncRequest request) async {
    final now = DateTime.now().toUtc();
    return SyncResult.failed(
      at: now,
      error: const SyncError(
        recordType: 'transport',
        recordId: 'hmm_api',
        message: 'ApiSyncProvider.sync not yet implemented. '
            'See docs/sync_contract.md §4–§5.',
      ),
    );
  }
}

final apiSyncProviderProvider =
    Provider<CloudSyncProvider>((ref) => const ApiSyncProvider());
