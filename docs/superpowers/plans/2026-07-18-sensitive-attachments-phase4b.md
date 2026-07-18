# Sensitive Attachments — Phase 4b (UX & Gate) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the user-facing Secure Vault layer on top of Phase 4a: corrupt-state handling + destructive reset, a biometric-gated secure-storage key cache with a timed session, a Settings "Secure Vault" section, add-time "Mark as sensitive", blurred/lock previews, and the cloud-AI exclusion gate.

**Architecture:** A `VaultKeyService` (4a) gains corrupt-detection, `reset()`, and an injectable key cache. A new `vaultSessionProvider` (Riverpod `Notifier`) exposes a `VaultStatus { absent, locked, unlocked, corrupt }` state, orchestrates biometric/passphrase unlock, and relocks on background/inactivity. The UI reads that status.

**Tech Stack:** Dart/Flutter, Riverpod 3.0.3, `flutter_secure_storage`, `local_auth`, plus all Phase 4a crypto.

**Parent design:** `docs/superpowers/specs/2026-07-18-sensitive-attachments-phase4b-design.md`.

## Global Constraints

- **Riverpod 3.0.3:** read async provider values with `.value ?? <default>` — **never** `.valueOrNull`. `WidgetRef` is `sealed` (cannot be faked in tests).
- **Never overwrite recoverable ciphertext:** a corrupt `vault_meta.json` must surface as a distinct **corrupt** state; `setupPassphrase` must refuse when meta is present-or-corrupt. The naive "catch FormatException → return null" is forbidden.
- **Reset is destructive and explicit:** `reset()` deletes `vault_meta.json` + every `sensitive/` vault entry + clears the cache; the UI gates it behind typed confirmation.
- **lock() keeps the cache:** relock drops only the in-memory key so biometric re-unlock needs no passphrase; only `reset()` clears the cache.
- **Add-time sensitivity only.** Persisting a sensitive image requires the vault **unlocked**; if a sensitive pick hits `VaultLockedException` at save, the flow must prompt unlock and retry — **never** silently strip the image.
- **No `cloudApi` behavior change.** No secret key or plaintext ever logged or put in an exception message.
- Platform channels (`flutter_secure_storage`, `local_auth`) are always injected behind a fakeable interface so tests run headless.
- `flutter analyze` clean after every task. Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## File Structure

- `lib/core/data/vault/vault_key_service.dart` — corrupt-detection + `reset()` + cache wiring (B1, B2).
- `lib/core/data/vault/vault_key_cache.dart` — **new**: `VaultKeyCache` interface + `SecureStorageVaultKeyCache` (B2).
- `lib/core/data/vault/biometric_gate.dart` — **new**: `BiometricGate` wrapper over `local_auth` (B3).
- `lib/core/data/vault/vault_session.dart` — **new**: `VaultStatus`, `VaultSessionController`, `vaultSessionProvider` (B3).
- `lib/features/settings/presentation/widgets/secure_vault_section.dart` — **new**: the Settings rows (B4).
- `lib/features/settings/presentation/screens/settings_screen.dart` — insert the section (B4).
- `lib/core/data/attachments/picker/image_byte_source.dart` — add `sensitive` to `PickedImageBytes` (B5).
- `lib/core/data/attachments/picker/image_attachment_picker.dart` — `persistToVault(..., sensitive)` (B5).
- `lib/features/notes/states/mutate_note_state.dart` — thread `sensitive` in `persistInlineImage` (B5).
- `lib/features/notes/presentation/widgets/media_toolbar.dart` + `note_editor_screen.dart` — "Add sensitive image" action + unlock-at-add + save-lock retry (B5).
- `lib/features/notes/presentation/widgets/sensitive_attachment_image.dart` — **new**: lock-aware image (B6).
- `lib/features/notes/presentation/widgets/note_markdown_body.dart` + `note_media_card_list.dart` — use it for sensitive refs (B6).
- `lib/features/receipt_scan/domain/receipt_draft.dart` + `data/api_llm_extractor.dart` — `sensitive` gate (B7).
- `pubspec.yaml` — add `local_auth` (B3).
- Tests mirror each under `test/`.

---

### Task B1: Corrupt-state detection + destructive `reset()`

**Files:**
- Modify: `lib/core/data/vault/vault_key_service.dart`
- Test: `test/core/data/vault/vault_key_service_test.dart` (add cases)

