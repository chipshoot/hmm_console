# Sensitive Attachments — Phase 4a (Crypto Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encrypt sensitive attachment bytes at rest (AES-256-GCM under a passphrase-derived Argon2id key) with a headless, fully-testable foundation — no UI, no biometrics yet.

**Architecture:** A `sensitive` flag rides on `VaultRef`; sensitivity is detected in the storage layer purely by a `sensitive/` path segment. An `EncryptedVaultStore` decorator wraps the tier's base `IVaultStore` and transparently encrypts/decrypts only sensitive paths, reading the session key from an in-memory `VaultKeyService`. Non-secret key material (salt, Argon2 params, a key-verifier) lives in a synced `vault_meta.json`. All callers keep taking a plain `IVaultStore`.

**Tech Stack:** Dart/Flutter, Riverpod 3.0.3, Drift, the `cryptography` package (AES-256-GCM + Argon2id), the existing vault/attachment layer.

**Parent design:** `docs/superpowers/specs/2026-07-16-sensitive-attachments-phase4-design.md` (§Sub-phase 4a).

## Global Constraints

- **Riverpod 3.0.3:** read async provider values with `.value ?? <default>` — **never** `.valueOrNull` (undefined in this version). No widgets in 4a.
- **Back-compat is mandatory:** the `sensitive` field is emitted **only when true**; existing images-only attachment JSON must stay byte-identical (mirror the existing `files`-when-empty omission).
- **No `cloudApi` behavior change:** the `cloudApi` branch of `vaultStoreProvider` returns the `ApiVaultStore` unencrypted, exactly as today (encryption there is Phase 5).
- **Crypto framing is fixed:** AES-256-GCM, `nonce(12) ‖ ciphertext ‖ tag(16)`; 32-byte key. Argon2id with params echoed into `vault_meta` so any device re-derives identically. A bad key/tag throws `VaultCryptoException` — never returns garbage bytes.
- **Scope refinement vs design §4a.5:** the derived key is held **in memory only** in 4a. Caching it in `flutter_secure_storage` is moved to **4b**, where the `local_auth` biometric gate gives the cache a purpose — a cached key with no gate would be a liability with no benefit. So 4a has **no secure-storage and no platform-channel dependency**, and every test runs headless with injected fakes.
- **Tests must not touch real platform channels** (`path_provider`, `flutter_secure_storage`, `local_auth`): inject in-memory fakes / temp values.
- `flutter analyze` clean after every task. Commit trailer on every commit:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

## File Structure

- `lib/core/data/attachments/attachment_ref.dart` — add `sensitive` to `VaultRef` (Task 1).
- `lib/core/data/attachments/attachment_ref_codec.dart` — encode/decode `sensitive` (Task 1).
- `lib/core/data/vault/sensitive_path.dart` — **new**: `isSensitiveVaultPath` + `buildSensitiveAttachmentPath` (Task 2). Kept separate from `vault_path.dart` so the cross-repo-mirrored file is untouched.
- `pubspec.yaml` — add `cryptography` (Task 3).
- `lib/core/data/vault/crypto/vault_crypto.dart` — **new**: `VaultCrypto`, `Argon2Params`, `VaultCryptoException` (Task 3).
- `lib/core/data/vault/vault_meta.dart` — **new**: `VaultMeta` + `VaultMetaCodec` + `vaultMetaPath` (Task 4).
- `lib/core/data/vault/vault_key_service.dart` — **new**: `VaultKeyService` (Task 5).
- `lib/core/data/vault/encrypted_vault_store.dart` — **new**: `EncryptedVaultStore` + `VaultLockedException` (Task 6).
- `lib/core/data/attachments/attachment_providers.dart` — wire `baseVaultStoreProvider` / `vaultKeyServiceProvider` / `vaultStoreProvider` (Task 7).
- Tests mirror each under `test/core/data/...`.

---

### Task 1: `sensitive` flag on `VaultRef` + codec

**Files:**
- Modify: `lib/core/data/attachments/attachment_ref.dart` (the `VaultRef` class)
- Modify: `lib/core/data/attachments/attachment_ref_codec.dart` (`_vaultFromJson`, `_vaultToJson`)
- Test: `test/core/data/attachments/attachment_ref_codec_test.dart` (existing file — add cases; if absent, create)

