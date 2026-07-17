// Holds the derived vault key for the session (in memory only in 4a;
// secure-storage caching + biometric gating land in 4b). Reads/writes
// the non-secret vault_meta.json through the BASE (unencrypted) store.

import 'dart:convert';
import 'dart:typed_data';

import 'crypto/vault_crypto.dart';
import 'vault_meta.dart';
import 'vault_store.dart';

class VaultKeyService {
  VaultKeyService({
    required IVaultStore store,
    VaultCrypto crypto = const VaultCrypto(),
    Argon2Params params = Argon2Params.production,
  })  : _store = store,
        _crypto = crypto,
        _params = params;

  final IVaultStore _store;
  final VaultCrypto _crypto;
  final Argon2Params _params;

  /// Known plaintext encrypted under the key to prove correctness.
  static const String _sentinel = 'hmm-secure-vault-v1';

  Uint8List? _key;

  Uint8List? get currentKey => _key;
  bool get isUnlocked => _key != null;

  Future<VaultMeta?> _readMeta() async {
    try {
      final bytes = await _store.getBytes(vaultMetaPath);
      return VaultMetaCodec.decode(utf8.decode(bytes));
    } on VaultStoreException {
      return null; // not set up yet
    }
  }

  Future<bool> isConfigured() async => (await _readMeta()) != null;

  /// First-time setup. Throws [StateError] if the vault already exists
  /// (passphrase rotation is out of scope for this phase).
  Future<void> setupPassphrase(String passphrase) async {
    if (await isConfigured()) {
      throw StateError('vault already configured');
    }
    final salt = _crypto.newSalt();
    final key = await _crypto.deriveKey(passphrase, salt, _params);
    final verifier = await _crypto.encrypt(
        Uint8List.fromList(utf8.encode(_sentinel)), key);
    final meta = VaultMeta(
      version: 1,
      salt: salt,
      params: _params,
      keyVerifier: verifier,
    );
    await _store.putBytes(
      vaultMetaPath,
      Uint8List.fromList(utf8.encode(VaultMetaCodec.encode(meta))),
    );
    _key = key;
  }

  /// Derive from [passphrase] and verify against the stored verifier.
  /// Returns true and holds the key on success; false and holds nothing
  /// on a wrong passphrase. Throws [StateError] if not configured.
  Future<bool> unlock(String passphrase) async {
    final meta = await _readMeta();
    if (meta == null) throw StateError('vault not configured');
    final key = await _crypto.deriveKey(passphrase, meta.salt, meta.params);
    try {
      final clear = await _crypto.decrypt(meta.keyVerifier, key);
      if (utf8.decode(clear) != _sentinel) return false;
    } on VaultCryptoException {
      return false;
    }
    _key = key;
    return true;
  }

  void lock() {
    _key = null;
  }
}
