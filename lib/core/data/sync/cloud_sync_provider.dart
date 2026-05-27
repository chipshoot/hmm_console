import 'sync_models.dart';

/// Provider-agnostic transport contract. See `docs/sync_contract.md` §9.
///
/// Implementations expose low-level I/O primitives against one remote
/// (OneDrive, the Hmm API, iCloud, …). The [SyncOrchestrator] drives the
/// full sync algorithm (pull manifest → pull newer records → push local
/// changes → rewrite manifest).
///
/// Each primitive may throw on transport/auth failure; the orchestrator
/// catches and converts to [SyncError] entries in the final [SyncResult].
abstract class CloudSyncProvider {
  /// Stable identifier used for the sync-cursor key in SharedPreferences
  /// (e.g. `'onedrive'`, `'hmm_api'`).
  String get providerId;

  /// True once credentials are cached and usable.
  Future<bool> isAuthenticated();

  /// Starts the platform-appropriate auth flow.
  Future<void> signIn();

  /// Drops cached credentials. Does not purge local data.
  Future<void> signOut();

  // ---- Manifest ----

  /// Fetch the current remote manifest; returns null if the cloud namespace
  /// is empty (first-ever sync).
  Future<SyncManifest?> pullManifest();

  /// Push a fresh manifest. Full overwrite — no partial updates.
  Future<void> pushManifest(SyncManifest manifest);

  // ---- Notes ----

  /// Fetch the JSON body of one note, or null if the blob is missing.
  Future<Map<String, dynamic>?> pullNoteBody(String id);

  /// Upload the JSON body of one note (creates or overwrites).
  Future<void> pushNoteBody(String id, Map<String, dynamic> body);

  // ---- Settings ----
  //
  // The user's preference bundle (units, locale, network policy)
  // travels as a single JSON blob sibling to the manifest, so it
  // syncs alongside notes via the same `syncNow()` pass. See Phase
  // D.2 in `task_plan.md`.
  //
  // Default impls return null / no-op so providers that don't speak
  // settings (e.g., the cloudApi `ApiSyncProvider` for now) can stay
  // untouched. The OneDrive impl actually writes to
  // `users/{sub}/settings.json`.

  /// Fetch the raw settings blob (the SyncableSettings JSON map), or
  /// null when the cloud hasn't been seeded with settings yet.
  Future<Map<String, dynamic>?> pullSettings() async => null;

  /// Push the settings blob. No-op default so non-OneDrive providers
  /// remain transparent until they're ready to implement this.
  Future<void> pushSettings(Map<String, dynamic> body) async {}

  // Attachment byte transfer was removed in Phase 11.5 (2026-05-17).
  // Attachment refs now travel inside the note body (via the
  // `Notes.attachments` JSON column); attachment bytes travel
  // out-of-band — cloudStorage relies on the OS-level OneDrive /
  // iCloud Drive sync client, cloudApi will route through the
  // future `ApiVaultStore` (Phase 15) when it lands.
}