**Interfaces:**
- Consumes: existing `VaultRef`, `AttachmentRefCodec`.
- Produces: `VaultRef({..., bool sensitive = false})`; codec emits `'sensitive': true` only when true, reads optional bool `sensitive` (absent ⇒ false).

- [ ] **Step 1: Write the failing test**

Add to `test/core/data/attachments/attachment_ref_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';

void main() {
  group('VaultRef.sensitive', () {
    test('defaults to false and is omitted from JSON', () {
      const ref = VaultRef(
        path: 'attachments/note-1/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 10,
      );
      expect(ref.sensitive, isFalse);
      final json = AttachmentRefCodec.toJson(ref);
      expect(json.containsKey('sensitive'), isFalse,
          reason: 'legacy payloads must stay byte-identical');
    });

    test('sensitive: true round-trips and is emitted', () {
      const ref = VaultRef(
        path: 'attachments/note-1/sensitive/a.jpg',
        contentType: 'image/jpeg',
        byteSize: 10,
        sensitive: true,
      );
      final json = AttachmentRefCodec.toJson(ref);
      expect(json['sensitive'], isTrue);
      final back = AttachmentRefCodec.fromJson(json);
      expect(back, ref);
      expect((back as VaultRef).sensitive, isTrue);
    });

    test('absent sensitive decodes to false', () {
      final ref = AttachmentRefCodec.fromJson({
        'kind': 'vault',
        'path': 'attachments/note-1/a.jpg',
        'contentType': 'image/jpeg',
        'byteSize': 10,
      });
      expect((ref as VaultRef).sensitive, isFalse);
    });

    test('non-bool sensitive throws FormatException', () {
      expect(
        () => AttachmentRefCodec.fromJson({
          'kind': 'vault',
          'path': 'attachments/note-1/a.jpg',
          'contentType': 'image/jpeg',
          'byteSize': 10,
          'sensitive': 'yes',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/data/attachments/attachment_ref_codec_test.dart`
Expected: FAIL — `VaultRef` has no `sensitive` parameter.

- [ ] **Step 3: Implement — add the field to `VaultRef`**

In `attachment_ref.dart`, update `VaultRef` (add the field, constructor param, and include it in `==`/`hashCode`/`toString`):

```dart
final class VaultRef extends AttachmentRef {
  const VaultRef({
    required this.path,
    this.originalName,
    required this.contentType,
    required this.byteSize,
    this.sensitive = false,
  });

  final String path;
  final String? originalName;
  final String contentType;
  final int byteSize;

  /// Encrypted-at-rest, view-gated, AI-excluded when true. Default false;
  /// absent in JSON means false (back-compat).
  final bool sensitive;

  @override
  String get kind => 'vault';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultRef &&
          other.path == path &&
          other.originalName == originalName &&
          other.contentType == contentType &&
          other.byteSize == byteSize &&
          other.sensitive == sensitive;

  @override
  int get hashCode =>
      Object.hash(path, originalName, contentType, byteSize, sensitive);

  @override
  String toString() =>
      'VaultRef(path: $path, contentType: $contentType, '
      'byteSize: $byteSize, sensitive: $sensitive)';
}
```

- [ ] **Step 4: Implement — codec**

In `attachment_ref_codec.dart`, add an optional-bool reader and use it. Add near the other `_optional*` helpers:

```dart
bool _optionalBool(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return false;
  if (v is! bool) {
    throw FormatException('"$key" must be a bool when present');
  }
  return v;
}
```

In `_vaultFromJson`, pass `sensitive`:

```dart
    return VaultRef(
      path: path,
      originalName:
          _optionalString(j, 'originalName', maxLength: _maxOriginalNameLength),
      contentType: _validateContentType(_requireString(j, 'contentType')),
      byteSize: _requireByteSize(j),
      sensitive: _optionalBool(j, 'sensitive'),
    );
```

In `_vaultToJson`, emit only when true:

