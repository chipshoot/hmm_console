// IVaultFileStore — by-path access to a filesystem-backed vault, so large
// files (videos, up to 2 GB) never pass through Dart memory.

import 'dart:io';

import 'vault_store.dart' show VaultEntry;

abstract interface class IVaultFileStore {
  /// Moves [source] into the vault at [relativePath]. Throws
  /// [ArgumentError] for an invalid or sensitive path and
  /// `VaultStoreException` if [source] is missing.
  Future<void> importFile(String relativePath, File source);

  /// The absolute file for [relativePath], or null when it is not on this
  /// device.
  Future<File?> localFile(String relativePath);

  /// Moves a video from the vault root to the offload root. No-op if it is
  /// already there. Throws [ArgumentError] for a non-video path and
  /// `VaultStoreException` if the file is in neither root.
  Future<void> offload(String relativePath);

  /// Where a download of this video should end up, or null when there is no
  /// offload root.
  File? downloadTarget(String relativePath);

  /// Videos in the offload home only (never the vault root), skipping
  /// `*.part` and `*.tmp`. Empty when there is no offload root.
  Future<List<VaultEntry>> listOffloaded();

  /// Deletes the offload copy of [relativePath]. Never touches the vault
  /// root.
  Future<void> deleteOffloaded(String relativePath);

  /// Last-modified time of the offload copy, or null when there is none.
  Future<DateTime?> offloadedModified(String relativePath);

  /// Deletes `*.part` files under the offload root and returns how many.
  Future<int> deleteStaleParts();
}
