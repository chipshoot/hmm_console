// Transparent encryption decorator over an IVaultStore. Encrypts only
// paths flagged sensitive by convention (a `sensitive/` segment); all
// other paths and the exists/delete/list operations pass straight
// through. Requires an unlocked VaultKeyService for sensitive I/O.

import 'dart:typed_data';

import 'crypto/vault_crypto.dart';
import 'sensitive_path.dart';
import 'vault_key_service.dart';
import 'vault_store.dart';

/// Thrown when a sensitive path is read/written while the vault key is
/// locked. Distinct from [VaultStoreException] (missing/IO) so callers
/// can show a "locked" affordance rather than a broken-file one.
class VaultLockedException implements Exception {
  const VaultLockedException(this.relativePath);
  final String relativePath;
  @override
  String toString() => 'VaultLockedException(path: $relativePath)';
}

class EncryptedVaultStore implements IVaultStore {
  EncryptedVaultStore({
    required IVaultStore inner,
    required VaultKeyService keyService,
    VaultCrypto crypto = const VaultCrypto(),
  })  : _inner = inner,
        _keys = keyService,
        _crypto = crypto;

  final IVaultStore _inner;
  final VaultKeyService _keys;
  final VaultCrypto _crypto;

  @override
  Future<void> putBytes(
    String relativePath,
    Uint8List bytes, {
    String? contentType,
  }) async {
    if (!isSensitiveVaultPath(relativePath)) {
      return _inner.putBytes(relativePath, bytes, contentType: contentType);
    }
    final key = _keys.currentKey;
    if (key == null) throw VaultLockedException(relativePath);
    final ciphertext = await _crypto.encrypt(bytes, key);
    return _inner.putBytes(relativePath, ciphertext, contentType: contentType);
  }

  @override
  Future<Uint8List> getBytes(String relativePath) async {
    // Read first so a genuinely-missing file surfaces as
    // VaultStoreException even for sensitive paths — that lets the UI
    // tell "missing" from "locked".
    final stored = await _inner.getBytes(relativePath);
    if (!isSensitiveVaultPath(relativePath)) return stored;
    final key = _keys.currentKey;
    if (key == null) throw VaultLockedException(relativePath);
    return _crypto.decrypt(stored, key);
  }

  @override
  Future<bool> exists(String relativePath) => _inner.exists(relativePath);

  @override
  Future<void> delete(String relativePath) => _inner.delete(relativePath);

  @override
  Future<List<VaultEntry>> list(String prefix) => _inner.list(prefix);
}