```dart
  static Map<String, dynamic> _vaultToJson(VaultRef r) => {
        'kind': 'vault',
        'path': r.path,
        if (r.originalName != null) 'originalName': r.originalName,
        'contentType': r.contentType,
        'byteSize': r.byteSize,
        if (r.sensitive) 'sensitive': true,
      };
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/core/data/attachments/attachment_ref_codec_test.dart`
Expected: PASS. Then `flutter analyze` (clean).

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/attachments/attachment_ref.dart lib/core/data/attachments/attachment_ref_codec.dart test/core/data/attachments/attachment_ref_codec_test.dart
git commit -m "feat(vault): add sensitive flag to VaultRef + codec (Phase 4a)"
```

---

### Task 2: Sensitive path convention

**Files:**
- Create: `lib/core/data/vault/sensitive_path.dart`
- Test: `test/core/data/vault/sensitive_path_test.dart`

**Interfaces:**
- Consumes: `vaultRelativePathJoin` from `vault_path.dart`; `generateUuid` from `lib/core/util/uuid.dart`.
- Produces:
  - `bool isSensitiveVaultPath(String path)` — true iff any `/`-segment equals `sensitive`.
  - `String buildSensitiveAttachmentPath({required int noteId, required String ext})` — `attachments/note-<id>/sensitive/<uuid>.<ext>`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/sensitive_path.dart';

void main() {
  group('isSensitiveVaultPath', () {
    test('true when a segment is "sensitive"', () {
      expect(isSensitiveVaultPath('attachments/note-1/sensitive/a.jpg'), isTrue);
    });
    test('false for a normal attachment path', () {
      expect(isSensitiveVaultPath('attachments/note-1/a.jpg'), isFalse);
    });
    test('false when "sensitive" is only a substring of a segment', () {
      expect(isSensitiveVaultPath('attachments/note-1/sensitiveish.jpg'), isFalse);
    });
    test('false for vault_meta.json', () {
      expect(isSensitiveVaultPath('vault_meta.json'), isFalse);
    });
  });

  group('buildSensitiveAttachmentPath', () {
    test('produces a validated sensitive path', () {
      final path = buildSensitiveAttachmentPath(noteId: 7, ext: 'jpg');
      expect(path, startsWith('attachments/note-7/sensitive/'));
      expect(path, endsWith('.jpg'));
      expect(isSensitiveVaultPath(path), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/data/vault/sensitive_path_test.dart`
Expected: FAIL — file/functions don't exist.

- [ ] **Step 3: Implement**

Create `lib/core/data/vault/sensitive_path.dart`:

```dart
// Sensitive-attachment path convention. Sensitivity is carried by a
// dedicated `sensitive` path segment so the storage layer can decide
// to encrypt/decrypt from the path alone — IVaultStore signatures and
// callers stay unchanged. Kept out of vault_path.dart (which mirrors a
// .NET spec) so that cross-repo file is untouched.

import '../../util/uuid.dart';
import 'vault_path.dart';

/// The reserved path segment that marks an attachment as sensitive.
const String sensitiveSegment = 'sensitive';

/// True iff any POSIX segment of [path] equals [sensitiveSegment].
bool isSensitiveVaultPath(String path) => path.split('/').contains(sensitiveSegment);

/// Build a validated vault path for a sensitive attachment:
/// `attachments/note-<noteId>/sensitive/<uuid>.<ext>`.
String buildSensitiveAttachmentPath({required int noteId, required String ext}) {
  return vaultRelativePathJoin([
    'attachments',
    'note-$noteId',
    sensitiveSegment,
    '${generateUuid()}.$ext',
  ]);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/data/vault/sensitive_path_test.dart`
Expected: PASS. Then `flutter analyze` (clean).

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/vault/sensitive_path.dart test/core/data/vault/sensitive_path_test.dart
git commit -m "feat(vault): sensitive-attachment path convention (Phase 4a)"
```

---

### Task 3: `VaultCrypto` — AES-256-GCM + Argon2id (+ dependency)

**Files:**
- Modify: `pubspec.yaml` (add `cryptography`)
- Create: `lib/core/data/vault/crypto/vault_crypto.dart`
- Test: `test/core/data/vault/crypto/vault_crypto_test.dart`

**Interfaces:**
- Produces:
  - `class Argon2Params` with `memory/iterations/parallelism/hashLength`, `toJson`/`fromJson`, `static const production` and `static const test`.
  - `class VaultCryptoException implements Exception` (message).
  - `class VaultCrypto` (const) with:
    - `Future<Uint8List> encrypt(Uint8List plaintext, Uint8List key)`
    - `Future<Uint8List> decrypt(Uint8List framed, Uint8List key)` (throws `VaultCryptoException` on any failure)
    - `Future<Uint8List> deriveKey(String passphrase, Uint8List salt, Argon2Params params)`
    - `Uint8List newSalt([int length = 16])`

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml` under `dependencies:` add:

