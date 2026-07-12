# Note Inline References & Secure Attachments — Design Spec

**Date:** 2026-07-11
**Status:** Approved (brainstorming) — ready for planning
**Supersedes:** the narrower `2026-07-11-inline-note-images-design.md` (inline images
are Phase 1 of this umbrella).

## Goal

Give notes three related capabilities, on a shared foundation, working across the
data tiers:

1. **Inline images** in the flow of note text (OneNote-style, for instruction
   demos).
2. **Inline references / links**: note→note, note→web/video (`hmm-note://`,
   `http(s)://`), using the *same* Markdown mechanism as images.
3. **Sensitive attachments** (ID cards, health reports, tickets): encrypted at
   rest, biometric-gated, excluded from cloud AI, but still synced (as
   ciphertext) across devices.

Note content stays a **plain-text Markdown string** — AI-friendly, never binary.
The capability lives on the **base `HmmNote`**, so every note catalog (general,
gas-log, future BookNote/Recipe) inherits it.

## Non-Goals (this sprint)

- No WYSIWYG editor; editing stays Markdown-source + insert-at-cursor + live
  preview.
- No content/block-level link **anchors** (`hmm-note://<uuid>#anchor`) and no
  backlinks index — the namespace is reserved, built later.
- No **cloudApi** attachment byte path this sprint. That tier is "Phase 15, not
  yet built" (`sync_orchestrator` reconciles vault only when
  `supportsAttachments`). The design is cloudApi-**ready** (same refs/URIs/
  encryption via `ApiVaultStore`); wiring lands when that phase does.
- No change to receipt-scan behavior beyond adding the sensitive-exclusion gate.

## Core Decisions (locked during brainstorming)

| Area | Decision |
|------|----------|
| Content format | Markdown text string on base `HmmNote.content`. |
| Reference model | One `hmm://` scheme family, **dispatched by scheme** in a shared renderer. |
| Images | `![alt](hmm-attachment://<vault-path>)`; whole image, fit-to-width, max-height cap, tap → fullscreen. |
| Links | `[label](hmm-note://<uuid>)` (note) and `[label](https://…)` (web/video). Anchors reserved. |
| Base capability | Lives on base `HmmNote`; all catalogs inherit; structured renderers emit `hmm-…` refs in their Markdown. |
| Editor | Insert-at-cursor + live preview (images via staged bytes; links via note picker). |
| Retention | Confirmation-gated: a stored image is never deleted as a side effect of editing text. |
| Sensitive | Per-attachment `sensitive` flag → `EncryptedVaultStore` (AES-256-GCM). |
| Key model | **Passphrase-derived vault key** (Argon2id), cached in secure storage, biometric-gated; multi-device via passphrase; server never holds key or plaintext. |
| View gate | Biometric/passcode (`local_auth`) before decrypt/view; blurred previews until unlocked. |
| AI policy | Sensitive attachments never sent to any cloud-AI `/extract` endpoint. |
| Tiers | `local` + `cloudStorage` live this sprint; `cloudApi` design-ready, deferred. |

---

## The `hmm://` Reference Family (unifying model)

All inline references are Markdown, distinguished by **image vs link syntax** and
by **URI scheme**. The shared renderer dispatches on scheme:

| Markdown | Scheme | Meaning | Sprint |
|----------|--------|---------|--------|
| `![alt](hmm-attachment://<vault-path>)` | `hmm-attachment` | inline image (vault bytes) | Phase 1 |
| `[label](hmm-note://<uuid>)` | `hmm-note` | link to another note | Phase 2 |
| `[label](https://…)` | `http`/`https` | web / video link | Phase 2 |
| `[label](hmm-note://<uuid>#anchor)` | reserved | link to a block inside a note | later |

**Identity choices (all stable across tiers):**
- Image: `VaultRef.path` (`attachments/note-{N}/{file}`) — the key
  `VaultResolver`/`vault_gc` already use.
