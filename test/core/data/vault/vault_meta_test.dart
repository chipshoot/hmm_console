import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/crypto/vault_crypto.dart';
import 'package:hmm_console/core/data/vault/vault_meta.dart';

void main() {
  test('VaultMeta encode/decode round-trips', () {
    final meta = VaultMeta(
      version: 1,
      salt: Uint8List.fromList(List<int>.generate(16, (i) => i)),
      params: Argon2Params.production,
      keyVerifier: Uint8List.fromList(List<int>.generate(60, (i) => i)),
    );
    final raw = VaultMetaCodec.encode(meta);
    final back = VaultMetaCodec.decode(raw);
    expect(back, meta);
  });

  test('decode of malformed JSON throws FormatException', () {
    expect(() => VaultMetaCodec.decode('not json'),
        throwsA(isA<FormatException>()));
  });

  test('vaultMetaPath is a valid single-segment path', () {
    expect(vaultMetaPath, 'vault_meta.json');
  });
}