```yaml
  cryptography: ^2.7.0   # AES-256-GCM + Argon2id for the sensitive vault (Phase 4a)
```

Run: `flutter pub get`
Expected: resolves successfully. (If resolution fails, report BLOCKED with the resolver output — do not substitute a different package without approval.)

- [ ] **Step 2: Write the failing test**

```dart
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/core/data/vault/crypto/vault_crypto_test.dart`
Expected: FAIL — file/symbols don't exist.

- [ ] **Step 4: Implement**

Create `lib/core/data/vault/crypto/vault_crypto.dart`:

```dart
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
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/core/data/vault/crypto/vault_crypto_test.dart`
Expected: PASS. Then `flutter analyze` (clean).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/data/vault/crypto/vault_crypto.dart test/core/data/vault/crypto/vault_crypto_test.dart
git commit -m "feat(vault): AES-256-GCM + Argon2id VaultCrypto primitives (Phase 4a)"
```

---

### Task 4: `vault_meta.json` model + codec

**Files:**
- Create: `lib/core/data/vault/vault_meta.dart`
- Test: `test/core/data/vault/vault_meta_test.dart`

**Interfaces:**
- Consumes: `Argon2Params` (Task 3).
- Produces:
  - `const String vaultMetaPath = 'vault_meta.json';`
  - `class VaultMeta { int version; Uint8List salt; Argon2Params params; Uint8List keyVerifier; }` with value `==`/`hashCode`.
  - `class VaultMetaCodec { static String encode(VaultMeta); static VaultMeta decode(String); }` (`decode` throws `FormatException` on bad shape).

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/data/vault/vault_meta_test.dart`
Expected: FAIL — file/symbols don't exist.

- [ ] **Step 3: Implement**

Create `lib/core/data/vault/vault_meta.dart`:

```dart
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/data/vault/vault_meta_test.dart`
Expected: PASS. Then `flutter analyze` (clean).

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/vault/vault_meta.dart test/core/data/vault/vault_meta_test.dart
git commit -m "feat(vault): vault_meta.json model + codec (Phase 4a)"
```

---

### Task 5: `VaultKeyService`

**Files:**
- Create: `lib/core/data/vault/vault_key_service.dart`
- Test: `test/core/data/vault/vault_key_service_test.dart`

**Interfaces:**
- Consumes: `IVaultStore`, `VaultCrypto`, `Argon2Params`, `VaultMeta`/`VaultMetaCodec`/`vaultMetaPath`.
- Produces `class VaultKeyService`:
  - ctor `VaultKeyService({required IVaultStore store, VaultCrypto crypto = const VaultCrypto(), Argon2Params params = Argon2Params.production})`
  - `Uint8List? get currentKey`
  - `bool get isUnlocked`
  - `Future<bool> isConfigured()`
  - `Future<void> setupPassphrase(String passphrase)` (throws `StateError` if already configured)
  - `Future<bool> unlock(String passphrase)` (throws `StateError` if not configured)
  - `void lock()`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/data/vault/vault_key_service_test.dart`
Expected: FAIL — file/symbols don't exist.

- [ ] **Step 3: Implement**

Create `lib/core/data/vault/vault_key_service.dart`:

