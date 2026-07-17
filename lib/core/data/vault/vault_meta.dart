// Non-secret vault metadata written to `vault_meta.json` at the vault
// root. Holds the Argon2 salt + params and a key-verifier (a small
// GCM-encrypted sentinel) so a device can (a) re-derive the key from a
// passphrase and (b) confirm the passphrase is correct without a second
// KDF pass. Contains NO key material. Rides the normal vault sync path.

import 'dart:convert';
import 'dart:typed_data';

import 'crypto/vault_crypto.dart';

/// Fixed vault path for the metadata file (vault root).
const String vaultMetaPath = 'vault_meta.json';

class VaultMeta {
  const VaultMeta({
    required this.version,
    required this.salt,
    required this.params,
    required this.keyVerifier,
  });

  final int version;
  final Uint8List salt;
  final Argon2Params params;

  /// GCM frame of a known sentinel encrypted under the derived key.
  final Uint8List keyVerifier;

  @override
  bool operator ==(Object other) =>
      other is VaultMeta &&
      other.version == version &&
      _bytesEqual(other.salt, salt) &&
      other.params == params &&
      _bytesEqual(other.keyVerifier, keyVerifier);

  @override
  int get hashCode =>
      Object.hash(version, Object.hashAll(salt), params,
          Object.hashAll(keyVerifier));
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class VaultMetaCodec {
  const VaultMetaCodec._();

  static String encode(VaultMeta m) => jsonEncode({
        'version': m.version,
        'salt': base64Encode(m.salt),
        'argon2': m.params.toJson(),
        'keyVerifier': base64Encode(m.keyVerifier),
      });

  static VaultMeta decode(String raw) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException('vault_meta: invalid JSON — ${e.message}');
    }
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('vault_meta: expected an object');
    }
    try {
      return VaultMeta(
        version: parsed['version'] as int,
        salt: base64Decode(parsed['salt'] as String),
        params: Argon2Params.fromJson(parsed['argon2'] as Map<String, dynamic>),
        keyVerifier: base64Decode(parsed['keyVerifier'] as String),
      );
    } catch (e) {
      throw FormatException('vault_meta: invalid shape — $e');
    }
  }
}
