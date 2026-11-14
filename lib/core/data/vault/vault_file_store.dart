// IVaultFileStore — by-path access to a filesystem-backed vault, so large
// files (videos, up to 2 GB) never pass through Dart memory.

import 'dart:io';

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
}