```dart
// Holds the derived vault key for the session (in memory only in 4a;
// secure-storage caching + biometric gating land in 4b). Reads/writes
// the non-secret vault_meta.json through the BASE (unencrypted) store.

import 'dart:convert';
import 'dart:typed_data';

import 'crypto/vault_crypto.dart';
import 'vault_meta.dart';
import 'vault_store.dart';

class VaultKeyService {
  VaultKeyService({
    required IVaultStore store,
    VaultCrypto crypto = const VaultCrypto(),
    Argon2Params params = Argon2Params.production,
  })  : _store = store,
        _crypto = crypto,
        _params = params;

  final IVaultStore _store;
  final VaultCrypto _crypto;
  final Argon2Params _params;

  /// Known plaintext encrypted under the key to prove correctness.
  static const String _sentinel = 'hmm-secure-vault-v1';

  Uint8List? _key;

  Uint8List? get currentKey => _key;
  bool get isUnlocked => _key != null;

  Future<VaultMeta?> _readMeta() async {
    try {
      final bytes = await _store.getBytes(vaultMetaPath);
      return VaultMetaCodec.decode(utf8.decode(bytes));
    } on VaultStoreException {
      return null; // not set up yet
    }
  }

  Future<bool> isConfigured() async => (await _readMeta()) != null;

  /// First-time setup. Throws [StateError] if the vault already exists
  /// (passphrase rotation is out of scope for this phase).
  Future<void> setupPassphrase(String passphrase) async {
    if (await isConfigured()) {
      throw StateError('vault already configured');
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
  }

  /// Derive from [passphrase] and verify against the stored verifier.
  /// Returns true and holds the key on success; false and holds nothing
  /// on a wrong passphrase. Throws [StateError] if not configured.
  Future<bool> unlock(String passphrase) async {
    final meta = await _readMeta();
    if (meta == null) throw StateError('vault not configured');
    final key = await _crypto.deriveKey(passphrase, meta.salt, meta.params);
    try {
      final clear = await _crypto.decrypt(meta.keyVerifier, key);
      if (utf8.decode(clear) != _sentinel) return false;
    } on VaultCryptoException {
      return false;
    }
    _key = key;
    return true;
  }

  void lock() {
    _key = null;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/data/vault/vault_key_service_test.dart`
Expected: PASS. Then `flutter analyze` (clean).

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/vault/vault_key_service.dart test/core/data/vault/vault_key_service_test.dart
git commit -m "feat(vault): in-memory VaultKeyService (setup/unlock/lock) (Phase 4a)"
```

---

### Task 6: `EncryptedVaultStore` decorator

**Files:**
- Create: `lib/core/data/vault/encrypted_vault_store.dart`
- Test: `test/core/data/vault/encrypted_vault_store_test.dart`

**Interfaces:**
- Consumes: `IVaultStore`, `VaultKeyService`, `VaultCrypto`, `isSensitiveVaultPath`, `buildSensitiveAttachmentPath`.
- Produces:
  - `class VaultLockedException implements Exception` (`relativePath`).
  - `class EncryptedVaultStore implements IVaultStore` — ctor `EncryptedVaultStore({required IVaultStore inner, required VaultKeyService keyService, VaultCrypto crypto = const VaultCrypto()})`.

Behavior: sensitive path ⇒ encrypt on `putBytes` / decrypt on `getBytes`, requiring an unlocked key (else `VaultLockedException`); `getBytes` reads the inner store **first** so a missing file surfaces as `VaultStoreException` (distinct from locked). Non-sensitive paths and `exists`/`delete`/`list` pass straight through.

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/data/vault/encrypted_vault_store_test.dart`
Expected: FAIL — file/symbols don't exist.

- [ ] **Step 3: Implement**

Create `lib/core/data/vault/encrypted_vault_store.dart`:

```dart
// Transparent encryption decorator over an IVaultStore. Encrypts only
// paths flagged sensitive by convention (a `sensitive/` segment); all
// other paths and the exists/delete/list operations pass straight
// through. Requires an unlocked VaultKeyService for sensitive I/O.

import 'dart:typed_data';

import 'crypto/vault_crypto.dart';
import 'sensitive_path.dart';
import 'vault_key_service.dart';
import 'vault_store.dart';

/// Thrown when a sensitive path is read/written while the vault key is
/// locked. Distinct from [VaultStoreException] (missing/IO) so callers
/// can show a "locked" affordance rather than a broken-file one.
class VaultLockedException implements Exception {
  const VaultLockedException(this.relativePath);
  final String relativePath;
  @override
  String toString() => 'VaultLockedException(path: $relativePath)';
}

class EncryptedVaultStore implements IVaultStore {
  EncryptedVaultStore({
    required IVaultStore inner,
    required VaultKeyService keyService,
    VaultCrypto crypto = const VaultCrypto(),
  })  : _inner = inner,
        _keys = keyService,
        _crypto = crypto;

  final IVaultStore _inner;
  final VaultKeyService _keys;
  final VaultCrypto _crypto;

  @override
  Future<void> putBytes(
    String relativePath,
    Uint8List bytes, {
    String? contentType,
  }) async {
    if (!isSensitiveVaultPath(relativePath)) {
      return _inner.putBytes(relativePath, bytes, contentType: contentType);
    }
    final key = _keys.currentKey;
    if (key == null) throw VaultLockedException(relativePath);
    final ciphertext = await _crypto.encrypt(bytes, key);
    return _inner.putBytes(relativePath, ciphertext, contentType: contentType);
  }

  @override
  Future<Uint8List> getBytes(String relativePath) async {
    // Read first so a genuinely-missing file surfaces as
    // VaultStoreException even for sensitive paths — that lets the UI
    // tell "missing" from "locked".
    final stored = await _inner.getBytes(relativePath);
    if (!isSensitiveVaultPath(relativePath)) return stored;
    final key = _keys.currentKey;
    if (key == null) throw VaultLockedException(relativePath);
    return _crypto.decrypt(stored, key);
  }

  @override
  Future<bool> exists(String relativePath) => _inner.exists(relativePath);

  @override
  Future<void> delete(String relativePath) => _inner.delete(relativePath);

  @override
  Future<List<VaultEntry>> list(String prefix) => _inner.list(prefix);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/data/vault/encrypted_vault_store_test.dart`
