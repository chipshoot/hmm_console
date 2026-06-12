import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/idp_token_service.dart';
import 'cloud_sync_provider.dart';
import 'onedrive_auth.dart';
import 'onedrive_graph_client.dart';
import 'sync_models.dart';

/// OneDrive implementation of [CloudSyncProvider]. Delegates I/O to
/// [OneDriveGraphClient]; the orchestrator owns the sync algorithm.
class OneDriveSyncProvider implements CloudSyncProvider {
  OneDriveSyncProvider(this._auth, this._graph, this._tokenService);

  final OneDriveAuth _auth;
  final OneDriveGraphClient _graph;
  final IdpTokenService _tokenService;

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
  Future<Map<String, dynamic>?> pullSettings() => _graph.getSettings();

  @override
  Future<void> pushSettings(Map<String, dynamic> body) =>
      _graph.putSettings(body);

  @override
  Future<Map<String, dynamic>?> pullTags() => _graph.getTags();

  @override
  Future<void> pushTags(Map<String, dynamic> doc) => _graph.putTags(doc);

  /// One-time copy of pre-per-user-isolation data into the current user's
  /// subtree. Idempotent: a marker file at `approot/users/.legacy_migrated.json`
  /// is checked first; once present, this method returns immediately.
  ///
  /// Why this exists: before this release, every Hmm user signed in to the
  /// same Microsoft account wrote notes to a single shared
  /// `approot/notes/{id}.json` path. After the per-user-namespacing change
  /// the read path is `approot/users/{sub}/notes/{id}.json` — so on a clean
  /// upgrade, existing notes would simply "disappear" (the new path is
  /// empty until someone pushes). This method copies them into the current
  /// user's subtree so the first user to sync post-upgrade keeps their
  /// data.
  ///
  /// Trade-off: only the first signing-in user gets the legacy data
  /// claimed for them. That's by design — there's no way for the client
  /// to know which Hmm user "owned" the pre-upgrade data. The marker
  /// records WHICH sub claimed it for future debugging.
  ///
  /// Returns the number of note files copied (0 when nothing to migrate or
  /// migration was already done).
  Future<int> migrateLegacyIfNeeded() async {
    if (await _graph.hasLegacyMigrationMarker()) return 0;

    final sub = (await _tokenService.getStoredClaims())?['sub'] as String?;
    if (sub == null || sub.isEmpty) {
      // No signed-in user → can't pick a target subtree. Don't write the
      // marker either (a later, signed-in attempt should still get to
      // migrate).
      return 0;
    }

    final legacyManifest = await _graph.getLegacyManifest();
    if (legacyManifest == null) {
      // No legacy data at all — still write the marker so subsequent
      // syncs don't repeat this null-result probe.
      await _graph.writeLegacyMigrationMarker(
        forSub: sub,
        copiedNoteCount: 0,
      );
      return 0;
    }

    // Copy each note body to the user-scoped path. We iterate via the
    // manifest's note list so deleted entries (which have no body file)
    // are skipped without an extra round-trip per note.
    var copied = 0;
    for (final entry in legacyManifest.notes) {
      if (entry.deleted) continue;
      final body = await _graph.getLegacyNoteBlob(entry.id);
      if (body == null) continue; // Manifest+body drift — skip silently.
      await _graph.putNoteBlob(entry.id, body);
      copied++;
    }

    // Only copy the manifest itself if the per-user subtree doesn't
    // already have one — overwriting would clobber any cross-device sync
    // state the user already established on another device.
    final existingUserManifest = await _graph.getManifest();
    if (existingUserManifest == null) {
      await _graph.putManifest(legacyManifest);
    }

    await _graph.writeLegacyMigrationMarker(
      forSub: sub,
      copiedNoteCount: copied,
    );
    return copied;
  }

  // Attachment byte transfer was retired from the CloudSyncProvider
  // contract in Phase 11.5. For cloudStorage tier the vault root sits
  // inside the user's OneDrive folder; the OS-level OneDrive client
  // moves the bytes. OneDriveGraphClient's getAttachment /
  // putAttachment / deleteAttachment helpers were removed in the same
  // change.
}

final oneDriveSyncProviderProvider = Provider<CloudSyncProvider>((ref) {
  return OneDriveSyncProvider(
    ref.watch(oneDriveAuthProvider),
    ref.watch(oneDriveGraphClientProvider),
    ref.watch(idpTokenServiceProvider),
  );
});
