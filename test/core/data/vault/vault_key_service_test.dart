import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/crypto/vault_crypto.dart';
import 'package:hmm_console/core/data/vault/vault_key_cache.dart';
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

/// In-memory VaultKeyCache for headless tests.
class _MemCache implements VaultKeyCache {
  Uint8List? _v;
  @override
  Future<Uint8List?> read() async => _v;
  @override
  Future<void> write(Uint8List key) async => _v = key;
  @override
  Future<void> clear() async => _v = null;
}

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

  group('corrupt state + reset', () {
    test('configState reports corrupt for undecodable meta', () async {
      final store = _FakeVaultStore();
      await store.putBytes('vault_meta.json',
          Uint8List.fromList('not json'.codeUnits));
      final s = _service(store);
      expect(await s.configState(), VaultConfigState.corrupt);
    });

    test('configState reports absent then configured', () async {
      final store = _FakeVaultStore();
      final s = _service(store);
      expect(await s.configState(), VaultConfigState.absent);
      await s.setupPassphrase('hunter2');
      expect(await s.configState(), VaultConfigState.configured);
    });

    test('setupPassphrase refuses over corrupt meta (no overwrite)', () async {
      final store = _FakeVaultStore();
      await store.putBytes('vault_meta.json',
          Uint8List.fromList('not json'.codeUnits));
      final s = _service(store);
      expect(() => s.setupPassphrase('x'), throwsA(isA<StateError>()));
      // Corrupt bytes are untouched.
      expect(await store.getBytes('vault_meta.json'),
          Uint8List.fromList('not json'.codeUnits));
    });

    test('reset deletes meta + sensitive files, keeps non-sensitive', () async {
      final store = _FakeVaultStore();
      final s = _service(store);
      await s.setupPassphrase('hunter2');
      await store.putBytes('attachments/note-1/sensitive/a.enc',
          Uint8List.fromList([1, 2, 3]));
      await store.putBytes('attachments/note-1/plain.jpg',
          Uint8List.fromList([4, 5, 6]));
      await s.reset();
      expect(await store.exists('vault_meta.json'), isFalse);
      expect(await store.exists('attachments/note-1/sensitive/a.enc'), isFalse);
      expect(await store.exists('attachments/note-1/plain.jpg'), isTrue);
      expect(s.currentKey, isNull);
      expect(await s.configState(), VaultConfigState.absent);
    });
  });

  group('key cache', () {
    test('setup writes cache; lock keeps it; unlockFromCache restores', () async {
      final store = _FakeVaultStore();
      final cache = _MemCache();
      final s = VaultKeyService(
          store: store, params: Argon2Params.test, cache: cache);
      await s.setupPassphrase('hunter2');
      expect(await cache.read(), isNotNull);
      s.lock();
      expect(s.currentKey, isNull);
      expect(await cache.read(), isNotNull, reason: 'lock keeps the cache');
      expect(await s.unlockFromCache(), isTrue);
      expect(s.currentKey, isNotNull);
    });

    test('unlockFromCache false when cache empty', () async {
      final s = VaultKeyService(
          store: _FakeVaultStore(),
          params: Argon2Params.test,
          cache: _MemCache());
      expect(await s.unlockFromCache(), isFalse);
      expect(s.currentKey, isNull);
    });

    test('reset clears the cache', () async {
      final store = _FakeVaultStore();
      final cache = _MemCache();
      final s = VaultKeyService(
          store: store, params: Argon2Params.test, cache: cache);
      await s.setupPassphrase('hunter2');
      await s.reset();
      expect(await cache.read(), isNull);
    });

    test(
        'unlockFromCache rejects a cached key that does not match the '
        'current meta (cross-tier key), clears the cache', () async {
      // Simulates the cross-tier hole: a key cached while unlocking one
      // vault tier (e.g. cloudStorage) must not unlock a DIFFERENT vault's
      // meta (e.g. local) just because a key happens to be sitting in the
      // shared secure-storage cache slot.
      final otherStore = _FakeVaultStore();
      final otherCache = _MemCache();
      final other = VaultKeyService(
          store: otherStore, params: Argon2Params.test, cache: otherCache);
      await other.setupPassphrase('other-vault-passphrase');
      final wrongKey = other.currentKey!;

      final store = _FakeVaultStore();
      final cache = _MemCache();
      final s = VaultKeyService(
          store: store, params: Argon2Params.test, cache: cache);
      await s.setupPassphrase('this-vault-passphrase'); // writes real meta
      s.lock();
      // Re-seed cache with the wrong key after setup overwrote it.
      await cache.write(wrongKey);

      expect(await s.unlockFromCache(), isFalse);
      expect(s.currentKey, isNull);
      expect(await cache.read(), isNull, reason: 'mismatched cache cleared');
    });

    test('unlockFromCache with meta absent but a stale cached key clears '
        'the cache and returns false', () async {
      final store = _FakeVaultStore();
      final cache = _MemCache();
      // Seed a stale cached key with no vault_meta.json present at all.
      final other = VaultKeyService(
          store: _FakeVaultStore(), params: Argon2Params.test, cache: null);
      await other.setupPassphrase('whatever');
      await cache.write(other.currentKey!);

      final s = VaultKeyService(
          store: store, params: Argon2Params.test, cache: cache);
      expect(await s.configState(), VaultConfigState.absent);
      expect(await s.unlockFromCache(), isFalse);
      expect(s.currentKey, isNull);
      expect(await cache.read(), isNull);
    });

    test('unlockFromCache with corrupt meta clears the cache and returns '
        'false', () async {
      final store = _FakeVaultStore();
      await store.putBytes(
          'vault_meta.json', Uint8List.fromList('not json'.codeUnits));
      final cache = _MemCache();
      final other = VaultKeyService(
          store: _FakeVaultStore(), params: Argon2Params.test, cache: null);
      await other.setupPassphrase('whatever');
      await cache.write(other.currentKey!);

      final s = VaultKeyService(
          store: store, params: Argon2Params.test, cache: cache);
      expect(await s.configState(), VaultConfigState.corrupt);
      expect(await s.unlockFromCache(), isFalse);
      expect(s.currentKey, isNull);
      expect(await cache.read(), isNull);
    });
  });
}
