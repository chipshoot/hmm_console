# Sensitive Attachments (Phase 4b) — UX & Gate Design Spec

**Date:** 2026-07-18
**Status:** Approved (brainstorming) — ready for planning
**Parent:** `docs/superpowers/specs/2026-07-11-note-inline-refs-and-secure-attachments-design.md`
(umbrella §U7 / Phase 4). **Builds on Phase 4a** (shipped): `sensitive` flag on
`VaultRef`, `sensitive/` path convention + `isSensitiveVaultPath`, `VaultCrypto`
(AES-256-GCM + Argon2id), `vault_meta.json`, in-memory `VaultKeyService`,
`EncryptedVaultStore` wired into `vaultStoreProvider` for `local`/`cloudStorage`.

## Goal

Put the user-facing layer on top of 4a's crypto foundation: let a user set up a
Secure Vault, mark attachments sensitive at add-time, view them behind a
biometric/passphrase gate with blurred previews until unlocked, and keep
sensitive content out of cloud AI — all in `local` + `cloudStorage`. Also fix
the corrupt-`vault_meta` gap the 4a final review surfaced.

## Locked decisions (from brainstorming)

| Area | Decision |
|------|----------|
| Key persistence | **Secure-storage cache + biometric.** After setup, the derived key is cached in `flutter_secure_storage` (Keychain/Keystore); each session a `local_auth` biometric/passcode unlocks it. Passphrase is needed only at setup or on a new device (empty cache). |
| Mark timing | **Add-time only.** Sensitivity is chosen when adding the image (written straight to an encrypted `sensitive/` path). No retroactive re-encrypt/move of existing bytes this phase. |
| Corrupt/reset | **Typed `corrupt` state + explicit destructive reset.** `_readMeta` distinguishes absent from corrupt (never auto-overwrites). A "Reset Secure Vault" requires typed confirmation and permanently deletes all sensitive attachments. |
| Scope | **One 4b plan** covering all components below. |
| Biometric dep | **`local_auth`.** |
| Reset aftermath | Orphaned sensitive `VaultRef`s (whose bytes reset deleted) render as the existing broken-image placeholder — **not** auto-stripped from note content this phase. |

## Non-goals (this phase)

- No passphrase **change/rotation** or re-encryption of existing bytes (add-only, per 4a).
- No **retroactive** mark/unmark of already-stored attachments.
- No auto-stripping of orphaned sensitive refs after a reset (broken-image is acceptable).
- No `cloudApi` sensitive path (Phase 5).
- No per-attachment individual keys / sharing / server escrow.

---

## Vault state model (backbone)

```dart
enum VaultStatus { absent, locked, unlocked, corrupt }
```

Exposed via **`vaultSessionProvider`** — a Riverpod `Notifier<VaultSessionState>`
wrapping the 4a `VaultKeyService` plus the cache, the biometric gate, and the
timed-session lifecycle:

- **absent** — no `vault_meta.json` → offer setup.
- **locked** — valid meta, no in-session key → offer unlock (biometric if the
  key is cached, else passphrase).
- **unlocked** — key held in the session; sensitive reads/writes work.
- **corrupt** — `vault_meta.json` present but undecodable → block sensitive
  features; offer destructive reset.

`VaultSessionState` carries the `status` and (when unlocked) drives
`VaultKeyService.currentKey`, which `EncryptedVaultStore` already reads.

---

## Components

### B1 — Corrupt-state fix + destructive reset (the carried must-fix)

- **`VaultKeyService._readMeta`** currently catches only `VaultStoreException`
  (absent ⇒ null). Extend it to also catch `FormatException` from
  `VaultMetaCodec.decode` and surface a distinct **corrupt** signal (e.g.
  `_readMeta` returns a small result type `MetaLookup { absent | corrupt | VaultMeta }`,
  or a dedicated `status()` that reports corrupt). The naive
  "catch → null" is explicitly rejected: it would read corrupt as absent and let
  `setupPassphrase` overwrite the meta, destroying recoverable ciphertext.
