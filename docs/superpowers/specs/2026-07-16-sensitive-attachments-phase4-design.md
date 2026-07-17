# Sensitive Attachments (Phase 4) — Design Spec

**Date:** 2026-07-16
**Status:** Approved (brainstorming) — ready for planning
**Parent:** `docs/superpowers/specs/2026-07-11-note-inline-refs-and-secure-attachments-design.md`
(this is **Phase 4 / §U7** of that umbrella; Phases 1–3 are shipped).

## Goal

Let a note attachment be marked **sensitive** (ID cards, health reports,
tickets): encrypted at rest with a passphrase-derived key, biometric-gated
before viewing, and never sent to cloud AI — while still syncing as opaque
ciphertext across devices. Note content stays plain-text Markdown; only the
attachment **bytes** are encrypted. Works in `local` + `cloudStorage` this
sprint; `cloudApi` is design-ready and deferred to Phase 5.

## Locked decisions (from brainstorming)

| Area | Decision |
|------|----------|
| Plan split | **4a foundation** (crypto/key/store, headless-testable, ships alone) then **4b UX** (gate, previews, setup, AI-exclusion). |
| Sensitivity detection in the store | **Path convention** — a `sensitive/` path segment; `EncryptedVaultStore` encrypts/decrypts iff `isSensitiveVaultPath(path)`. `IVaultStore` signature and all callers unchanged. |
| Metadata flag | Additive `bool sensitive` on `VaultRef` (default `false`; absent ⇒ false) — the signal for UI, previews, and the AI gate. Set at the same moment the sensitive path is chosen. |
| Unlock model | **Timed session** — one unlock stays valid until the app is backgrounded **or** ~5 min of inactivity, whichever first; then re-auth. |
| Setup entry | **Settings → "Secure Vault"** section (set passphrase + recovery warning + "Lock now"). Marking sensitive before setup routes here first. |
| Salt/params storage | **Synced `vault_meta.json`** at a fixed vault path (salt, Argon2 params, key-verifier hash) — rides the existing vault sync/reconcile path; self-contained with the ciphertext. |
| Crypto | **`cryptography` package** — AES-256-GCM + Argon2id (pure Dart; optional `cryptography_flutter` for native acceleration later). |
| Biometric gate | **`local_auth`** (biometric/passcode) protects *using* the cached key. |

## Non-goals (this phase)

- No `cloudApi` byte path or backend `NoteAttachments.schema.json` `sensitive`
  field — that lands with Phase 5 (cloudApi attachments). Design is
  cloudApi-ready (same decorator over `ApiVaultStore`).
- No passphrase **change/rotation** or re-encryption of existing sensitive
  bytes this phase (add-only: set once). Rotation is a follow-up.
- No server key escrow / recovery — forgetting the passphrase is
  unrecoverable (warned at setup). By decision.
- No sensitivity for the *note content text* — only attachment bytes.
- No native-accelerated crypto (`cryptography_flutter`) required to ship;
  pure-Dart is acceptable for the expected file counts.

---

## Sub-phase 4a — Crypto foundation

Everything here is headless-testable (no `local_auth`, no UI) and shippable on
its own. A caller with an unlocked key can round-trip sensitive bytes.

### 4a.1 — `sensitive` flag on `VaultRef` + codec

- Add `final bool sensitive;` to `VaultRef` (`attachment_ref.dart`), default
  `false`; include it in `==`/`hashCode`/`toString`.
- Codec (`attachment_ref_codec.dart`):
  - `_vaultToJson`: emit `if (r.sensitive) 'sensitive': true` — omitted when
    false so **existing images-only payloads stay byte-identical**
    (same discipline as the `files`-when-empty omission).
  - `_vaultFromJson`: read an optional bool `sensitive` (absent ⇒ false;
    present-and-not-bool ⇒ `FormatException`).
- Back-compat: every pre-Phase-4 `VaultRef` decodes with `sensitive: false`.
- Only `VaultRef` gains the flag (the only kind with vault bytes to encrypt);
  `PhAssetRef`/`CloudFileRef` are unaffected.

