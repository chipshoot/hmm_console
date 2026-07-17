import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/crypto/vault_crypto.dart';
import 'package:hmm_console/core/data/vault/vault_key_service.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';

/// In-memory IVaultStore for headless tests.
class _FakeVaultStore implements IVaultStore {
  final Map<String, Uint8List> _m = {};
  @override
  Future<void> putBytes(String p, Uint8List b, {String? contentType}) async {
    _m[p] = b;
  }

  @override
  Future<Uint8List> getBytes(String p) async {
    final v = _m[p];
    if (v == null) throw VaultStoreException('missing', p);
    return v;
  }

  @override
  Future<bool> exists(String p) async => _m.containsKey(p);
  @override
  Future<void> delete(String p) async => _m.remove(p);
  @override
  Future<List<VaultEntry>> list(String prefix) async => _m.entries
      .where((e) => e.key.startsWith(prefix))
      .map((e) => VaultEntry(relativePath: e.key, byteSize: e.value.length))
      .toList();
}

VaultKeyService _service(_FakeVaultStore store) => VaultKeyService(
      store: store,
      params: Argon2Params.test, // fast
    );

void main() {
  test('unconfigured by default; currentKey null', () async {
    final s = _service(_FakeVaultStore());
    expect(await s.isConfigured(), isFalse);
    expect(s.currentKey, isNull);
    expect(s.isUnlocked, isFalse);
  });

  test('setupPassphrase configures, holds the key, writes meta', () async {
    final store = _FakeVaultStore();
    final s = _service(store);
    await s.setupPassphrase('hunter2');
    expect(await s.isConfigured(), isTrue);
    expect(s.isUnlocked, isTrue);
    expect(s.currentKey, isNotNull);
    expect(await store.exists('vault_meta.json'), isTrue);
  });

  test('setupPassphrase throws if already configured', () async {
    final s = _service(_FakeVaultStore());
    await s.setupPassphrase('hunter2');
    expect(() => s.setupPassphrase('again'), throwsA(isA<StateError>()));
  });

  test('unlock with the right passphrase succeeds (fresh service)', () async {
    final store = _FakeVaultStore();
    await _service(store).setupPassphrase('hunter2');
    final s2 = _service(store); // simulates a new device/session
    expect(s2.isUnlocked, isFalse);
    expect(await s2.unlock('hunter2'), isTrue);
    expect(s2.currentKey, isNotNull);
  });

  test('unlock with the wrong passphrase fails and holds no key', () async {
    final store = _FakeVaultStore();
    await _service(store).setupPassphrase('hunter2');
    final s2 = _service(store);
    expect(await s2.unlock('WRONG'), isFalse);
    expect(s2.currentKey, isNull);
  });

  test('unlock throws if not configured', () async {
    final s = _service(_FakeVaultStore());
    expect(() => s.unlock('x'), throwsA(isA<StateError>()));
  });

  test('lock clears the key', () async {
    final s = _service(_FakeVaultStore());
    await s.setupPassphrase('hunter2');
    s.lock();
    expect(s.currentKey, isNull);
    expect(s.isUnlocked, isFalse);
  });
}