- Note link: **`Notes.uuid`** — the unique, `clientDefault(generateUuid)` column
  that the sync layer matches on (`sync_orchestrator.dart:22-25,289`). No schema
  change; links survive local↔OneDrive↔API sync.

Content stays pure text; an AI reads clean, captioned placeholders
(`[See setup](hmm-note://…)`, `![Login screen](hmm-attachment://…)`).

## Base-Note Capability

Note "type" is a **catalog name string** → renderer via
`NoteRenderRegistry.rendererFor(catalogName)` (`render_registry.dart:9-26`); all
catalogs share one `HmmNote` (content + `attachments` column). Therefore:

- Inline refs are inherently base-level: any catalog's note can carry them in its
  `content`, and `note_detail_screen` already renders `MarkdownView` + the
  attachments region (`NoteMediaCardList`) for every note.
- **Structured renderers** (e.g. `GasLogNoteRenderer`) return a Markdown string;
  to show inline images/links they simply include `hmm-…` refs in that string,
  and the shared renderer resolves them. No per-catalog image plumbing.
- **Shared attachments region:** the existing `NoteMediaCardList` (trailing
  cards) is the shared surface where a structured note's non-inline attachments
  ("comment"-style images) appear. It already renders for all catalogs.

---

## Component Architecture

Shared infrastructure (U1–U5), links (U6), sensitive (U7). Each is independently
testable.

### U1 — Inline-reference URI codec

**New:** `lib/core/data/attachments/inline_ref_uri.dart` (pure, no I/O).

- `const attachmentScheme = 'hmm-attachment';` / `const noteScheme = 'hmm-note';`
- Image: `formatImageUri(VaultRef) → 'hmm-attachment://<path>'`;
  `parseImageUri(String) → VaultRef?`.
- Pending (pre-save image, no note id yet):
  `formatPendingUri(uuid) → 'hmm-attachment://pending/<uuid>'`;
  `pendingUuidOf(String) → String?`.
- Note link: `formatNoteUri(noteUuid) → 'hmm-note://<uuid>'`;
  `parseNoteUri(String) → String? uuid` (ignores any `#anchor` for now).
- Predicates: `isAttachmentUri`, `isNoteUri`. Anything else (`http(s)`, unknown)
  → not an hmm ref (handled as external/default).

### U2 — Staged (pending) bytes for the live preview

Freshly-picked, unsaved images render via an **in-memory `Map<String, Uint8List>
pendingBytes` (uuid → bytes)** handed to the renderer. **No new `AttachmentRef`
subtype** and no pending case in the persistence codec — the sealed hierarchy's
exhaustive switches gain no transient variant (a pending value must never be
persisted; the `sensitive` field in U7 is a separate, additive `VaultRef`
change). A `pending/<uuid>` image URI renders
directly from `pendingBytes[uuid]`; real URIs resolve through the normal vault
path. Pending images become tap-to-fullscreen only after save.

### U3 — Shared reference-aware Markdown renderer

**New:** `lib/features/notes/presentation/widgets/note_markdown_body.dart`.
`MarkdownView` (`markdown_view.dart`) is reimplemented to **delegate** to it, so
existing call sites keep working.

Wraps `flutter_markdown`'s `MarkdownBody` with:
- **`imageBuilder(uri,…)`** — dispatch by scheme:
  - pending image URI → `Image.memory(pendingBytes[uuid])` in the sizing wrapper.
  - real `hmm-attachment://` → `AttachmentImage(ref, resolver, fit: contain,
    alignment: topCenter)`, scaled to column width (aspect preserved, no
    upscaling past native, capped max-height), tap → `showFullscreenImage`;
    resolve failure → inline broken-image placeholder.
  - other (`http(s)` image) → default/placeholder; never throws.
- **`onTapLink(text, href, title)`** — dispatch by scheme:
  - `hmm-note://<uuid>` → resolve + navigate (U6).
  - `http(s)://` → `url_launcher` (external/in-app; video URLs open in the
    platform player/browser).
  - unknown → ignore safely.

