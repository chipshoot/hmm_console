// Riverpod providers for the attachment plumbing: vault store,
// resolver, picker. Mode-aware where appropriate.
//
// Vault root resolution per tier (Phase 11.5):
//   - `local`           → `<app docs>/vault/`
//   - `cloudStorage`    → user-configured `vaultPath` from settings
//                         (typically inside their OneDrive folder so
//                         the OS-level sync client moves the bytes).
//                         Falls back to `<app docs>/vault/` if the
//                         user hasn't set one yet. iOS always falls
//                         back — iOS doesn't surface a desktop-style
//                         OneDrive folder; iCloud Drive ubiquity
//                         containers are a Phase-19 follow-up.
//   - `cloudApi`        → ApiVaultStore (Phase 15) — bytes go
//                         straight to /v1/notes/{noteId}/vault/{filename}.
//                         No on-disk root, so the directory provider
//                         is skipped entirely.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data_mode.dart';
import '../../settings/settings_controller.dart';
import 'picker/image_attachment_picker.dart';
import 'picker/image_downsizer.dart';
import 'resolver/attachment_resolver.dart';
import '../vault/api_vault_store.dart';
import '../vault/encrypted_vault_store.dart';
import '../vault/local_vault_store.dart';
import '../vault/vault_key_cache.dart';
import '../vault/vault_key_service.dart';
import '../vault/vault_store.dart';

/// The user's chosen cloudStorage vault folder from the unified settings,
/// or null if unset/empty. The store appends `vault/` to whatever the user
/// picks. Persistence lives in SettingsController
/// (`cloudStorageVaultPath`); writes go through
/// `settingsProvider.notifier.setCloudStorageVaultPath(path)` — pass `''` to
/// clear.
Future<String?> _readConfiguredVaultPath(Ref ref) async {
  final v = (await ref.watch(settingsProvider.future)).cloudStorageVaultPath;
  if (v == null || v.isEmpty) return null;
  return v;
}

/// Reactive view of the configured vault folder path (null if unset).
/// Used by Settings UI to display + edit the current value.
final cloudStorageVaultPathProvider =
    FutureProvider<String?>((ref) => _readConfiguredVaultPath(ref));

/// Resolves the on-disk vault root for the current tier.
final vaultRootDirectoryProvider = FutureProvider<Directory>((ref) async {
  final mode = ref.watch(dataModeProvider);
  switch (mode) {
    case DataMode.local:
      return _appDocsVault();
    case DataMode.cloudStorage:
      // iOS has no desktop-style OneDrive folder; fall back to the
      // app sandbox. The OS-level OneDrive client isn't a thing on
      // iOS; iCloud Drive ubiquity-container integration is a later
      // phase. Note JSON still syncs via the API path.
      if (Platform.isIOS) return _appDocsVault();

      final configured = await _readConfiguredVaultPath(ref);
      if (configured == null) {
        // Not yet configured — fall back to app docs so the app
        // remains usable. The Settings UI prompts the user to point
        // this at their OneDrive folder so multi-device sync works.
        return _appDocsVault();
      }
      final root = Directory(p.join(configured, 'vault'));
      if (!await root.exists()) {
        await root.create(recursive: true);
      }
      return root;
    case DataMode.cloudApi:
      // No on-disk vault in cloudApi mode — bytes live server-side.
      // The vault root provider should never be read in this tier;
      // callers go through vaultStoreProvider (which short-circuits
      // to ApiVaultStore before touching this provider).
      throw StateError(
        'vaultRootDirectoryProvider must not be read in cloudApi mode; '
        'use vaultStoreProvider, which returns an ApiVaultStore.',
      );
  }
});

Future<Directory> _appDocsVault() async {
  final appDir = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(appDir.path, 'vault'));
  if (!await root.exists()) {
    await root.create(recursive: true);
  }
  return root;
}

/// Mode-aware **unencrypted** [IVaultStore]. Local + cloudStorage share
/// the filesystem-backed [LocalVaultStore] (only the root differs);
/// cloudApi swaps in [ApiVaultStore] which talks straight to
/// `/v1/notes/{noteId}/vault/...` and never touches local disk. This is
/// the base the encrypting decorator and the key service both build on.
final baseVaultStoreProvider = FutureProvider<IVaultStore>((ref) async {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.cloudApi) {
    // Direct passthrough — no async setup needed, no directory
    // provider to await. Reuses the shared apiClientProvider so the
    // existing auth + logging interceptors fire on every request.
    return ref.watch(apiVaultStoreProvider);
  }
  final root = await ref.watch(vaultRootDirectoryProvider.future);
  return LocalVaultStore(rootDir: root);
});

/// Platform secure-storage cache for the derived vault key, so a future
/// biometric unlock (Phase 4b/B3) can restore it without re-deriving from
/// the passphrase.
final vaultKeyCacheProvider =
    Provider<VaultKeyCache>((ref) => SecureStorageVaultKeyCache());

/// Session key holder for sensitive attachments. Reads/writes the
/// non-secret vault_meta.json through the base (unencrypted) store.
final vaultKeyServiceProvider = FutureProvider<VaultKeyService>((ref) async {
  final base = await ref.watch(baseVaultStoreProvider.future);
  return VaultKeyService(store: base, cache: ref.watch(vaultKeyCacheProvider));
});

/// Mode-aware [IVaultStore] used by all callers. For local + cloudStorage
/// it wraps the base store in an [EncryptedVaultStore] so sensitive paths
/// are encrypted at rest; cloudApi returns the base store unchanged
/// (encryption there lands in Phase 5).
final vaultStoreProvider = FutureProvider<IVaultStore>((ref) async {
  final base = await ref.watch(baseVaultStoreProvider.future);
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.cloudApi) {
    return base;
  }
  final keyService = await ref.watch(vaultKeyServiceProvider.future);
  return EncryptedVaultStore(inner: base, keyService: keyService);
});

/// Composite resolver. For v1 only the vault arm is wired; PhAsset
/// and CloudFile resolvers plug in here in Phases 16/17 without
/// callers changing anything.
final attachmentResolverProvider =
    FutureProvider<IAttachmentResolver>((ref) async {
  final store = await ref.watch(vaultStoreProvider.future);
  return CompositeAttachmentResolver(
    vault: VaultResolver(vaultStore: store),
  );
});

/// Image picker backed by `image_picker` + the current vault store.
final imageAttachmentPickerProvider =
    FutureProvider<IImageAttachmentPicker>((ref) async {
  final store = await ref.watch(vaultStoreProvider.future);
  // Production downsizes on copy via native codecs (handles HEIC,
  // re-encodes to JPEG). Tests/headless construction default to the
  // no-op downsizer.
  return VaultImageAttachmentPicker(
    vaultStore: store,
    downsizer: const NativeImageDownsizer(),
  );
});