**Interfaces:**
- Consumes: `IVaultStore`, `VaultMetaCodec`, `isSensitiveVaultPath` (Phase 4a).
- Produces:
  - `enum VaultConfigState { absent, configured, corrupt }`
  - `Future<VaultConfigState> configState()` — `absent` (no meta), `corrupt` (meta present but `VaultMetaCodec.decode` throws), `configured` (valid).
  - `Future<void> reset()` — deletes meta + all `sensitive/` entries; drops in-memory key.
  - `setupPassphrase` now throws `StateError` if `configState() != absent` (i.e. also refuses over `corrupt`).

- [ ] **Step 1: Write the failing tests**

Add to `test/core/data/vault/vault_key_service_test.dart` (the `_FakeVaultStore` already exists in this file):

```dart
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/data/vault/vault_key_service_test.dart`
Expected: FAIL — `VaultConfigState`/`configState`/`reset` don't exist.

- [ ] **Step 3: Implement**

In `vault_key_service.dart`, add the enum (top level):

```dart
/// Outcome of inspecting vault_meta.json.
enum VaultConfigState { absent, configured, corrupt }
```

Add a meta reader that distinguishes absent from corrupt, and a state reader:

```dart
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
```

Update `isConfigured()` to `async => (await configState()) == VaultConfigState.configured;`.
Change `unlock` to treat corrupt as a clean failure (not a crash):

```dart
  Future<bool> unlock(String passphrase) async {
    final VaultMeta? meta;
    try {
      meta = await _readMetaOrThrow();
    } on FormatException {
      return false; // corrupt meta → cannot unlock (UI routes to reset)
    }
    if (meta == null) throw StateError('vault not configured');
    // ... unchanged: derive key, decrypt verifier, hold key, return true/false ...
  }
```

Change `setupPassphrase`'s guard to refuse over corrupt too:

```dart
  Future<void> setupPassphrase(String passphrase) async {
    if (await configState() != VaultConfigState.absent) {
      throw StateError('vault already configured or corrupt');
    }
    // ... unchanged ...
  }
```

Add `reset()` and the `sensitive_path.dart` import:

```dart
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
```

(Remove the now-unused old `_readMeta` if it's fully replaced; keep behavior identical for `unlock`/`isConfigured`.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/data/vault/vault_key_service_test.dart`
Expected: PASS (existing 4a tests + new group). Then `flutter analyze`.

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/vault/vault_key_service.dart test/core/data/vault/vault_key_service_test.dart
git commit -m "feat(vault): corrupt-meta state + destructive reset (Phase 4b)"
```

---

### Task B2: Secure-storage key cache

**Files:**
- Create: `lib/core/data/vault/vault_key_cache.dart`
- Modify: `lib/core/data/vault/vault_key_service.dart` (accept a cache, use it)
- Modify: `lib/core/data/attachments/attachment_providers.dart` (`vaultKeyCacheProvider`, pass into `vaultKeyServiceProvider`)
- Test: `test/core/data/vault/vault_key_cache_test.dart`, and add cache cases to `vault_key_service_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class VaultKeyCache { Future<Uint8List?> read(); Future<void> write(Uint8List key); Future<void> clear(); }`
  - `class SecureStorageVaultKeyCache implements VaultKeyCache` — `flutter_secure_storage`-backed (optional `FlutterSecureStorage` ctor param, mirrors `TokenStorage`).
  - `VaultKeyService` gains `VaultKeyCache? cache` ctor param; `unlockFromCache()`; caches on setup/unlock; `reset()` clears the cache.

- [ ] **Step 1: Write the failing tests**

`test/core/data/vault/vault_key_cache_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/vault_key_cache.dart';

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
  test('in-memory cache round-trips and clears', () async {
    final c = _MemCache();
    expect(await c.read(), isNull);
    await c.write(Uint8List.fromList([1, 2, 3]));
    expect(await c.read(), Uint8List.fromList([1, 2, 3]));
    await c.clear();
    expect(await c.read(), isNull);
  });
}
```

Add to `vault_key_service_test.dart` (define a `_MemCache` there too):

```dart
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
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/data/vault/vault_key_cache_test.dart test/core/data/vault/vault_key_service_test.dart`
Expected: FAIL — cache type + `cache` param + `unlockFromCache` missing.

- [ ] **Step 3: Implement the cache**

Create `lib/core/data/vault/vault_key_cache.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the derived vault key in the platform secure store so a biometric
/// unlock can restore it without re-deriving from the passphrase. The key is
/// never written anywhere else and never leaves the device.
abstract interface class VaultKeyCache {
  Future<Uint8List?> read();
  Future<void> write(Uint8List key);
  Future<void> clear();
}