### 4a.2 — Sensitive path convention

**New:** extend `lib/core/data/vault/vault_path.dart` (or a sibling pure file).

- Sensitive bytes live at `attachments/note-{N}/sensitive/{file}` (the
  existing per-note prefix plus a `sensitive` segment).
- `bool isSensitiveVaultPath(String path)` — true iff any POSIX segment equals
  `sensitive`. Pure, no I/O.
- A path builder for sensitive attachments mirrors the existing non-sensitive
  builder, inserting the `sensitive` segment.
- The flag (4a.1) and the path are set together at creation; the store relies
  only on the path, the metadata only on the flag. They never disagree because
  one creation site sets both.

### 4a.3 — `VaultCrypto` primitives

**New:** `lib/core/data/vault/crypto/vault_crypto.dart`.

- Dependency: add **`cryptography`** to `pubspec.yaml`.
- `Future<Uint8List> encrypt(Uint8List plaintext, Uint8List key)` →
  AES-256-GCM with a fresh random 12-byte nonce; output framing
  `nonce (12) ‖ ciphertext ‖ tag (16)`.
- `Future<Uint8List> decrypt(Uint8List framed, Uint8List key)` → inverse;
  a bad tag / wrong key throws `VaultCryptoException` (never returns garbage).
- `Future<Uint8List> deriveKey(String passphrase, Argon2Params params)` →
  Argon2id → 32-byte key. Params fixed in code (memory/iterations/parallelism)
  and echoed into `vault_meta` so a new device re-derives identically.
- Deterministic for `(passphrase, salt, params)` — asserted by test.

### 4a.4 — `vault_meta.json` (synced, non-secret)

**New:** `lib/core/data/vault/vault_meta.dart` (model + codec) and read/write
through `IVaultStore` at a fixed path `vault_meta.json` (vault root).

- Fields: `version`, `salt` (base64), `argon2` params, `keyVerifier`
  (e.g. Argon2id/HMAC of a known constant under the derived key, or a stored
  GCM-encrypted sentinel) — all **non-secret**; the key itself is never here.
- `VaultMetaRepository` (or provider): `read()` → `VaultMeta?` (absent ⇒ vault
  not yet set up); `write(VaultMeta)`.
- Because it is a vault file, `_reconcileVault` replicates it via OneDrive like
  any attachment — a second device reads it, prompts for the passphrase, and
  re-derives the same key.

### 4a.5 — `VaultKeyService`

**New:** `lib/core/data/vault/vault_key_service.dart` + provider.

- Holds the derived key in memory for the session; caches it in
  `flutter_secure_storage` (Keychain/Keystore) keyed per vault.
- `Future<void> setupPassphrase(String passphrase)` — generate salt, derive
  key, write `vault_meta` (with verifier), cache key. First-time setup only
  (throws if `vault_meta` already exists — rotation is out of scope).
- `Future<bool> unlock(String passphrase)` — derive, verify against
  `vault_meta.keyVerifier`; on match cache + hold and return true; else false
  (no key retained).
- `void lock()` — drop the in-memory key (secure-storage cache handling per
  the session policy; the timed-session lifecycle wiring is 4b).
- `Uint8List? get currentKey` — null when locked.
- `bool get isConfigured` — `vault_meta` present.

### 4a.6 — `EncryptedVaultStore` decorator

**New:** `lib/core/data/vault/encrypted_vault_store.dart implements IVaultStore`.

- Wraps an inner `IVaultStore` + reads the current key from `VaultKeyService`.
- `putBytes(path, bytes)`:
  - `isSensitiveVaultPath(path)` ⇒ require `currentKey` (else
    `VaultLockedException`); `bytes = VaultCrypto.encrypt(bytes, key)`; delegate.
  - else delegate unchanged.
- `getBytes(path)`:
  - sensitive ⇒ delegate to inner; require `currentKey` (else
    `VaultLockedException`); `VaultCrypto.decrypt(framed, key)`; return plaintext.
  - else delegate unchanged.
