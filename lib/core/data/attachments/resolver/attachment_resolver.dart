// Resolver — given an AttachmentRef, return display bytes (or null
// if the reference is unresolvable on this device).
//
// v1 only resolves `vault` refs. `phasset` (iOS Photos) and
// `cloudFile` (OneDrive/iCloud Drive paths) get their own resolvers
// in later phases; until then they return null, which the UI
// surfaces as "this photo isn't accessible — Replace?" per the
// design doc's render-time fallback section.

import 'dart:typed_data';

import '../../vault/vault_store.dart';
import '../attachment_ref.dart';

abstract interface class IAttachmentResolver {
  /// Return the bytes that should be rendered for [ref], or null if
  /// this device can't resolve it (wrong OS, photo deleted, file
  /// missing). Never throws on a missing resolution — that's a
  /// "show the placeholder" signal, not an error.
  Future<Uint8List?> resolve(AttachmentRef ref);
}

/// Resolves [VaultRef] via the configured [IVaultStore]. Returns
/// null for missing files or non-vault refs.
class VaultResolver implements IAttachmentResolver {
  const VaultResolver({required this.vaultStore});

  final IVaultStore vaultStore;

  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async {
    if (ref is! VaultRef) return null;
    try {
      return await vaultStore.getBytes(ref.path);
    } on VaultStoreException {
      return null;
    }
  }
}

/// Dispatches to per-kind resolvers. Useful once PhAssetResolver and
/// CloudFileResolver land — pass an instance per kind and this class
/// routes by [AttachmentRef.kind].
///
/// For v1 (vault-only) we still expose this so the call site doesn't
/// have to change when later phases plug in new kinds — they just
/// inject more resolvers into the same dispatch.
class CompositeAttachmentResolver implements IAttachmentResolver {
  const CompositeAttachmentResolver({
    required this.vault,
    this.phAsset,
    this.cloudFile,
  });

  final IAttachmentResolver vault;
  final IAttachmentResolver? phAsset;
  final IAttachmentResolver? cloudFile;

  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async {
    return switch (ref) {
      VaultRef() => vault.resolve(ref),
      PhAssetRef() => phAsset?.resolve(ref) ?? Future.value(null),
      CloudFileRef() => cloudFile?.resolve(ref) ?? Future.value(null),
    };
  }
}