Used at every render site: `note_detail_screen`, `service_record_form_screen`
notes preview, and the editor live preview.

### U4 — Editor insert helpers

**New:** `lib/features/notes/presentation/widgets/inline_insert.dart` — shared by
every editing surface.

- `insertImageAtCursor(controller, uuid, alt)` → inserts
  `\n\n![alt](hmm-attachment://pending/<uuid>)\n\n` at the selection.
- `insertNoteLinkAtCursor(controller, uuid, label)` → inserts
  `[label](hmm-note://<uuid>)` at the selection.
- `insertWebLinkAtCursor(controller, url, label)` → standard `[label](url)`.
- Extractors/rewriters:
  `imageRefsIn(md) → List<String> vaultPaths`,
  `pendingUuidsIn(md) → List<String>`,
  `noteUuidsIn(md) → List<String>`,
  `rewritePendingToVault(md, uuidToPath) → md`.

Toolbar (`media_toolbar.dart`) gains a **"link to note"** action → opens a
**note picker** (search existing notes by subject) → `insertNoteLinkAtCursor`.
Image buttons now insert at cursor (U2/U5) instead of appending a trailing card.

### U5 — Retention, GC safety, no double-display

Retention is **confirmation-gated**; `attachments.images` (what `vault_gc` reads)
changes only via explicit user confirmation.

On save: `inlineRefs = imageRefsIn(body)`, `attachedRefs = attachments.images`,
`removed = attachedRefs − inlineRefs`.
- New inline images (persisted pending picks) are **added** to
  `attachments.images` → GC never deletes a live inline image.
- If `removed` is non-empty → confirm dialog **"Delete these stored images, or
  keep them attached?"**: *Delete* drops the refs (bytes GC-eligible on the next
  user-triggered `vault_gc`, never mid-edit); *Keep* retains them (render as
  trailing cards).
- Note-delete confirm gains **"This will also remove N stored image(s)."**
- **No double-display:** `NoteMediaCardList` excludes any ref referenced inline;
  inline images render once, in place; legacy notes unchanged.

### U6 — Note-link resolution & navigation

- **Resolve:** `hmm-note://<uuid>` → look up the local note by `Notes.uuid`
  (works in every tier since sync correlates by uuid). New provider
  `noteByUuidProvider(uuid)`.
- **Navigate:** on tap, GoRouter push to that note's detail route. (Route takes
  the local id resolved from the uuid; if the note isn't present locally yet in
  cloud modes, show a "syncing / not available" affordance.)
