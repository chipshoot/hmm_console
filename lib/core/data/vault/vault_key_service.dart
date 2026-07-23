// Holds the derived vault key for the session (in memory only in 4a;
// secure-storage caching + biometric gating land in 4b). Reads/writes
// the non-secret vault_meta.json through the BASE (unencrypted) store.

import 'dart:convert';
import 'dart:typed_data';

import 'crypto/vault_crypto.dart';
import 'sensitive_path.dart';
import 'vault_key_cache.dart';
import 'vault_meta.dart';
import 'vault_store.dart';

/// Outcome of inspecting vault_meta.json.
enum VaultConfigState { absent, configured, corrupt }

class VaultKeyService {
  VaultKeyService({
    required IVaultStore store,
    VaultCrypto crypto = const VaultCrypto(),
    Argon2Params params = Argon2Params.production,
    VaultKeyCache? cache,
  })  : _store = store,
        _crypto = crypto,
        _params = params,
        _cache = cache;

  final IVaultStore _store;
  final VaultCrypto _crypto;
  final Argon2Params _params;
  final VaultKeyCache? _cache;

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
    await _cache?.write(key);
  }

  /// Decrypts [meta]'s key-verifier under [key] and checks it against the
  /// known sentinel. True only if [key] is the correct key for [meta].
  /// Never throws: a failed (unauthenticated) decrypt is treated as "does
  /// not verify", not an error — shared by [unlock] and [unlockFromCache]
  /// so both apply exactly the same proof-of-correctness check.
  Future<bool> _verifyKeyAgainstMeta(Uint8List key, VaultMeta meta) async {
    try {
      final clear = await _crypto.decrypt(meta.keyVerifier, key);
      return utf8.decode(clear) == _sentinel;
    } on VaultCryptoException {
      return false;
    }
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
    if (!await _verifyKeyAgainstMeta(key, meta)) return false;
    _key = key;
    await _cache?.write(key);
    return true;
  }

  /// Restore the key from the secure-storage cache without a passphrase.
  ///
  /// A cached key is only ever held if it actually verifies against the
  /// CURRENT vault_meta.json (same check [unlock] performs against a
  /// freshly-derived key). This closes the cross-tier hole where a key
  /// cached while unlocking one vault tier (e.g. cloudStorage) could
  /// otherwise "restore" as if it unlocked a completely different vault
  /// (e.g. local) merely because a key was sitting in the shared
  /// secure-storage cache slot. It also refuses to hold a key when the
  /// current meta is absent or corrupt — no meta means nothing to verify
  /// against, so a stale cached key is cleared rather than trusted.
  ///
  /// Returns true (and holds the key) only when a cached key is present
  /// AND verifies against the current meta. In every other case it
  /// returns false and — whenever a key was cached at all — clears the
  /// cache so the stale/mismatched entry doesn't linger.
  Future<bool> unlockFromCache() async {
    final cached = await _cache?.read();
    if (cached == null) return false;

    final VaultMeta? meta;
    try {
      meta = await _readMetaOrThrow();
    } on FormatException {
      await _cache?.clear();
      return false; // corrupt meta → nothing to verify the key against
    }
    if (meta == null) {
      await _cache?.clear();
      return false; // no vault configured → nothing to verify against
    }
    if (!await _verifyKeyAgainstMeta(cached, meta)) {
      await _cache?.clear();
      return false; // wrong tier / stale / garbage key
    }

    _key = cached;
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
    await _cache?.clear();
  }
}