Expected: PASS. Then `flutter analyze` (clean).

- [ ] **Step 5: Commit**

```bash
git add lib/core/data/vault/encrypted_vault_store.dart test/core/data/vault/encrypted_vault_store_test.dart
git commit -m "feat(vault): EncryptedVaultStore decorator + VaultLockedException (Phase 4a)"
```

---

### Task 7: Wire the providers

**Files:**
- Modify: `lib/core/data/attachments/attachment_providers.dart`
- Test: `test/core/data/attachments/vault_store_provider_wiring_test.dart`

**Interfaces:**
- Consumes: `EncryptedVaultStore`, `VaultKeyService`, existing `dataModeProvider`, `apiVaultStoreProvider`, `vaultRootDirectoryProvider`, `LocalVaultStore`.
- Produces (new/updated providers):
  - `baseVaultStoreProvider` (`FutureProvider<IVaultStore>`) — the tier's **unencrypted** store (extracted from today's `vaultStoreProvider` body).
  - `vaultKeyServiceProvider` (`FutureProvider<VaultKeyService>`) — over the base store.
  - `vaultStoreProvider` (`FutureProvider<IVaultStore>`) — for `local`/`cloudStorage`, an `EncryptedVaultStore` over the base + key service; for `cloudApi`, the base (`ApiVaultStore`) unchanged.

**Design note for the implementer:** today's `vaultStoreProvider` body (the `FutureProvider<IVaultStore>` at ~lines 101–111) becomes `baseVaultStoreProvider`. `vaultStoreProvider` is rewritten to wrap it. Keep the doc comments. `baseVaultStoreProvider` is **public** so tests can override it with a fake store (avoids the `path_provider` channel).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/vault/encrypted_vault_store.dart';
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
  Future<List<VaultEntry>> list(String prefix) async => const [];
}

ProviderContainer _containerFor(DataMode mode, IVaultStore base) {
  return ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith((ref) => mode),
      baseVaultStoreProvider.overrideWith((ref) async => base),
    ],
  );
}

void main() {
  test('local mode yields an EncryptedVaultStore', () async {
    final c = _containerFor(DataMode.local, _FakeVaultStore());
    addTearDown(c.dispose);
    final store = await c.read(vaultStoreProvider.future);
    expect(store, isA<EncryptedVaultStore>());
  });

  test('cloudStorage mode yields an EncryptedVaultStore', () async {
    final c = _containerFor(DataMode.cloudStorage, _FakeVaultStore());
    addTearDown(c.dispose);
    final store = await c.read(vaultStoreProvider.future);
    expect(store, isA<EncryptedVaultStore>());
  });

  test('cloudApi mode yields the base store unchanged (no encryption)',
      () async {
    final base = _FakeVaultStore();
    final c = _containerFor(DataMode.cloudApi, base);
    addTearDown(c.dispose);
    final store = await c.read(vaultStoreProvider.future);
    expect(store, same(base));
    expect(store, isNot(isA<EncryptedVaultStore>()));
  });
}
```

> Note on `dataModeProvider.overrideWith`: match the existing override signature used elsewhere in the suite. If `dataModeProvider` is a `NotifierProvider`, override it the same way other tests in `test/` do (search for an existing `dataModeProvider.overrideWith`); adjust this test's override line to that shape. The behavior asserted (which store type each mode yields) is unchanged.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/data/attachments/vault_store_provider_wiring_test.dart`
Expected: FAIL — `baseVaultStoreProvider` doesn't exist; `vaultStoreProvider` returns a `LocalVaultStore`, not an `EncryptedVaultStore`.

