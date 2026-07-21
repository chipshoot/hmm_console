import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/vault/biometric_gate.dart';
import 'package:hmm_console/core/data/vault/crypto/vault_crypto.dart';
import 'package:hmm_console/core/data/vault/vault_key_cache.dart';
import 'package:hmm_console/core/data/vault/vault_key_service.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
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

class _FakeGate implements BiometricGate {
  _FakeGate(this.result);
  bool result;
  int calls = 0;
  @override
  Future<bool> authenticate() async {
    calls++;
    return result;
  }
}

/// Mutable clock for driving VaultSessionController's `now` injection hook
/// deterministically (inactivity timeout / touch() tests).
class _FakeClock {
  DateTime _t = DateTime(2026, 1, 1);
  DateTime call() => _t;
  void advance(Duration d) => _t = _t.add(d);
}

void main() {
  // Needed for the app-pause test below, which drives the real
  // WidgetsBinding lifecycle dispatch (WidgetsBinding.instance must be
  // initialized before VaultSessionController.build() registers its
  // observer). Matches the pattern used elsewhere in this repo's tests
  // (e.g. test/core/data/sync/sync_controller_test.dart).
  TestWidgetsFlutterBinding.ensureInitialized();

  // Wiring note: vaultKeyServiceProvider is a FutureProvider<VaultKeyService>
  // (it awaits the base store), so VaultSessionController resolves it
  // asynchronously and memoizes it rather than reading a synchronous
  // vaultSessionServiceProvider. The test overrides vaultKeyServiceProvider
  // directly with an async factory returning the fake service.
  //
  // Pass `now` to also override vaultSessionProvider itself with a
  // VaultSessionController wired to a fake/injectable clock, so timed-relock
  // behavior (inactivity timeout, refresh()-stamps-access-time regression)
  // can be driven deterministically instead of racing wall-clock time.
  ProviderContainer containerWith(VaultKeyService svc, BiometricGate gate,
          {DateTime Function()? now}) =>
      ProviderContainer(overrides: [
        vaultKeyServiceProvider.overrideWith((ref) async => svc),
        biometricGateProvider.overrideWithValue(gate),
        if (now != null)
          vaultSessionProvider
              .overrideWith(() => VaultSessionController(now: now)),
      ]);

  test('absent → setup → unlocked', () async {
    final svc = VaultKeyService(
        store: _FakeVaultStore(), params: Argon2Params.test, cache: _MemCache());
    final c = containerWith(svc, _FakeGate(true));
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);
    await ctrl.refresh();
    expect(c.read(vaultSessionProvider), VaultStatus.absent);
    await ctrl.setup('hunter2');
    expect(c.read(vaultSessionProvider), VaultStatus.unlocked);
  });

  test('locked → biometric success → unlocked (no passphrase)', () async {
    final store = _FakeVaultStore();
    final svc = VaultKeyService(
        store: store, params: Argon2Params.test, cache: _MemCache());
    await svc.setupPassphrase('hunter2');
    svc.lock();
    final gate = _FakeGate(true);
    final c = containerWith(svc, gate);
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);
    await ctrl.refresh();
    expect(c.read(vaultSessionProvider), VaultStatus.locked);
    expect(await ctrl.unlockWithBiometric(), isTrue);
    expect(gate.calls, 1);
    expect(c.read(vaultSessionProvider), VaultStatus.unlocked);
  });

  test('biometric denied stays locked; passphrase fallback unlocks', () async {
    final store = _FakeVaultStore();
    final svc = VaultKeyService(
        store: store, params: Argon2Params.test, cache: _MemCache());
    await svc.setupPassphrase('hunter2');
    svc.lock();
    final c = containerWith(svc, _FakeGate(false));
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);
    await ctrl.refresh();
    expect(await ctrl.unlockWithBiometric(), isFalse);
    expect(c.read(vaultSessionProvider), VaultStatus.locked);
    expect(await ctrl.unlockWithPassphrase('hunter2'), isTrue);
    expect(c.read(vaultSessionProvider), VaultStatus.unlocked);
  });

  test('corrupt meta → corrupt status; reset → absent', () async {
    final store = _FakeVaultStore();
    await store.putBytes('vault_meta.json', Uint8List.fromList('x'.codeUnits));
    final svc = VaultKeyService(
        store: store, params: Argon2Params.test, cache: _MemCache());
    final c = containerWith(svc, _FakeGate(true));
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);
    await ctrl.refresh();
    expect(c.read(vaultSessionProvider), VaultStatus.corrupt);
    await ctrl.reset();
    expect(c.read(vaultSessionProvider), VaultStatus.absent);
  });

  test('lockNow relocks', () async {
    final svc = VaultKeyService(
        store: _FakeVaultStore(), params: Argon2Params.test, cache: _MemCache());
    final c = containerWith(svc, _FakeGate(true));
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);
    await ctrl.setup('hunter2');
    ctrl.lockNow();
    expect(c.read(vaultSessionProvider), VaultStatus.locked);
  });

  test('unlockFromCache throwing during biometric unlock is a clean failure',
      () async {
    // B2 hardening: unlockFromCache()/secure-storage read() can throw on a
    // corrupt cached key or a PlatformException. unlockWithBiometric() must
    // treat that as a normal unlock failure (stay locked), never crash.
    final store = _FakeVaultStore();
    final svc = VaultKeyService(
        store: store, params: Argon2Params.test, cache: _ThrowingCache());
    await svc.setupPassphrase('hunter2');
    svc.lock();
    final c = containerWith(svc, _FakeGate(true));
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);
    await ctrl.refresh();
    expect(await ctrl.unlockWithBiometric(), isFalse);
    expect(c.read(vaultSessionProvider), VaultStatus.locked);
  });

  test(
      'refresh() resolving to unlocked stamps access time; '
      'immediate touch() does not relock', () async {
    // Regression for the latent B3 defect: refresh()'s `unlocked` branch
    // (configured + svc already unlocked, e.g. app-resume with a live
    // in-memory key) must stamp _lastAccessAt, or a subsequent touch() sees
    // now - epoch0 > 5min and relocks a legitimately-unlocked session.
    final clock = _FakeClock();
    final store = _FakeVaultStore();
    final svc = VaultKeyService(
        store: store, params: Argon2Params.test, cache: _MemCache());
    // svc is already unlocked before the controller ever sees it — the
    // controller's own _touchNow() calls (setup/unlockWith*) are bypassed.
    await svc.setupPassphrase('hunter2');
    final c = containerWith(svc, _FakeGate(true), now: clock.call);
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);

    await ctrl.refresh();
    expect(c.read(vaultSessionProvider), VaultStatus.unlocked);

    clock.advance(const Duration(seconds: 1)); // well within the timeout
    ctrl.touch();
    expect(c.read(vaultSessionProvider), VaultStatus.unlocked);
  });

  test(
      'touch() relocks after the inactivity timeout; bumps within timeout',
      () async {
    final clock = _FakeClock();
    final svc = VaultKeyService(
        store: _FakeVaultStore(), params: Argon2Params.test, cache: _MemCache());
    final c = containerWith(svc, _FakeGate(true), now: clock.call);
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);
    await ctrl.setup('hunter2');
    expect(c.read(vaultSessionProvider), VaultStatus.unlocked);

    // Within the 5-minute timeout: touch() bumps the clock, stays unlocked.
    clock.advance(const Duration(minutes: 4));
    ctrl.touch();
    expect(c.read(vaultSessionProvider), VaultStatus.unlocked);

    // More than 5 minutes since the last touch (bumped above): relocks.
    clock.advance(const Duration(minutes: 5, seconds: 1));
    ctrl.touch();
    expect(c.read(vaultSessionProvider), VaultStatus.locked);
  });

  test('unlocked session relocks on app pause', () async {
    // Drives the real WidgetsBinding lifecycle dispatch (the same path a
    // genuine app-pause transition uses) rather than reaching into the
    // private _LifecycleObserver — no test-only production hooks needed.
    final svc = VaultKeyService(
        store: _FakeVaultStore(), params: Argon2Params.test, cache: _MemCache());
    final c = containerWith(svc, _FakeGate(true));
    addTearDown(c.dispose);
    final ctrl = c.read(vaultSessionProvider.notifier);
    await ctrl.setup('hunter2');
    expect(c.read(vaultSessionProvider), VaultStatus.unlocked);

    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);

    expect(c.read(vaultSessionProvider), VaultStatus.locked);
  });
}

/// Cache whose read() throws, simulating a corrupt cached key or a
/// PlatformException surfaced by secure storage.
class _ThrowingCache implements VaultKeyCache {
  @override
  Future<Uint8List?> read() async => throw Exception('boom');
  @override
  Future<void> write(Uint8List key) async {}
  @override
  Future<void> clear() async {}
}
