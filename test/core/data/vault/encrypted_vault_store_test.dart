import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/crypto/vault_crypto.dart';
import 'package:hmm_console/core/data/vault/encrypted_vault_store.dart';
import 'package:hmm_console/core/data/vault/sensitive_path.dart';
import 'package:hmm_console/core/data/vault/vault_key_service.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';

class _FakeVaultStore implements IVaultStore {
  final Map<String, Uint8List> m = {};
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async {
    m[p] = b;
  }

  @override
  Future<Uint8List> getBytes(String p) async {
    final v = m[p];
    if (v == null) throw VaultStoreException('missing', p);
    return v;
  }

  @override
  Future<bool> exists(String p) async => m.containsKey(p);
  @override
  Future<void> delete(String p) async => m.remove(p);
  @override
  Future<List<VaultEntry>> list(String prefix) async => m.entries
      .where((e) => e.key.startsWith(prefix))
      .map((e) => VaultEntry(relativePath: e.key, byteSize: e.value.length))
      .toList();
}

void main() {
  late _FakeVaultStore inner;
  late VaultKeyService keys;
  late EncryptedVaultStore store;

  setUp(() async {
    inner = _FakeVaultStore();
    keys = VaultKeyService(store: inner, params: Argon2Params.test);
    store = EncryptedVaultStore(inner: inner, keyService: keys);
    await keys.setupPassphrase('hunter2'); // unlocked
  });

  final sensitivePath = buildSensitiveAttachmentPath(noteId: 1, ext: 'jpg');
  final plain = Uint8List.fromList(utf8.encode('sensitive image bytes'));

  test('sensitive put stores ciphertext; get returns plaintext', () async {
    await store.putBytes(sensitivePath, plain, contentType: 'image/jpeg');
    // The inner store holds ciphertext, not the plaintext.
    expect(inner.m[sensitivePath], isNotNull);
    expect(inner.m[sensitivePath], isNot(equals(plain)));
    final back = await store.getBytes(sensitivePath);
    expect(back, equals(plain));
  });

  test('non-sensitive path bypasses crypto entirely', () async {
    const p = 'attachments/note-1/a.jpg';
    await store.putBytes(p, plain, contentType: 'image/jpeg');
    expect(inner.m[p], equals(plain)); // stored verbatim
    expect(await store.getBytes(p), equals(plain));
  });

  test('locked sensitive put throws VaultLockedException', () async {
    keys.lock();
    expect(() => store.putBytes(sensitivePath, plain),
        throwsA(isA<VaultLockedException>()));
  });

  test('locked sensitive get (existing file) throws VaultLockedException',
      () async {
    await store.putBytes(sensitivePath, plain); // written while unlocked
    keys.lock();
    expect(() => store.getBytes(sensitivePath),
        throwsA(isA<VaultLockedException>()));
  });

  test('missing sensitive file throws VaultStoreException, not locked',
      () async {
    // Unlocked, but the file was never written.
    expect(
        () => store
            .getBytes(buildSensitiveAttachmentPath(noteId: 9, ext: 'jpg')),
        throwsA(isA<VaultStoreException>()));
  });

  test('exists/delete/list pass through', () async {
    await store.putBytes(sensitivePath, plain);
    expect(await store.exists(sensitivePath), isTrue);
    await store.delete(sensitivePath);
    expect(await store.exists(sensitivePath), isFalse);
  });
}
