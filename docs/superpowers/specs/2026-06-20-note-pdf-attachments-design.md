# Note PDF Attachments + Generalized Media Model (Phase 3a) — Design

**Date:** 2026-06-20
**Status:** Approved (brainstorm) — pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-06-18-note-media-and-metadata-design.md` (this details the **PDF** half of **Phase 3 / N3 — Voice + PDF**). Voice is Phase 3b, separate, and builds on the generalized model introduced here.
**Repos touched:** `hmm_console` (Flutter client) **and** `hmm` (`Hmm.ServiceApi` backend, incl. `Hmm.Core.Vault`).

## Goal

Let a note carry **PDF (and, structurally, any non-image) file attachments**, shown as Journal-style **file cards** that open in the OS viewer on tap. Generalize the attachment container from image-only (`primaryImage` + `images`) to also hold a typed `files` list — laying the groundwork voice (3b) reuses. Close the pre-existing gap where attachment **refs** don't sync across devices.

## Decisions (locked during brainstorm)

1. **Split:** PDF first (this spec, 3a) + the model generalization; voice is 3b.
2. **One generic `files` list** on `NoteAttachments` for all non-image media; rendering dispatches on `contentType`. (Not type-specific `documents`/`audios` lists.)
3. **OS hand-off** for viewing (tap → system viewer via a light `open_filex` dep). No in-app PDF renderer.
4. **Close the attachment-ref sync gap:** serialize the `attachments` JSON column in the synced note body (out + in, preserve-on-omit). This makes PDFs **and images** sync across devices.

## Key facts grounding this design

- `VaultRef` already carries `contentType` + `byteSize`, so a ref is type-agnostic — only the **container** is image-specific.
- `persistToVault({noteId, bytes, originalName, contentTypeHint})` (added in Phase 1) already turns picked bytes into a vault `VaultRef`. PDF picking reuses it unchanged.
- `file_picker` ^8.0.0 is already a dependency.
- The synced note body (`_noteRowToBlob`) does **not** currently include the `attachments` column, so attachment refs don't propagate in `cloudStorage` (the bytes ride OS-level vault sync, but the refs don't). Decision 4 fixes this.

---

## Part A — Backend (`hmm`)

### Vault model (`Hmm.Core.Vault`)

- `NoteAttachments.cs`: add `public IReadOnlyList<VaultRef> Files { get; }` (constructor param `IList<VaultRef>? files = null`, defaulting to empty). Include `Files` in `Empty`, equality, and any `IsEmpty`-style check. `Files` need not be disjoint from images (it holds non-image media), but in practice it never overlaps.
- `Schemas/NoteAttachments.schema.json`: add a `files` property — an array of the same vault-ref item shape as `images`. Not required (absent = empty).
- `NoteAttachmentsCodec.cs`: decode the `files` array (absent ⇒ empty list) and encode it (empty ⇒ omit the key, mirroring how empty payloads encode to null/omitted today).
- `NoteAttachmentsCodecTests.cs`: round-trip a payload with `files`.

### Domain + DTOs + mapping

- `Hmm.Core.Map/DomainEntity/HmmNote.cs`: add `public IList<VaultRef> Files { get; set; } = new List<VaultRef>();`.
- `HmmMappingProfile.cs`: extend the existing attachments projection — decode `Files` from the `Attachments` column (`.ForMember(dest => dest.Files, opt => opt.MapFrom(src => NoteAttachmentsCodec.Decode(src.Attachments).Files.ToList()))`) and include `Files` in the reverse `Encode(...)` call that writes the column.
- DTOs (`ApiNote`, `ApiNoteForCreate`, `ApiNoteForUpdate`): add `IList<VaultRef> Files` (maps by convention, like `Images`).

### Backend tests

- Codec round-trips `files`.
- Mapping: a `HmmNote` with `Files` round-trips Dao(JSON)↔Domain↔Dto.

---

## Part B — Client (`hmm_console`)

### Attachment model + codec

- `lib/core/data/attachments/attachment_ref.dart` — `NoteAttachments`: add `final List<AttachmentRef> files;` (constructor defaults to `const []`, stored unmodifiable). Update `isEmpty`/`isNotEmpty`, `==`, `hashCode`, `toString` to include `files`. `primaryImage` disjointness check stays image-only.
- `lib/core/data/attachments/attachment_ref_codec.dart` — `NoteAttachmentsCodec`: decode a `files` array (absent ⇒ empty) and encode it (empty ⇒ omit, so an images-only/empty payload is byte-identical to today). Keep the `{primaryImage, images, files}` wrapper in sync with the backend schema.

### PDF picking → vault

- New `📄` button in `MediaToolbar` (`lib/features/notes/presentation/widgets/media_toolbar.dart`) alongside Photos/Camera. Tapping invokes a new editor callback (parallel to `onPick` for images).
- Picking uses a new file byte source (parallel to `ImagePickerByteSource`): `file_picker` filtered to PDF → `PickedFileBytes {bytes, originalName, contentType}` (contentType `application/pdf`). Provider-injected for testability (mirrors `imageByteSourceProvider`).
- The editor holds `_pendingFiles: List<PickedFileBytes>`; picking adds to it and a card appears immediately. On save, each is persisted via `persistToVault` and appended to `NoteAttachments.files` (a new `MutateNote.attachFileBytes` method, parallel to `attachImageBytes`).

### File card UI

- New `lib/features/notes/presentation/widgets/note_file_card.dart` — `NoteFileCard`: doc icon + filename (`originalName`) + human size; ✕ to remove (editor only); tap → open.
- A new `lib/features/notes/presentation/widgets/note_file_card_list.dart` (parallel to `NoteMediaCardList`) renders `saved` (List<AttachmentRef>) + `pending` (List<PickedFileBytes>) file cards, with `onRemovePending` and `readOnly`.
- **Open action:** a small `openAttachment(ref)` helper resolves a `VaultRef` to an openable absolute path and calls `open_filex`. Resolution: prefer the local vault store's on-disk absolute path; fall back to writing the resolved bytes to a temp file (`path_provider` temp dir) then opening. Errors (no app to open / failure) surface a SnackBar, never crash.

### Editor + detail wiring

- `note_editor_screen.dart`: add `_pendingFiles` + saved files (from `note.effectiveAttachments.files`); render `NoteFileCardList` (near the image cards); `_save` persists pending files into `files`. The 📄 toolbar button picks via the new file byte source.
- `note_detail_screen.dart`: render saved files via `NoteFileCardList(readOnly: true)` (tap opens).

### Vault GC

- `lib/core/data/vault/vault_gc.dart` — `VaultGarbageCollector` reachable-ref set currently collects `attachments.primaryImage` + `attachments.images`; add `...attachments.files`, or attached PDFs get collected.

### Sync — close the ref-sync gap (`sync_orchestrator.dart`)

- **Outbound** (`_noteRowToBlob`): add `'attachments': n.attachments` (the raw JSON-string column value, nullable) to the body.
- **Inbound**: on **insert**, write `attachments: Value(body['attachments'] as String?)`; on **update**, preserve-on-omit (`body.containsKey('attachments') ? Value(...) : const Value.absent()`).
- This carries the whole `{primaryImage, images, files}` payload, so **images and PDFs both sync** across devices. (Bytes continue to ride OS-level vault sync, unchanged.)

### Dependencies

- Add `open_filex` (open a file in the OS default app). `file_picker` and `path_provider` already present.

### Client tests

- Codec: `files` round-trips; an images-only/empty payload encodes identically to today (back-compat).
- `NoteAttachments`: equality/isEmpty account for `files`.
- Repo / `attachFileBytes`: a picked PDF persists to the vault and appends to `files`.
- GC: a ref in `files` is treated as reachable (not collected).
- Card: `NoteFileCard` renders name/size, hides ✕ when read-only; tapping invokes the open helper (open helper stubbed).
- Editor: 📄 pick shows a pending file card; save persists it.
- Sync: round-trip of the `attachments` payload (out + in + preserve-on-omit), asserting a note's `files` (and images) survive a push→pull.

## Sequencing

Backend first (Vault schema/codec ready for `cloudApi` later), then client. Client `local` + `cloudStorage` work ships independently.

## Out of scope (Phase 3a)

- Voice recording/playback (Phase 3b — reuses the `files` list + cards).
- In-app PDF rendering (OS hand-off only).
- Non-PDF document types from the 📄 button (the model is generic, but the button filters to PDF in 3a).
- Attachment-**byte** transport changes (bytes still ride OS-level vault sync).