- **Deleted / missing target:** non-crashing inline affordance ("Linked note
  unavailable"); the link text stays selectable.
- **No GC / no bytes** — links are plain text. Deleting a note does not rewrite
  other notes' link text; resolution simply fails gracefully.

### U7 — Sensitive (encrypted) attachments

**Classification.** A per-attachment `bool sensitive` on the attachment metadata
(extend `VaultRef` / `NoteAttachments` codec with a `sensitive` field, default
`false`; back-compat: absent = false). Set when adding/marking an image
("Mark as sensitive"). Sensitive images may be inline or trailing.

**Encryption at rest — `EncryptedVaultStore` decorator.**
`lib/core/data/vault/encrypted_vault_store.dart` implements `IVaultStore`, wraps
the active store (`LocalVaultStore` now, `ApiVaultStore` later), and:
- On `putBytes` for a sensitive path → AES-256-GCM encrypt (random per-file
  nonce; nonce + tag stored with the ciphertext, e.g. prefixed) then delegate.
- On `getBytes` for a sensitive path → delegate, then decrypt (requires an
  unlocked key, see below).
- Non-sensitive paths pass straight through (no crypto).
Selection: `vaultStoreProvider` returns the encrypted decorator over the
tier-appropriate base store — callers unchanged.

**Key model — passphrase-derived, biometric-gated.**
- First use: the user sets a **vault passphrase**. Derive a 256-bit key via
  **Argon2id** (salt stored non-secret; params fixed in code). 
- Cache the derived key in **`flutter_secure_storage`** (Keychain/Keystore).
- **`local_auth`** biometric/passcode gate protects *using* the cached key
  (unlock → key available for the session/timeout; else prompt).
- **Multi-device:** a new device prompts for the passphrase once, re-derives the
  same key (salt travels with the user's synced vault metadata, non-secret), then
  caches it locally. The server/OneDrive only ever see ciphertext + non-secret
  salt/nonce.
- **Recovery:** forgetting the passphrase makes sensitive bytes unrecoverable —
  surfaced with an explicit warning at setup. (No server escrow by decision.)

**View gate & previews.** Showing a sensitive image requires an unlocked key
(biometric/passcode). Until unlocked, previews (inline and trailing) render a
**blurred / lock-icon placeholder**; tap → auth → decrypt → show.

**AI / sync policy.**
- **Sync:** sensitive **ciphertext** syncs like any attachment (OneDrive bytes;
  cloudApi later). Encryption is transparent to sync — it moves opaque bytes.
- **AI exclusion:** any attachment with `sensitive = true` is **never** sent to a
  cloud-AI `/extract` endpoint. Gate at the extractor input (e.g.
  `ApiLlmExtractor.extract` / its caller) — reject or skip sensitive inputs with
  a clear message.

**GC:** unchanged — operates on refs/paths regardless of encryption.

---

## Three-Tier Behavior

| Tier | Note content + refs | Image bytes | Sensitive | Status |
|------|--------------------|-------------|-----------|--------|
| `local` | Drift `content` + `attachments` JSON | `LocalVaultStore` (app docs) | `EncryptedVaultStore` over local | **Live** |
| `cloudStorage` (OneDrive) | synced note JSON (`sync_orchestrator`) | `LocalVaultStore` rooted in OneDrive; `_reconcileVault` replicates bytes | ciphertext replicated by OneDrive; key never synced in plaintext | **Live** |
| `cloudApi` (serviceAPI) | note JSON via API | `ApiVaultStore` → `/v1/notes/{id}/vault/{path}` | same encrypted decorator over `ApiVaultStore` | **Design-ready, deferred** (Phase 15) |

`hmm-note://<uuid>` and `hmm-attachment://<path>` URIs are tier-independent; the
same content string resolves in every tier. cloudApi needs only its vault byte
path finished for full parity — no design change.

---

## Data Flow (Phase 1 image example)

| Moment | What happens |
|--------|--------------|
| Display | `content` → `NoteMarkdownBody`; `imageBuilder` parses `hmm-attachment://` → `VaultRef` → `VaultResolver` (through `EncryptedVaultStore` if sensitive → biometric → decrypt) → whole-image inline; tap → fullscreen. |
| Insert | pick bytes → stage under `uuid` → insert `![alt](hmm-attachment://pending/<uuid>)` → live preview from `pendingBytes`. |
| Save | persist referenced pending picks (encrypt if sensitive) → rewrite `pending/<uuid>`→real path → reconcile `attachments.images` (add new; confirm on removed) → write content + attachments. |
| Link insert | note picker → `[label](hmm-note://<uuid>)`. |
| Link tap | resolve uuid → navigate, or graceful "unavailable". |
| GC | `vault_gc` scans `attachments.images`; live inline refs always present. |

---

## Error Handling

- Unresolvable image ref (missing/deleted file) → inline broken-image
  placeholder; rest of the Markdown still renders.
- Malformed / non-`hmm` image or link URI → placeholder / ignored; never throws.
- Pending uuid missing (defensive) → placeholder.
- Sensitive decrypt without unlock → blurred placeholder + auth prompt; auth
  cancel → stays blurred.
- Wrong passphrase on a new device → decryption fails with a clear "wrong vault
  passphrase" message; no partial/garbage bytes shown.
- Note-link target missing → "Linked note unavailable" affordance.
- Save where a pending pick failed to persist → surface via existing mutate error
  path; do not rewrite that placeholder or add a missing ref.

---

## Security Model (sensitive attachments)

- **Threat model:** protects sensitive images if the cloud store (OneDrive /
  serviceAPI) is compromised or a synced blob is exfiltrated (attacker sees only
  ciphertext), and adds a device-level view gate against a briefly-unlocked
  phone. Does **not** defend against a fully compromised unlocked device with the
  vault key resident.
- **Crypto:** AES-256-GCM per-file (random nonce, auth tag); key = Argon2id(pass,
  salt). Salt + nonce are non-secret and travel with the ciphertext/metadata.
- **Key custody:** key exists only on the user's devices (secure storage);
  never sent to any server. No escrow (by decision) → passphrase loss is
  unrecoverable (warned).
- **AI boundary:** sensitive plaintext never leaves the device and is never sent
  to cloud AI, even as ciphertext.

## Dependencies to Add

- A vetted Dart crypto lib for **AES-256-GCM + Argon2id** (e.g. `cryptography`).
- **`local_auth`** for biometric/passcode gating.
- Already present: `flutter_secure_storage` (^9.2.4), `crypto` (^3.0.6),
  `url_launcher` (verify; add if missing) for web/video links.

---

## Testing

**U1 codec:** round-trip image/pending/note URIs; malformed/other-scheme → null;
predicates correct.

**U3 renderer:** `hmm-attachment://` renders image (fake resolver); `pending/…`
renders from map; malformed → placeholder + surrounding text renders;
`onTapLink` dispatches `hmm-note://` vs `http(s)` vs unknown.

**U4 insert/rewrite:** each insert helper places correct syntax at the caret;
extractors return exactly the referenced refs; `rewritePendingToVault` maps all
pending uuids.

**U5 retention:** save with a removed link → confirm dialog; Delete drops ref
(then `vault_gc` reclaims); Keep retains (trailing card); live inline ref
survives GC; dedup (inline image not also a trailing card); note-delete count.

**U6 links:** `hmm-note://<uuid>` resolves to the right note and navigates;
missing target → "unavailable"; web link → `url_launcher` invoked.

**U7 sensitive:** sensitive `putBytes`/`getBytes` round-trips through
`EncryptedVaultStore` (ciphertext on disk ≠ plaintext; decrypt matches);
non-sensitive bypasses crypto; wrong passphrase → decrypt fails cleanly; view
requires unlock (blurred until auth); a `sensitive` attachment is rejected by the
cloud-AI extractor gate; Argon2id derivation is deterministic for
(passphrase, salt).

**Cross-tier:** a note with inline image + note-link round-trips through the sync
models (content + attachments) preserving refs; encrypted bytes reconcile as
opaque bytes.

---

## Phasing (for the plan) — all this sprint except Phase 5

1. **Inline images (shared infra + general notes):** U1 codec, U2 pending bytes,
   U3 renderer (imageBuilder), U4 image insert + rewrite, U5 retention/dedup;
   wire into the general-notes editor + all read sites. local + cloudStorage.
2. **Links (note + web/video):** extend U1 (note URIs), U3 `onTapLink`, U4 note
   picker + link inserts, U6 resolution/navigation/deleted-target, `url_launcher`.
3. **Base-note capability surfacing:** ensure structured catalogs (gas-log) can
   carry/show inline refs via the shared renderer + attachments region; add the
   `NoteRenderer` path for structured notes to emit refs (mostly wiring/tests).
4. **Sensitive attachments:** `sensitive` flag + codec; `EncryptedVaultStore`;
   passphrase/Argon2id key + secure-storage cache; `local_auth` gate; blurred
   previews; AI-exclusion gate; setup/unlock UX. local + cloudStorage.
5. **cloudApi parity (design-ready, deferred):** finish `ApiVaultStore` byte path
   + backend `/v1/notes/{id}/vault` when the cloudApi attachments phase lands.
   Documented; not built this sprint.

Each phase is independently testable and shippable.
