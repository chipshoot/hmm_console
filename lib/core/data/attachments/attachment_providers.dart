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
//   - `cloudApi`        → not yet implemented (ApiVaultStore lands
//                         in Phase 15).

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data_mode.dart';
import 'picker/image_attachment_picker.dart';
import 'resolver/attachment_resolver.dart';
import '../vault/local_vault_store.dart';
import '../vault/vault_store.dart';

/// SharedPreferences key for the user's chosen cloudStorage vault
/// folder. Stored as an absolute filesystem path; the store appends
/// `vault/` itself.
const _vaultPathKey = 'cloud_storage_vault_path';

/// Persisted path of the user's cloudStorage vault folder, or null
/// if unset. The store appends `vault/` to whatever the user picks.
Future<String?> _readConfiguredVaultPath() async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getString(_vaultPathKey);
  if (v == null || v.isEmpty) return null;
  return v;
}

/// Persist a user-chosen vault folder path (or clear by passing null).
Future<void> setCloudStorageVaultPath(String? newPath) async {
  final prefs = await SharedPreferences.getInstance();
  if (newPath == null || newPath.isEmpty) {
    await prefs.remove(_vaultPathKey);
  } else {
    await prefs.setString(_vaultPathKey, newPath);
  }
}

/// Reactive view of the persisted vault folder path (null if unset).
/// Used by Settings UI to display + edit the current value.
final cloudStorageVaultPathProvider =
    FutureProvider<String?>((ref) => _readConfiguredVaultPath());

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

      final configured = await _readConfiguredVaultPath();
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
      throw UnimplementedError(
        'cloudApi vault root requires ApiVaultStore (Phase 15).',
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

/// Mode-aware [IVaultStore].
final vaultStoreProvider = FutureProvider<IVaultStore>((ref) async {
  final root = await ref.watch(vaultRootDirectoryProvider.future);
  return LocalVaultStore(rootDir: root);
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
  return VaultImageAttachmentPicker(vaultStore: store);
});
