// Holds the derived vault key for the session (in memory only in 4a;
// secure-storage caching + biometric gating land in 4b). Reads/writes
// the non-secret vault_meta.json through the BASE (unencrypted) store.

import 'dart:convert';
import 'dart:typed_data';

import 'crypto/vault_crypto.dart';
import 'sensitive_path.dart';
import 'vault_meta.dart';
import 'vault_store.dart';

/// Outcome of inspecting vault_meta.json.
enum VaultConfigState { absent, configured, corrupt }

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

  /// Reads meta bytes; null if absent. Throws [FormatException] if present
  /// but undecodable (caller decides how to surface corrupt).
  Future<VaultMeta?> _readMetaOrThrow() async {
    final Uint8List bytes;
    try {
      bytes = await _store.getBytes(vaultMetaPath);
    } on VaultStoreException {
      return null; // absent
    }
    return VaultMetaCodec.decode(utf8.decode(bytes)); // may throw FormatException
  }

  Future<VaultConfigState> configState() async {
    try {
      final meta = await _readMetaOrThrow();
      return meta == null
          ? VaultConfigState.absent
          : VaultConfigState.configured;
    } on FormatException {
      return VaultConfigState.corrupt;
    }
  }

  Future<bool> isConfigured() async =>
      (await configState()) == VaultConfigState.configured;

  /// First-time setup. Throws [StateError] if the vault already exists
  /// or the existing meta is corrupt (passphrase rotation is out of
  /// scope for this phase; corrupt meta must go through [reset] first
  /// so recoverable ciphertext is never silently overwritten).
  Future<void> setupPassphrase(String passphrase) async {
    if (await configState() != VaultConfigState.absent) {
      throw StateError('vault already configured or corrupt');
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
  /// on a wrong passphrase or corrupt meta (UI routes corrupt to
  /// [reset]). Throws [StateError] if not configured.
  Future<bool> unlock(String passphrase) async {
    final VaultMeta? meta;
    try {
      meta = await _readMetaOrThrow();
    } on FormatException {
      return false; // corrupt meta → cannot unlock (UI routes to reset)
    }
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

  /// Destructive: removes vault_meta.json and every sensitive attachment,
  /// then drops the in-memory key. Non-sensitive files are untouched.
  Future<void> reset() async {
    final entries = await _store.list('');
    for (final e in entries) {
      if (e.relativePath == vaultMetaPath ||
          isSensitiveVaultPath(e.relativePath)) {
        await _store.delete(e.relativePath);
      }
    }
    _key = null;
  }
}