- [ ] **Step 3: Implement**

In `attachment_providers.dart`, add imports:

```dart
import '../vault/encrypted_vault_store.dart';
import '../vault/vault_key_service.dart';
```

Replace the existing `vaultStoreProvider` (the `FutureProvider<IVaultStore>` at ~line 101) with the three providers below. Preserve the existing doc comment on the base provider:

```dart
/// Mode-aware **unencrypted** [IVaultStore]. Local + cloudStorage share
/// the filesystem-backed [LocalVaultStore] (only the root differs);
/// cloudApi swaps in [ApiVaultStore]. This is the base the encrypting
/// decorator and the key service both build on.
final baseVaultStoreProvider = FutureProvider<IVaultStore>((ref) async {
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.cloudApi) {
    return ref.watch(apiVaultStoreProvider);
  }
  final root = await ref.watch(vaultRootDirectoryProvider.future);
  return LocalVaultStore(rootDir: root);
});

/// Session key holder for sensitive attachments. Reads/writes the
/// non-secret vault_meta.json through the base (unencrypted) store.
final vaultKeyServiceProvider = FutureProvider<VaultKeyService>((ref) async {
  final base = await ref.watch(baseVaultStoreProvider.future);
  return VaultKeyService(store: base);
});

/// Mode-aware [IVaultStore] used by all callers. For local + cloudStorage
/// it wraps the base store in an [EncryptedVaultStore] so sensitive paths
/// are encrypted at rest; cloudApi returns the base store unchanged
/// (encryption there lands in Phase 5).
final vaultStoreProvider = FutureProvider<IVaultStore>((ref) async {
  final base = await ref.watch(baseVaultStoreProvider.future);
  final mode = ref.watch(dataModeProvider);
  if (mode == DataMode.cloudApi) {
    return base;
  }
  final keyService = await ref.watch(vaultKeyServiceProvider.future);
  return EncryptedVaultStore(inner: base, keyService: keyService);
});
```

(`attachmentResolverProvider` and `imageAttachmentPickerProvider` already
`ref.watch(vaultStoreProvider.future)` — they now transparently get the
encrypted store. No change needed there.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/data/attachments/vault_store_provider_wiring_test.dart`
Expected: PASS.

- [ ] **Step 5: Full suite + analyze**

Run: `flutter test` (expected: all green — no existing behavior changed for non-sensitive paths).
Run: `flutter analyze` (expected: clean).

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/attachments/attachment_providers.dart test/core/data/attachments/vault_store_provider_wiring_test.dart
git commit -m "feat(vault): wire EncryptedVaultStore into vaultStoreProvider (Phase 4a)"
```

---

## Self-Review (author checklist — completed)

- **Spec coverage (4a.1–4a.7):** flag+codec → T1; path convention → T2; crypto+dep → T3; vault_meta → T4; key service → T5; encrypted store → T6; provider wiring → T7. ✓
- **Scope refinement flagged:** secure-storage key cache deferred to 4b (Global Constraints) — 4a is in-memory + headless. ✓
- **Type consistency:** `Argon2Params`, `VaultCrypto`, `VaultMeta`/`vaultMetaPath`, `VaultKeyService.currentKey`, `EncryptedVaultStore`/`VaultLockedException`, `isSensitiveVaultPath`/`buildSensitiveAttachmentPath`, `baseVaultStoreProvider` used consistently across tasks. ✓
- **No placeholders:** every code step contains complete code. ✓
- **cloudApi untouched:** asserted by T7 test (`same(base)`). ✓
- **Back-compat:** `sensitive` omitted when false, asserted by T1. ✓

## Execution Handoff

Plan complete. Recommended: **superpowers:subagent-driven-development** — fresh implementer per task (T1–T2 cheap/mechanical; T3–T7 standard), task review after each, final whole-branch review. 4b follows as its own plan on top of this.