- **`reset()`** on `VaultKeyService`: delete `vault_meta.json`, enumerate the
  vault (`IVaultStore.list('')`), delete every entry with `isSensitiveVaultPath`,
  clear the key cache, drop the in-memory key. Ends in `absent`. Destructive;
  the UI gates it behind typed confirmation.

### B2 — Secure-storage key cache

- **`VaultKeyCache`** interface: `read()`, `write(Uint8List key)`, `clear()`.
  - `SecureStorageVaultKeyCache` — backed by `flutter_secure_storage` (mirrors
    the existing `TokenStorage` injectable-storage pattern), a fixed key name.
  - Tests inject an in-memory fake (no platform channel).
- Wire into `VaultKeyService` (optional ctor param; 4a's in-memory field stays):
  - `setupPassphrase` / `unlock(passphrase)` success → `cache.write(key)`.
  - `lock()` drops the in-memory key but **keeps** the cache (so biometric
    re-unlock needs no passphrase).
  - New `Future<bool> unlockFromCache()` → read cached key; if present, hold it
    and return true; else false (caller falls back to passphrase).
  - `reset()` → `cache.clear()`.

### B3 — `local_auth` biometric gate + timed session

- Add **`local_auth`**. A thin `BiometricGate` wrapper (`Future<bool> authenticate()`)
  so it's fakeable in tests.
- **`vaultSessionProvider`** orchestrates unlock:
  1. status `locked` + key cached → `BiometricGate.authenticate()`; on success
     `unlockFromCache()` → `unlocked`.
  2. no cache (new device) / biometrics unavailable or denied → prompt passphrase
     → `VaultKeyService.unlock(passphrase)` → `unlocked`.
- **Timed session:** the notifier records `lastAccessAt` (bumped on each
  sensitive access) and observes `AppLifecycleState`; it relocks
  (`VaultKeyService.lock()`, status → `locked`) on `paused` **or** when
  `now - lastAccessAt > 5 min`. Cache persists across relock, so re-unlock is
  biometric-only.

### B4 — Settings "Secure Vault" section

New rows under the existing sync/data area of `settings_screen.dart`, driven by
`vaultSessionProvider.status`:

- **absent:** "Set up Secure Vault" → passphrase + confirm field + explicit
  **"If you forget this passphrase, these files cannot be recovered."** →
  `setupPassphrase`.
- **locked:** "Secure Vault — locked" + **Unlock** (biometric/passphrase).
- **unlocked:** "Secure Vault — on" + **Lock now** (`lock()`).
- **corrupt:** a warning row + **Reset Secure Vault** (typed-confirmation dialog
  spelling out permanent deletion) → `reset()`.
- **any configured state:** **Reset Secure Vault** available (same destructive
  dialog) for the forgotten-passphrase escape hatch.

### B5 — Mark-as-sensitive (add-time)

- The image add flow (toolbar / picker sheet) gains a **"Mark as sensitive"**
  choice. When chosen:
  - if `status == absent` → route to B4 setup first; if `locked` → unlock first;
    if `corrupt` → block with the reset affordance.
  - once `unlocked`: persist bytes to a **sensitive path**
    (`buildSensitiveAttachmentPath`) through the encrypting `vaultStoreProvider`,
    and record the `VaultRef` with `sensitive: true`.
- Applies to inline and trailing images (both are `VaultRef`s in `attachments`).

### B6 — Blurred / lock previews

- A sensitive-aware image widget used by the inline Markdown `imageBuilder` and
  the trailing `NoteMediaCardList`:
  - **locked** (`status != unlocked`, or resolve throws `VaultLockedException`)
    → blurred + lock-icon placeholder; tap → `vaultSessionProvider` unlock flow
    → on success re-resolve + render.
  - **unlocked** → decrypt (transparent via `EncryptedVaultStore`) + render
    normally (tap → fullscreen as today).
  - **genuinely missing** (`VaultStoreException` / resolver null) → the existing
    broken-image placeholder — distinct from locked.
- Non-sensitive rendering is unchanged (a ref's `sensitive` flag selects the path).

### B7 — AI-exclusion gate

- Add `bool sensitive` to `ReceiptInput` (default false). `ApiLlmExtractor.extract`
  **rejects** a sensitive input with a clear message before any upload.
- **Honest scope note:** no current code path feeds a stored sensitive attachment
  into receipt-scan (it extracts freshly-picked bytes), so this is
  defense-in-depth + policy enforcement for future callers. On-device OCR is
  unaffected (never leaves the device).

---

## Security model (additions vs 4a)

- **Key at rest:** the derived key now persists in the platform secure store
  (Keychain/Keystore) behind the OS biometric/passcode gate — the deliberate
  usability choice. Still never leaves the device; never sent to any server.
- **Threat coverage:** protects a synced/exfiltrated cloud blob (ciphertext
  only) and adds a view gate against a briefly-unlocked phone. Does **not**
  defend a fully-compromised unlocked device where the secure-store key is
  extractable.
- **Reset is destructive by design:** losing the passphrase (with an empty
  cache, e.g. new device) is unrecoverable — reset is the only escape and it
  deletes the ciphertext. Warned explicitly.

## Error handling / edge cases

- **corrupt meta** → `corrupt` status, sensitive features blocked, reset offered;
  never crashes, never overwrites.
- **biometric unavailable / not enrolled / denied** → fall back to passphrase
  entry (which re-derives + re-caches the key).
- **auth cancelled** → stays `locked`; preview stays blurred.
- **wrong passphrase** (new device) → `unlock` returns false → "wrong vault
  passphrase" message; no key retained.
- **relock mid-view** → next sensitive access re-triggers the unlock flow.
- **orphaned sensitive ref after reset** → broken-image placeholder (not a crash).
- **marking sensitive while locked/absent/corrupt** → routed to the right
  affordance, never a silent failure.

## Dependencies to add

- **`local_auth`** — biometric/passcode gate.
- Already present: `flutter_secure_storage` (^9.2.4), plus all 4a crypto.

## Testing

**B1 corrupt/reset:** `_readMeta` reports corrupt for undecodable meta (not
absent); `setupPassphrase` refuses over corrupt/existing meta; `reset()` deletes
meta + all `sensitive/` entries + clears cache and ends `absent`; a fake store
proves the sensitive files are gone and non-sensitive files remain.
**B2 cache:** setup/unlock writes the cache; `lock()` keeps it; `unlockFromCache`
restores the key without a passphrase; `reset()` clears it — all with an
in-memory fake cache.
**B3 gate/session:** with a fake `BiometricGate`, a cached-key unlock uses
biometric (no passphrase); denied biometric falls back to passphrase; relock
fires on `paused` and on inactivity > threshold; cache survives relock.
**B4 settings:** each `VaultStatus` renders the right rows; setup requires the
confirm field + shows the warning; reset requires typed confirmation.
**B5 mark:** choosing sensitive writes to a `sensitive/` path with
`sensitive: true`; unconfigured routes to setup first.
**B6 previews:** locked sensitive image → blurred/lock (not broken-image);
after unlock → renders; missing bytes → broken-image (distinct); non-sensitive
path unchanged.
**B7 AI gate:** a `sensitive` `ReceiptInput` is rejected by `ApiLlmExtractor`
before upload; non-sensitive proceeds; on-device OCR unaffected.

## Phasing for the plan

One plan, tasks in dependency order: **B1** (corrupt-state + reset on the
service) → **B2** (key cache) → **B3** (biometric gate + session notifier) →
**B4** (Settings section) → **B5** (mark-as-sensitive add flow) → **B6** (blurred
previews) → **B7** (AI-exclusion gate). B1–B3 are headless/unit-testable; B4–B6
are widget-tested; B7 is a small unit test.
