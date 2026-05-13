// Riverpod providers for the attachment plumbing: vault store,
// resolver, picker. Mode-aware where appropriate.
//
// v1 ties both `local` and `cloudStorage` tiers to a LocalVaultStore
// rooted under the app's documents directory. The cloudStorage tier
// gets multi-device sync "for free" via the OS-level OneDrive /
// iCloud Drive client — but pointing the vault root at the user's
// cloud-synced folder is a follow-up (root detection per the design
// doc). For now both modes hit the same on-device vault and we lean
// on the existing SyncOrchestrator to relay bytes.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data_mode.dart';
import 'picker/image_attachment_picker.dart';
import 'resolver/attachment_resolver.dart';
import '../vault/local_vault_store.dart';
import '../vault/vault_store.dart';

/// Resolves the on-disk vault root for the current tier.
///
/// `local` / `cloudStorage`: `<app docs>/vault/`.
/// `cloudApi`: not yet implemented — the ApiVaultStore lands in a
/// later phase; throwing here keeps a forgotten mode from silently
/// writing to the wrong place.
final vaultRootDirectoryProvider = FutureProvider<Directory>((ref) async {
  final mode = ref.watch(dataModeProvider);
  switch (mode) {
    case DataMode.local:
    case DataMode.cloudStorage:
      final appDir = await getApplicationDocumentsDirectory();
      final root = Directory(p.join(appDir.path, 'vault'));
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