class SecureStorageVaultKeyCache implements VaultKeyCache {
  SecureStorageVaultKeyCache([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _keyName = 'hmm_vault_key_b64';

  @override
  Future<Uint8List?> read() async {
    final v = await _storage.read(key: _keyName);
    if (v == null) return null;
    return base64Decode(v);
  }

  @override
  Future<void> write(Uint8List key) =>
      _storage.write(key: _keyName, value: base64Encode(key));

  @override
  Future<void> clear() => _storage.delete(key: _keyName);
}
```

- [ ] **Step 4: Wire the cache into `VaultKeyService`**

Add ctor param + field:

```dart
  VaultKeyService({
    required IVaultStore store,
    VaultCrypto crypto = const VaultCrypto(),
    Argon2Params params = Argon2Params.production,
    VaultKeyCache? cache,
  })  : _store = store,
        _crypto = crypto,
        _params = params,
        _cache = cache;

  final VaultKeyCache? _cache;
```

- In `setupPassphrase`, after `_key = key;` add `await _cache?.write(key);`.
- In `unlock`, on success change to `_key = key; await _cache?.write(key); return true;`.
- In `reset()`, add `await _cache?.clear();` alongside `_key = null;`.
- Add:

```dart
  /// Restore the key from the secure-storage cache without a passphrase.
  /// Returns true if a cached key was present and is now held.
  Future<bool> unlockFromCache() async {
    final cached = await _cache?.read();
    if (cached == null) return false;
    _key = cached;
    return true;
  }
```

In `attachment_providers.dart` add and wire:

```dart
final vaultKeyCacheProvider =
    Provider<VaultKeyCache>((ref) => SecureStorageVaultKeyCache());
```
and in `vaultKeyServiceProvider`: `return VaultKeyService(store: base, cache: ref.watch(vaultKeyCacheProvider));`

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/core/data/vault/vault_key_cache_test.dart test/core/data/vault/vault_key_service_test.dart`
Expected: PASS. Then `flutter analyze`.

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/vault/vault_key_cache.dart lib/core/data/vault/vault_key_service.dart lib/core/data/attachments/attachment_providers.dart test/core/data/vault/vault_key_cache_test.dart test/core/data/vault/vault_key_service_test.dart
git commit -m "feat(vault): secure-storage key cache + unlockFromCache (Phase 4b)"
```

---

### Task B3: `local_auth` biometric gate + `vaultSessionProvider`

**Files:**
- Modify: `pubspec.yaml` (add `local_auth`)
- Create: `lib/core/data/vault/biometric_gate.dart`
- Create: `lib/core/data/vault/vault_session.dart`
- Modify: `lib/core/data/attachments/attachment_providers.dart` (a synchronous `vaultKeyServiceSyncProvider` for the session, or an init that awaits once — see note)
- Test: `test/core/data/vault/vault_session_test.dart`

**Interfaces:**
- `abstract interface class BiometricGate { Future<bool> authenticate(); }` + `LocalAuthBiometricGate` + `biometricGateProvider`.
- `enum VaultStatus { absent, locked, unlocked, corrupt }`
- `class VaultSessionController extends Notifier<VaultStatus>` with: `Future<void> refresh()`, `Future<bool> unlockWithBiometric()`, `Future<bool> unlockWithPassphrase(String)`, `Future<void> setup(String)`, `void lockNow()`, `Future<void> reset()`, `void touch()`; relocks on background/inactivity. `vaultSessionProvider = NotifierProvider<VaultSessionController, VaultStatus>`.

- [ ] **Step 1: Add the dependency**

`pubspec.yaml` dependencies: `  local_auth: ^2.3.0   # biometric/passcode gate for the sensitive vault (Phase 4b)`
Run: `flutter pub get` (report BLOCKED if it fails to resolve — don't substitute).

- [ ] **Step 2: Write the failing test**

```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/biometric_gate.dart';
import 'package:hmm_console/core/data/vault/crypto/vault_crypto.dart';
import 'package:hmm_console/core/data/vault/vault_key_cache.dart';
import 'package:hmm_console/core/data/vault/vault_key_service.dart';
import 'package:hmm_console/core/data/vault/vault_session.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';

// _FakeVaultStore + _MemCache inline (as in earlier tasks).

class _FakeGate implements BiometricGate {
  _FakeGate(this.result);
  bool result;
  int calls = 0;
  @override
  Future<bool> authenticate() async { calls++; return result; }
}

void main() {
  ProviderContainer containerWith(VaultKeyService svc, BiometricGate gate) =>
      ProviderContainer(overrides: [
        vaultSessionServiceProvider.overrideWithValue(svc),
        biometricGateProvider.overrideWithValue(gate),
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
}
```

> The test injects the service via `vaultSessionServiceProvider` (a synchronous `Provider<VaultKeyService>` the session controller reads) and the gate via `biometricGateProvider`. Define `vaultSessionServiceProvider` in `vault_session.dart`; in production it resolves from the async `vaultKeyServiceProvider` — since the session controller's methods are already async, the controller may `await ref.read(vaultKeyServiceProvider.future)` internally instead, in which case drop `vaultSessionServiceProvider` and have the test override `vaultKeyServiceProvider` with `overrideWith((ref) async => svc)`. Pick one wiring; keep the status-transition contract above identical.

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/core/data/vault/vault_session_test.dart`
Expected: FAIL — symbols missing.

- [ ] **Step 4: Implement `BiometricGate`**

Create `lib/core/data/vault/biometric_gate.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Thin, fakeable wrapper over local_auth. authenticate() returns true only on
/// a successful biometric/passcode check; any failure/unavailability → false.
abstract interface class BiometricGate {
  Future<bool> authenticate();
}

class LocalAuthBiometricGate implements BiometricGate {
  LocalAuthBiometricGate([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock your secure vault',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false; // unavailable / not enrolled / cancelled → not authenticated
    }
  }
}

final biometricGateProvider =
    Provider<BiometricGate>((ref) => LocalAuthBiometricGate());
```

- [ ] **Step 5: Implement `vault_session.dart`**

Create `lib/core/data/vault/vault_session.dart` with `VaultStatus`, the controller (mapping `VaultConfigState` → status, orchestrating unlock, relocking via a `WidgetsBindingObserver` on `AppLifecycleState.paused` and an inactivity check against `lastAccessAt`), and `vaultSessionProvider`. Core logic:

```dart
enum VaultStatus { absent, locked, unlocked, corrupt }

// inside VaultSessionController extends Notifier<VaultStatus>:
Future<void> refresh() async {
  final cfg = await _svc.configState();
  state = switch (cfg) {
    VaultConfigState.absent => VaultStatus.absent,
    VaultConfigState.corrupt => VaultStatus.corrupt,
    VaultConfigState.configured =>
        _svc.isUnlocked ? VaultStatus.unlocked : VaultStatus.locked,
  };
}

Future<bool> unlockWithBiometric() async {
  if (!await _gate.authenticate()) return false;
  if (!await _svc.unlockFromCache()) return false;
  _touchNow();
  state = VaultStatus.unlocked;
  return true;
}

Future<bool> unlockWithPassphrase(String p) async {
  if (!await _svc.unlock(p)) return false;
  _touchNow();
  state = VaultStatus.unlocked;
  return true;
}

Future<void> setup(String p) async {
  await _svc.setupPassphrase(p);
  _touchNow();
  state = VaultStatus.unlocked;
}

void lockNow() { _svc.lock(); state = VaultStatus.locked; }
Future<void> reset() async { await _svc.reset(); state = VaultStatus.absent; }

void touch() {
  if (state != VaultStatus.unlocked) return;
  if (_now().difference(_lastAccessAt) > const Duration(minutes: 5)) {
    lockNow();
  } else {
    _touchNow();
  }
}
```

Register a `WidgetsBindingObserver` in `build()` (via `ref.onDispose` to remove it) whose `didChangeAppLifecycleState(paused)` calls `lockNow()` when unlocked. For the clock, prefer the repo's existing date/time provider under `lib/core/services/` if present; otherwise a private `DateTime Function()` field defaulting to `DateTime.now` (overridable in tests).

- [ ] **Step 6: Run to verify it passes**

Run: `flutter test test/core/data/vault/vault_session_test.dart`
Expected: PASS. Then `flutter analyze`.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/data/vault/biometric_gate.dart lib/core/data/vault/vault_session.dart lib/core/data/attachments/attachment_providers.dart test/core/data/vault/vault_session_test.dart
git commit -m "feat(vault): local_auth gate + vaultSessionProvider timed session (Phase 4b)"
```

---

### Task B4: Settings "Secure Vault" section

**Files:**
- Create: `lib/features/settings/presentation/widgets/secure_vault_section.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart` (insert after the quick-panel block, ~L475, before the DB-path block ~L476; gate `if (dataMode != DataMode.cloudApi)`)
- Test: `test/features/settings/secure_vault_section_test.dart`

**Interfaces:**
- Consumes: `vaultSessionProvider` + controller methods.
- Produces: `class SecureVaultSection extends ConsumerWidget` rendering rows per `VaultStatus`.

**Behavior (mirror the existing `SwitchListTile.adaptive`/`ListTile` idiom at settings_screen.dart:450-475):**
- `absent`: `ListTile` **"Set up Secure Vault"** → dialog with a passphrase field + a confirm field + the warning "If you forget this passphrase, these files cannot be recovered." → `controller.setup(passphrase)` (only when both fields match and are non-empty).
- `locked`: `ListTile` **"Secure Vault — locked"** + an **"Unlock"** action → `unlockWithBiometric()`; on false, show a passphrase dialog → `unlockWithPassphrase`.
- `unlocked`: `ListTile` **"Secure Vault — on"** + **"Lock now"** → `lockNow()`.
- `corrupt`: a warning `ListTile` + **"Reset Secure Vault"** → typed-confirmation dialog (user types `RESET`) → `reset()`.
- Configured states also expose **"Reset Secure Vault"** (same destructive dialog) as the forgotten-passphrase escape hatch.

- [ ] **Step 1: Write the failing widget tests**

Cover: each `VaultStatus` renders its expected primary text (pump with `vaultSessionProvider` overridden to each status); the setup dialog shows the recovery warning; the reset dialog keeps its destructive button disabled until the confirmation token is typed. Use `ProviderScope` overrides; do NOT fake `WidgetRef`.

```dart
testWidgets('absent shows Set up Secure Vault', (t) async {
  await t.pumpWidget(_host(VaultStatus.absent));
  expect(find.text('Set up Secure Vault'), findsOneWidget);
});
// locked / unlocked / corrupt equivalents + dialog-content assertions.
```

- [ ] **Step 2: Run to verify they fail.** `flutter test test/features/settings/secure_vault_section_test.dart` → FAIL (widget doesn't exist).
- [ ] **Step 3: Implement** `SecureVaultSection` (a `switch (ref.watch(vaultSessionProvider))` building the rows above, with the dialogs), then insert `if (dataMode != DataMode.cloudApi) const SecureVaultSection()` at settings_screen.dart ~L475 with a preceding `GapWidgets.h24` + `Divider` + section header, matching neighbouring sections.
- [ ] **Step 4: Run to green + `flutter analyze`.**
- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/widgets/secure_vault_section.dart lib/features/settings/presentation/screens/settings_screen.dart test/features/settings/secure_vault_section_test.dart
git commit -m "feat(settings): Secure Vault section (setup/unlock/lock/reset) (Phase 4b)"
```

---

### Task B5: Mark-as-sensitive (add-time)

**Files:**
- Modify: `lib/core/data/attachments/picker/image_byte_source.dart` (`PickedImageBytes` gains `bool sensitive` + `copyWith`)
- Modify: `lib/core/data/attachments/picker/image_attachment_picker.dart` (`persistToVault(..., bool sensitive = false)` → sensitive path + `VaultRef.sensitive: true`)
- Modify: `lib/features/notes/states/mutate_note_state.dart` (`persistInlineImage` passes `pick.sensitive`)
- Modify: `lib/features/notes/presentation/widgets/media_toolbar.dart` (add an "Add sensitive image" action) + `note_editor_screen.dart` (`_addSensitiveMedia` + save-lock guard)
- Test: picker unit test + a note-editor test for the save-time-lock retry.

**Key changes:**
- `PickedImageBytes`: add `final bool sensitive;` (default false) + a `copyWith({bool? sensitive})`.
- `persistToVault({required int noteId, required Uint8List bytes, required String originalName, required String contentTypeHint, bool sensitive = false})`: when `sensitive`, build the path via `buildSensitiveAttachmentPath(noteId: noteId, ext: ext)` (from `sensitive_path.dart`) instead of the normal join, and return `VaultRef(..., sensitive: true)`; non-sensitive path unchanged.
- `persistInlineImage(noteId, pick)` → `picker.persistToVault(..., sensitive: pick.sensitive)`.
- Editor `_addSensitiveMedia(AttachmentPickSource source)`: read `ref.read(vaultSessionProvider)`; if not `unlocked`, drive the unlock/setup flow (reuse B4 affordances) and abort if still not unlocked; else `pick`, then `_inline.stageAndInsert(_bodyCtrl, pick.copyWith(sensitive: true))`. Wire a new `onPickSensitive` callback into `MediaToolbar` (or extend `AttachmentPickSource` — prefer a separate callback to keep source semantics).

**Save-time lock safety (binding constraint):** `InlineImageController.resolveAndRewrite`'s `persist` swallows exceptions into "failed" and strips the placeholder. A `VaultLockedException` on a sensitive persist must NOT strip the image. Handle in the editor's save path: **before** calling `resolveAndRewrite`, if any staged pick is sensitive and `vaultSessionProvider != unlocked`, run the unlock flow; if the user cancels, abort the save with a message rather than persisting (so `persist` never hits a locked store). Add a regression test: stage a sensitive pick, relock the session, trigger save → the unlock flow runs and the sensitive image is persisted (its placeholder rewritten to a real path), NOT stripped.

- [ ] **Step 1: Write the failing tests** — (a) `persistToVault(sensitive: true)` writes a `sensitive/`-segment path and returns `VaultRef.sensitive == true`; (b) `persistInlineImage` forwards `pick.sensitive`; (c) editor save with a sensitive staged pick after a relock unlocks first and does not strip the image.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** the field, the picker branch, the state forwarding, the toolbar action, and the save-path unlock guard.
- [ ] **Step 4: Run to green + `flutter analyze`.**
- [ ] **Step 5: Commit**

```bash
git add lib/core/data/attachments/picker/image_byte_source.dart lib/core/data/attachments/picker/image_attachment_picker.dart lib/features/notes/states/mutate_note_state.dart lib/features/notes/presentation/widgets/media_toolbar.dart lib/features/notes/presentation/screens/note_editor_screen.dart test/
git commit -m "feat(notes): mark-as-sensitive image add flow with unlock-at-save (Phase 4b)"
```

---

### Task B6: Blurred / lock previews

**Files:**
- Create: `lib/features/notes/presentation/widgets/sensitive_attachment_image.dart`
- Modify: `lib/features/notes/presentation/widgets/note_markdown_body.dart` (`_buildImage` `hmm-attachment://` branch) and `note_media_card_list.dart` (`_SavedImage`)
- Test: `test/features/notes/sensitive_attachment_image_test.dart`

**Interfaces:**
- `class SensitiveAttachmentImage extends ConsumerWidget` — props: `VaultRef ref`, `IAttachmentResolver resolver`, plus the same fit/alignment/semanticLabel as `AttachmentImage`. Watches `vaultSessionProvider`:
  - `unlocked` → renders `AttachmentImage` (decrypts transparently); a resolver-null / `VaultStoreException` → existing broken-image (missing).
  - not unlocked, or resolve throws `VaultLockedException` → a blurred + lock-icon placeholder (`Key('sensitiveLockedPlaceholder')`); tapping it runs the unlock flow (`unlockWithBiometric`, fallback passphrase dialog) then rebuilds.

**Wiring (sensitivity from the path, since the inline URI carries only the path):**
- `note_markdown_body.dart:_buildImage` `hmm-attachment://` branch: `if (isSensitiveVaultPath(path)) → SensitiveAttachmentImage(...)` else the current `AttachmentImage(...)`. (Build the `VaultRef` with `sensitive: isSensitiveVaultPath(path)` for consistency.)
- `note_media_card_list.dart:_SavedImage`: `if (ref.sensitive || isSensitiveVaultPath(ref.path)) → SensitiveAttachmentImage` else `AttachmentImage`.

- [ ] **Step 1: Write the failing tests** — locked sensitive ref → `sensitiveLockedPlaceholder` (not broken-image); after `vaultSessionProvider` overridden to `unlocked` → image renders; missing sensitive bytes while unlocked → broken-image (distinct); non-sensitive ref path → plain `AttachmentImage` (unchanged). Fake resolver + overridden `vaultSessionProvider`.
- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** the widget + both wiring sites.
- [ ] **Step 4: Run to green + `flutter analyze`.**
- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/widgets/sensitive_attachment_image.dart lib/features/notes/presentation/widgets/note_markdown_body.dart lib/features/notes/presentation/widgets/note_media_card_list.dart test/features/notes/sensitive_attachment_image_test.dart
git commit -m "feat(notes): blurred/lock previews for sensitive images (Phase 4b)"
```

---

### Task B7: AI-exclusion gate

**Files:**
- Modify: `lib/features/receipt_scan/domain/receipt_draft.dart` (`ReceiptInput` gains `bool sensitive`)
- Modify: `lib/features/receipt_scan/data/api_llm_extractor.dart` (reject sensitive input)
- Test: `test/features/receipt_scan/api_llm_extractor_sensitive_test.dart`

**Interfaces:**
- `ReceiptInput({required this.bytes, required this.contentType, this.sensitive = false})` + `final bool sensitive;` (keep `isPdf`).
- `ApiLlmExtractor.extract`: at the very top, before building the multipart form / any network call:
  `if (input.sensitive) { throw const ReceiptExtractionException('Sensitive attachments are never sent to cloud AI.'); }`

- [ ] **Step 1: Write the failing test**

```dart
test('sensitive input is rejected before any upload', () async {
  var posted = false;
  // Build an ApiLlmExtractor whose ApiClient.dio.post flips `posted = true`
  // (e.g. a Dio with a MockAdapter, or a fake ApiClient). Then:
  final extractor = ApiLlmExtractor(fakeClient);
  await expectLater(
    extractor.extract(ReceiptInput(
        bytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
        sensitive: true)),
    throwsA(isA<ReceiptExtractionException>()),
  );
  expect(posted, isFalse, reason: 'must not reach the network');
});
```

- [ ] **Step 2: Run red.**
- [ ] **Step 3: Implement** the field (default false → existing extractor tests + all call sites stay green) + the early guard.
- [ ] **Step 4: Run to green + `flutter analyze`.**
- [ ] **Step 5: Full suite** — `flutter test` (all green).
- [ ] **Step 6: Commit**

```bash
git add lib/features/receipt_scan/domain/receipt_draft.dart lib/features/receipt_scan/data/api_llm_extractor.dart test/features/receipt_scan/api_llm_extractor_sensitive_test.dart
git commit -m "feat(receipt-scan): exclude sensitive attachments from cloud AI (Phase 4b)"
```

---

## Self-Review (author checklist — completed)

- **Design coverage:** B1 corrupt+reset (the must-fix); B2 cache; B3 gate+session; B4 Settings; B5 mark add-time; B6 previews; B7 AI gate. ✓
- **Must-fix honored:** B1 distinguishes corrupt from absent, `setupPassphrase` refuses over corrupt (test proves bytes untouched), no naive catch→null. ✓
- **Save-time-lock hazard** called out in B5 with a regression test (sensitive image not silently stripped on relock). ✓
- **Platform channels injected/fakeable** (`VaultKeyCache`, `BiometricGate`) → headless tests. ✓
- **Type consistency:** `VaultConfigState`, `VaultStatus`, `VaultKeyCache`, `BiometricGate`, `vaultSessionProvider`, `PickedImageBytes.sensitive`, `persistToVault(sensitive:)`, `SensitiveAttachmentImage`, `ReceiptInput.sensitive` consistent across tasks. ✓
- **cloudApi untouched.** ✓

## Notes for the executor (widget-heavy tasks)

B4–B6 wire into existing widgets; the plan gives exact files, insertion points (line numbers from the current tree), and the new logic. Implementers follow the surrounding patterns (the `SwitchListTile.adaptive`/`ListTile` idiom at `settings_screen.dart:450-475`; the `AttachmentImage`/`FutureBuilder` idiom; the `_buildImage` scheme dispatch at `note_markdown_body.dart`). Where the current tree differs from these notes, follow the tree and preserve behavior — flag as DONE_WITH_CONCERNS if a pattern can't be matched cleanly.

## Execution Handoff

Plan complete. Recommended: **superpowers:subagent-driven-development** — B1/B2/B3/B7 headless (standard model); B4/B5/B6 widget/integration (standard model, careful review). B5's save-time-lock retry and B1's corrupt-refuse are the highest-risk items — review them hardest.
