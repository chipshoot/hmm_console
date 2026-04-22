import 'sync_models.dart';

/// Provider-agnostic sync contract. See `docs/sync_contract.md` §9.
///
/// An implementation is responsible for moving [NoteBlob]s and
/// [AttachmentBlob]s between the local store and one specific remote
/// (OneDrive, the Hmm API, iCloud, …). The orchestrator gathers locally
/// changed records, hands them to [sync], and applies the returned pulled
/// records back to the local DB.
abstract class CloudSyncProvider {
  /// Stable identifier used for the sync-cursor key in SharedPreferences
  /// (e.g. `'onedrive'`, `'hmm_api'`).
  String get providerId;

  /// True once credentials are cached and usable.
  Future<bool> isAuthenticated();

  /// Starts the platform-appropriate auth flow. Throws on failure.
  Future<void> signIn();

  /// Drops cached credentials. Does not purge local data.
  Future<void> signOut();

  /// Push local changes and pull remote ones. Never throws — transport or
  /// auth errors surface in [SyncResult.errors].
  Future<SyncResult> sync(SyncRequest request);
}