- `exists`/`delete`/`list` — pure passthrough (they operate on opaque paths;
  encryption is transparent to them and to `vault_gc`).
- **New exception** `VaultLockedException` (distinct from `VaultStoreException`)
  so callers can tell *locked* from *missing/error*.

### 4a.7 — Wire `vaultStoreProvider`

- In `attachment_providers.dart`, wrap the `LocalVaultStore` in
  `EncryptedVaultStore(inner: local, keyService: …)` for `local` +
  `cloudStorage`. `cloudApi` branch untouched (Phase 5). Callers unchanged —
  they still get an `IVaultStore`.

---

## Sub-phase 4b — UX + gates

### 4b.1 — "Mark as sensitive"

- In the image/attachment add flow (picker/toolbar), a **"Mark as sensitive"**
  choice. When chosen: if `!keyService.isConfigured`, route to Secure Vault
  setup (4b.2) first; then write bytes to a **sensitive path** (4a.2) through
  the (encrypting) `vaultStoreProvider`, and record the `VaultRef` with
  `sensitive: true`.
- Applies to inline images and trailing-card images alike (both are `VaultRef`s
  in `attachments`).

### 4b.2 — Settings "Secure Vault" section

- New rows under the existing sync/data section of `settings_screen.dart`:
  - **Set up Secure Vault** (when unconfigured) → passphrase entry with an
    explicit **"If you forget this passphrase, these files cannot be
    recovered."** warning → `keyService.setupPassphrase`.
  - **Secure Vault: On** status + **Lock now** (when configured) →
    `keyService.lock()`.
  - **Unlock** entry point when locked (also reachable from a blurred preview).

### 4b.3 — `local_auth` gate + timed session

- Add **`local_auth`** dependency. Before handing the cached key to a viewer,
  require a biometric/passcode success (fallback to passphrase entry if
  biometrics unavailable/denied).
- **Timed session:** an unlock is valid until the app is backgrounded
  (`AppLifecycleState.paused`) **or** ~5 min since last sensitive access;
  crossing either relocks (`keyService.lock()`), so the next view re-auths.
  Implemented via a lifecycle observer + a last-access timestamp.

### 4b.4 — Blurred / lock previews

- A sensitive image widget (inline via the Markdown `imageBuilder`, and
  trailing via `NoteMediaCardList`) that:
  - locked (`currentKey == null` or `VaultLockedException`) ⇒ blurred +
    lock-icon placeholder; tap → `local_auth` → unlock → decrypt → show.
  - unlocked ⇒ decrypt + render normally (tap → fullscreen as today).
  - genuinely missing bytes ⇒ the existing broken-image placeholder (distinct
    from locked, via `VaultLockedException` vs null/`VaultStoreException`).
- Non-sensitive rendering path is unchanged.

### 4b.5 — AI-exclusion gate

- Carry a `bool sensitive` on the extractor input (`ReceiptInput`) — or gate at
  the extractor caller — and have `ApiLlmExtractor.extract` **reject** sensitive
  input with a clear message before any upload.
- **Scope note (honest):** the current receipt-scan flow extracts
  freshly-picked bytes, not stored note attachments, so no live code path feeds
  a `sensitive` attachment to cloud AI today. This gate is **defense-in-depth**
  and policy enforcement for any future caller that might pass a stored
  attachment to an extractor. On-device OCR is unaffected (never leaves device).

### 4b.6 — Setup-before-sensitive routing

- Any attempt to create/view sensitive content when unconfigured routes to
  4b.2 setup; when configured-but-locked routes to unlock. No dead ends.

---

## Three-tier behavior

| Tier | Sensitive bytes | Key | Status |
|------|-----------------|-----|--------|
| `local` | `EncryptedVaultStore` over `LocalVaultStore` (app docs) | on-device only | **Live** |
| `cloudStorage` (OneDrive) | same decorator; ciphertext + `vault_meta.json` replicated by OneDrive `_reconcileVault` | re-derived per device from synced salt | **Live** |
| `cloudApi` | same decorator over `ApiVaultStore`; backend schema `sensitive` field | on-device only | **Deferred (Phase 5)** |

