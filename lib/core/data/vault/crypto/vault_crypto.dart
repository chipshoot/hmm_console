// Vault crypto primitives: AES-256-GCM authenticated encryption and
// Argon2id key derivation. Pure over byte buffers; no I/O, no key
// storage (that is VaultKeyService's job). A failed decrypt throws
// VaultCryptoException — it never returns unauthenticated bytes.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Fixed Argon2id cost parameters, echoed into vault_meta so any device
/// re-derives the same key. `production` is used at setup; `test` is a
/// tiny profile for fast unit tests.
class Argon2Params {
  const Argon2Params({
    required this.memory,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
  });

  /// Memory cost in KiB.
  final int memory;
  final int iterations;
  final int parallelism;
  final int hashLength;

  static const production = Argon2Params(
    memory: 19456, // 19 MiB
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
  );

  /// Deliberately weak — for unit tests only, never written by setup.
  static const test = Argon2Params(
    memory: 256,
    iterations: 1,
    parallelism: 1,
    hashLength: 32,
  );

  Map<String, dynamic> toJson() => {
        'memory': memory,
        'iterations': iterations,
        'parallelism': parallelism,
        'hashLength': hashLength,
      };

  factory Argon2Params.fromJson(Map<String, dynamic> j) => Argon2Params(
        memory: j['memory'] as int,
        iterations: j['iterations'] as int,
        parallelism: j['parallelism'] as int,
        hashLength: j['hashLength'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is Argon2Params &&
      other.memory == memory &&
      other.iterations == iterations &&
      other.parallelism == parallelism &&
      other.hashLength == hashLength;

  @override
  int get hashCode => Object.hash(memory, iterations, parallelism, hashLength);
}

/// Thrown when authenticated decryption fails (wrong key, tampered
/// bytes, malformed frame). Never carries plaintext.
class VaultCryptoException implements Exception {
  const VaultCryptoException(this.message);
  final String message;
  @override
  String toString() => 'VaultCryptoException: $message';
}

class VaultCrypto {
  const VaultCrypto();

  static const int _nonceLength = 12;
  static const int _macLength = 16;

  /// AES-256-GCM encrypt. Output is `nonce(12) ‖ ciphertext ‖ tag(16)`.
  Future<Uint8List> encrypt(Uint8List plaintext, Uint8List key) async {
    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(plaintext, secretKey: SecretKey(key));
    return Uint8List.fromList(box.concatenation());
  }

  /// AES-256-GCM decrypt of a frame produced by [encrypt]. Any failure
  /// (bad key/tag/length) throws [VaultCryptoException].
  Future<Uint8List> decrypt(Uint8List framed, Uint8List key) async {
    final algo = AesGcm.with256bits();
    try {
      final box = SecretBox.fromConcatenation(
        framed,
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      final clear = await algo.decrypt(box, secretKey: SecretKey(key));
      return Uint8List.fromList(clear);
    } catch (_) {
      throw const VaultCryptoException('decryption failed');
    }
  }

  /// Argon2id → a [Argon2Params.hashLength]-byte key.
  Future<Uint8List> deriveKey(
    String passphrase,
    Uint8List salt,
    Argon2Params params,
  ) async {
    final argon2 = Argon2id(
      memory: params.memory,
      iterations: params.iterations,
      parallelism: params.parallelism,
      hashLength: params.hashLength,
    );
    final derived = await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  /// Cryptographically-random salt.
  Uint8List newSalt([int length = 16]) {
    final rnd = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => rnd.nextInt(256)));
  }
}
