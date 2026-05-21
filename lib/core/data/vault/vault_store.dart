// IVaultStore — the storage layer for attachment bytes.
//
// One interface, multiple implementations (local FS, OneDrive-backed
// local FS, API). All take and return vault relative paths validated
// through `vault_path.dart`; no implementation accepts an absolute
// path or a path that escapes the vault root.

import 'dart:typed_data';

/// A single entry returned by [IVaultStore.list].
class VaultEntry {
  const VaultEntry({required this.relativePath, required this.byteSize});

  /// Path relative to the vault root, in the form produced by
  /// `vaultRelativePathJoin` (POSIX separators).
  final String relativePath;

  /// File size in bytes.
  final int byteSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultEntry &&
          other.relativePath == relativePath &&
          other.byteSize == byteSize;

  @override
  int get hashCode => Object.hash(relativePath, byteSize);

  @override
  String toString() =>
      'VaultEntry(relativePath: $relativePath, byteSize: $byteSize)';
}

/// Abstract storage for attachment bytes, keyed by validated vault
/// relative paths.
///
/// Contract:
/// - Every method that takes a `relativePath` validates it through
///   `vaultRelativePathValidate`; bad paths throw [ArgumentError].
/// - [putBytes] is atomic: a reader can never see a half-written
///   file. The implementation writes to a temp file under the same
///   parent and renames into place.
/// - [delete] is idempotent — deleting a path that doesn't exist
///   succeeds silently.
/// - [list] returns entries whose `relativePath` is equal to or
///   nested under the given prefix; an empty string means "list
///   everything under the vault root."
abstract interface class IVaultStore {
  /// Write [bytes] at [relativePath]. The optional [contentType] is
  /// advisory — the local store ignores it; the API store sends it
  /// as the request `Content-Type`.
  ///
  /// Throws [ArgumentError] if [relativePath] is invalid.
  Future<void> putBytes(
    String relativePath,
    Uint8List bytes, {
    String? contentType,
  });

  /// Read the bytes at [relativePath].
  ///
  /// Throws [ArgumentError] if [relativePath] is invalid, and a
  /// [VaultStoreException] if the file doesn't exist.
  Future<Uint8List> getBytes(String relativePath);

  /// Returns `true` if [relativePath] exists in the vault.
  ///
  /// Throws [ArgumentError] if [relativePath] is invalid.
  Future<bool> exists(String relativePath);

  /// Delete the file at [relativePath]. Succeeds silently if it
  /// doesn't exist.
  ///
  /// Throws [ArgumentError] if [relativePath] is invalid.
  Future<void> delete(String relativePath);

  /// Enumerate every file under [prefix]. An empty [prefix] lists
  /// everything under the vault root.
  ///
  /// Throws [ArgumentError] if [prefix] is non-empty and invalid.
  Future<List<VaultEntry>> list(String prefix);
}

/// Thrown by stores for non-validation errors (file missing on read,
/// I/O failure). Validation failures throw [ArgumentError] instead.
class VaultStoreException implements Exception {
  const VaultStoreException(this.message, [this.relativePath]);
  final String message;
  final String? relativePath;

  @override
  String toString() => relativePath == null
      ? 'VaultStoreException: $message'
      : 'VaultStoreException: $message (path: $relativePath)';
}