## Error handling

- Sensitive `getBytes`/`putBytes` while locked ⇒ `VaultLockedException` →
  blurred placeholder + unlock prompt (never a crash, never plaintext leak).
- Wrong passphrase on a new device ⇒ `unlock` returns false (verifier mismatch)
  or `decrypt` throws `VaultCryptoException` → clear "wrong vault passphrase"
  message; no partial/garbage bytes shown.
- Auth cancelled ⇒ stays blurred/locked.
- `vault_meta.json` missing while sensitive bytes exist (corruption/partial
  sync) ⇒ treat as locked/unrecoverable with a clear message; never crash.
- Malformed/short ciphertext frame ⇒ `VaultCryptoException`; placeholder.
- Non-sensitive paths never touch crypto — zero behavior change.

## Security model

- **Crypto:** AES-256-GCM per file (random nonce + auth tag); key =
  Argon2id(passphrase, salt, fixed params). Salt + nonce + params are
  non-secret and travel with the ciphertext / `vault_meta`.
- **Key custody:** key exists only on the user's devices (secure storage +
  in-memory session); never sent to any server; no escrow → passphrase loss is
  unrecoverable (warned).
- **View gate:** `local_auth` + timed session limits exposure on a
  briefly-unlocked device. Does **not** defend a fully compromised unlocked
  device with the key resident.
- **AI boundary:** sensitive plaintext never leaves the device and is never
  sent to cloud AI (gate at extractor input).

## Dependencies to add

- **`cryptography`** — AES-256-GCM + Argon2id.
- **`local_auth`** — biometric/passcode gating (4b).
- Already present: `flutter_secure_storage` (^9.2.4).

## Testing

**4a.1 codec:** `sensitive: true` round-trips; omitted when false (byte-identical
to legacy); absent ⇒ false; non-bool ⇒ `FormatException`.
**4a.2 path:** `isSensitiveVaultPath` true only with a `sensitive` segment;
builder produces the expected path.
**4a.3 crypto:** encrypt→decrypt round-trips; wrong key ⇒ `VaultCryptoException`;
ciphertext ≠ plaintext; `deriveKey` deterministic for `(pass, salt, params)`.
**4a.4 meta:** `vault_meta` round-trips through the codec + through a fake
`IVaultStore`; absent ⇒ `isConfigured == false`.
**4a.5 key service:** `setupPassphrase` then `unlock` with the right passphrase
succeeds; wrong passphrase fails and retains no key; `lock` clears the key.
**4a.6 store:** sensitive `putBytes` writes ciphertext to the inner store
(inner bytes ≠ plaintext) and `getBytes` returns the original; non-sensitive
bypasses crypto (inner bytes == input); locked sensitive op ⇒
`VaultLockedException`.
**4a.7 wiring:** `vaultStoreProvider` returns an `EncryptedVaultStore` in
`local`/`cloudStorage`; `cloudApi` returns `ApiVaultStore` unchanged.
**4b.4 previews:** locked sensitive image ⇒ blurred/lock (not broken-image);
after unlock ⇒ renders; missing bytes ⇒ broken-image (distinct from locked).
**4b.5 AI gate:** a `sensitive` extractor input is rejected by `ApiLlmExtractor`
before upload; non-sensitive proceeds; on-device OCR unaffected.
**Cross-tier:** a note with a sensitive `VaultRef` round-trips through the sync
models preserving `sensitive: true`; encrypted bytes reconcile as opaque bytes.

## Phasing for the plan

1. **Plan 4a** (this first): 4a.1–4a.7. Shippable — sensitive bytes encrypt at
   rest and round-trip with an unlocked key; no UI yet beyond wiring.
2. **Plan 4b**: 4b.1–4b.6 on top of 4a. Adds the user-facing gate, previews,
   setup, and AI-exclusion.

Each sub-phase is independently testable and shippable.
