import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/crypto/vault_crypto.dart';

void main() {
  const crypto = VaultCrypto();

  test('encrypt then decrypt round-trips; ciphertext != plaintext', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final plain = Uint8List.fromList(utf8.encode('top secret ID card'));
    final framed = await crypto.encrypt(plain, key);
    expect(framed, isNot(equals(plain)));
    expect(framed.length, greaterThan(plain.length)); // + nonce + tag
    final back = await crypto.decrypt(framed, key);
    expect(back, equals(plain));
  });

  test('decrypt with the wrong key throws VaultCryptoException', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final wrong = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
    final framed = await crypto.encrypt(
        Uint8List.fromList(utf8.encode('x')), key);
    expect(() => crypto.decrypt(framed, wrong),
        throwsA(isA<VaultCryptoException>()));
  });

  test('decrypt of a too-short frame throws VaultCryptoException', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    expect(() => crypto.decrypt(Uint8List.fromList([1, 2, 3]), key),
        throwsA(isA<VaultCryptoException>()));
  });

  test('deriveKey is deterministic for (passphrase, salt, params)', () async {
    final salt = Uint8List.fromList(List<int>.generate(16, (i) => i));
    const params = Argon2Params.test;
    final k1 = await crypto.deriveKey('hunter2', salt, params);
    final k2 = await crypto.deriveKey('hunter2', salt, params);
    expect(k1, equals(k2));
    expect(k1.length, 32);
    final k3 = await crypto.deriveKey('different', salt, params);
    expect(k3, isNot(equals(k1)));
  });

  test('Argon2Params JSON round-trips', () {
    const p = Argon2Params.production;
    expect(Argon2Params.fromJson(p.toJson()), p);
  });

  test('newSalt returns the requested length and varies', () {
    final a = crypto.newSalt();
    final b = crypto.newSalt();
    expect(a.length, 16);
    expect(a, isNot(equals(b)));
  });
}
