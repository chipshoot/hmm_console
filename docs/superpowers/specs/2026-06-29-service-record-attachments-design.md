# Service-Record Attachments — Design

Owner: Flutter `hmm_console`
Status: **Draft / pre-implementation**
Date: 2026-06-29
Sibling docs: `docs/attachments-design.md` (the universal note-attachment
model this builds on), `docs/attachments-path-spec.md` (vault path rules),
`docs/superpowers/specs/2026-06-20-note-pdf-attachments-design.md` (the
`files` list / PDF generalization this reuses).

## Why

A vehicle's service record is where receipts, invoices, and photos of
the work naturally belong. Today the service-record form captures typed
line items (labour/part/fee), tax, and totals, but there is no way to
attach the paper trail. This adds **image and PDF attachments** to a
service record, reusing the existing note-attachment vault stack.

## Scope

**In scope (v1):**
- Image and PDF attachments on automobile **service records**.
- Data modes **`local`** and **`cloudStorage`** only.
- Attach/remove in the service-record form; read-only display in the
  service-record detail/history view.

**Out of scope (v1):**
- `cloudApi` mode. In that mode service records are served from
  `/v1/automobiles/{autoId}/services/{id}` (a different controller from
  the note vault endpoints) and the API does not expose attachments on
  the service-record DTO. Supporting it needs backend work and a
  generalized `ApiVaultStore`; deferred. In `cloudApi` the entity's
  attachments are simply empty and the form's attachment section is
  hidden.
- Audio attachments (the model supports them; service records don't
  need them in v1 — image + PDF only).
- Any backend (`Hmm.ServiceApi`) change. None is required for the two
  in-scope modes.
- A "primary image" / hero concept (see Attachment model below).

## Background: what already exists

Service-record attachments are almost entirely a **wiring** job because
the foundation is built and shipping for notes:

- **A service record *is* an `HmmNote`** in `local`/`cloudStorage` mode.
  `LocalServiceRecordRepository` stores one note per service event
  (catalog `Hmm.AutomobileMan.ServiceRecord`, parented to the
  automobile), with the record JSON serialized into `note.content`.
  `ServiceRecord.id` **is** that note's integer id.
- **Notes already carry a synced `attachments` column.** The Drift
  `Notes` table has a nullable `attachments` JSON column (schema v4),
  and the sync orchestrator already propagates it for every note row —
  so service-record attachment **refs sync with zero sync changes**.
- **`HmmNoteCreate` and `HmmNoteUpdate` already accept
  `attachments: NoteAttachments?`.** No change to the note repository
  contract is needed.
- **The pick → persist → resolve → render stack is generic:**
  - `NoteAttachments { AttachmentRef? primaryImage; List<AttachmentRef>
    images; List<AttachmentRef> files }` + `NoteAttachmentsCodec`
    (`lib/core/data/attachments/`). `files` is the non-image (PDF) list;
    allowed content types include `application/pdf`.
  - `imageByteSourceProvider` → `PickedImageBytes` and
    `fileByteSourceProvider.pickPdf()` → `PickedFileBytes` pick bytes
    **without** needing a note id (hold-then-attach-on-save).
  - `IImageAttachmentPicker.persistToVault(...)` (images; downsized,
    HEIC→JPEG) and `persistFileToVault(...)` (PDF; raw) write bytes into
    the vault under `attachments/note-{noteId}/{uuid}.{ext}` and return a
    `VaultRef`.
  - `attachmentResolverProvider` → resolves a `VaultRef` to bytes;
    `AttachmentImage` (`lib/core/data/attachments/widgets/`) renders an
    image ref; `openAttachment(ref)` resolves → temp file → `open_filex`
    (OS viewer) for PDFs.
  - `VaultGarbageCollector` / `collectReferencedVaultPaths` already scan
    **every** note's `attachments` column — service-record notes
    included — so orphan GC needs no change.

## Attachment model

A service record's attachments are presented as **one flat, typed
list** — no "primary image". Images render as thumbnails; PDFs render as
document cards. Under the hood the data is stored in the existing
`NoteAttachments` shape on the owning note:
- Images → `NoteAttachments.images`.
- PDFs → `NoteAttachments.files`.
- `primaryImage` is left `null` and ignored by this feature.

This keeps the storage format identical to every other note (so the
codec, sync, and GC are untouched) while giving service records a
receipt-friendly flat presentation.

## Architecture (Approach A: read-through projection)

The `ServiceRecord` entity carries its attachments as a **read-through
projection of the owning note**, exactly as `docs/attachments-design.md`
prescribes for the `Automobile` entity. The form binds to
`record.attachments`; the local repo round-trips the note's
`attachments` column. This is the chosen approach over an
"attach-by-note-id, off-entity" alternative because it keeps a single
write path and makes the entity self-describing.

### Data layer

**Entity — `lib/features/automobile_records/domain/entities/service_record.dart`**
- Add `final NoteAttachments attachments;` defaulting to
  `NoteAttachments.empty` in the constructor (last optional field).
- `ServiceRecord` has **no `copyWith` today**; add one (covering all
  fields including `attachments`). The save flow uses it to set
  attachments after persisting picks.
- Computed getters (`effectiveTotal`, etc.) are untouched. Attachments
  do not participate in totals.

**Local repo — `lib/core/data/local/local_service_record_repository.dart`**
- `_deserialize(note)`: decode `note.attachments` via
  `NoteAttachmentsCodec.decode(...)` and pass the result into the
  `ServiceRecord`; fall back to `NoteAttachments.empty` on null or a
  decode error (the existing `try/catch` already guards the content
  decode; attachment decode is independently tolerant).
- `_serialize(...)`: **unchanged.** Attachments live in the note's
  dedicated `attachments` column, never inside the serialized `content`
  JSON.
- `createRecord(autoId, r)`: keep creating the note via
  `HmmNoteCreate(...)`. A brand-new record has no note id yet, so the
  picks are persisted and the column written on the follow-up update
  performed by the save flow (below). (The repo method itself may pass
  `attachments: r.attachments` into `HmmNoteCreate` when the caller
  already holds resolved refs — but in practice new records arrive with
  pending byte-picks, not refs, so the save flow does the two-step.)
- `updateRecord(autoId, id, r)`: pass `attachments: r.attachments` into
  `HmmNoteUpdate(...)` alongside `subject`/`content`.

### Save / pick flow (state)

In `lib/features/automobile_records/states/mutate_service_record_state.dart`,
mirroring `note_editor_screen.dart` + `MutateNote`:

1. The form holds **pending picks** — `List<PickedImageBytes>` +
   `List<PickedFileBytes>` (from `imageByteSourceProvider` and
   `fileByteSourceProvider.pickPdf()`) — plus the already-saved
   `VaultRef`s retained from the loaded record.
2. **New record save:** `createRecord(autoId, record)` → obtain the note
   id from the returned `ServiceRecord.id` → for each pending pick call
   `persistToVault` (images) / `persistFileToVault` (PDFs) under
   `note-{id}` → assemble a `NoteAttachments` from the new `VaultRef`s →
   `updateRecord(autoId, id, record.copyWith(attachments: assembled))`.
3. **Existing record save:** persist pending picks under the existing
   note id, merge the new `VaultRef`s with the retained ones, then a
   single `updateRecord(...)` with the merged `NoteAttachments`.
4. **Remove an attachment:** drop its `VaultRef` from the working
   `NoteAttachments` and call `IVaultStore.delete(ref.path)` for the
   bytes. Belt-and-braces: any missed bytes are reclaimed by the
   existing `vault_gc` sweep.

All vault paths are produced via
`vaultRelativePathJoin(['attachments', 'note-$id', '$uuid.$ext'])` —
never hand-built strings — per `docs/attachments-path-spec.md`.

### UI

**Shared widget — `AttachmentsSection`**
A new reusable widget (placed in a shared location, e.g.
`lib/core/data/attachments/widgets/attachments_section.dart`) renders the
flat, typed list and handles add/remove via callbacks. It is **not**
coupled to the notes feature; it composes core-level pieces:
- Image refs → `AttachmentImage` thumbnail; tap → `FullscreenImage`.
- PDF refs → a document card (icon + original name); tap →
  `openAttachment(ref)`.
- An `editable` flag: `true` shows the add control (image + PDF) and a
  per-item remove affordance; `false` is read-only.
- Built with `flutter_platform_widgets` (buttons, dialogs) per the
  project UI rules.

**One small refactor:** lift `openAttachment(ref)` from
`lib/features/notes/presentation/util/open_attachment.dart` to a shared
core location under `lib/core/data/attachments/` so both the notes
feature and `AttachmentsSection` use it. Update the notes-feature import;
behaviour is unchanged (resolve bytes → temp file → `open_filex`).

**Form — `service_record_form_screen.dart`**
Add an "Attachments" section near the bottom of the existing
`Form`/`SingleChildScrollView`, rendering `AttachmentsSection(editable:
true, ...)` wired to the pending-pick lists and the save flow. Hidden in
`cloudApi` mode.

**Detail / history view — `service_records_screen.dart`**
Render `AttachmentsSection(editable: false, ...)` so receipts are visible
when browsing a record. Hidden when the record has no attachments.

## Error handling

- **Decode failure** of the `attachments` column → `NoteAttachments.empty`
  (tolerant; never throws on load).
- **Resolve failure** (bytes not present on this device — e.g.
  `cloudStorage` mobile-only, byte sync is desktop-only per
  `attachments-design.md`) → `AttachmentImage` shows its placeholder;
  PDF card shows a "can't open on this device" state. This is the
  existing note behaviour, reused unchanged.
- **Pick exceeds limits** (8 MB cap `kMaxAttachmentBytes`; unsupported
  type) → the existing picker rejects it; surface the existing
  user-facing message.
- **Vault write failure** mid-save → the record's content still saves;
  the failed attachment is reported and not added to the column (no
  dangling ref). Bytes without a ref are GC-reclaimed.

## Testing

TDD, bite-sized tasks. New/changed test files:

- **Local repo round-trip** (`local_service_record_repository` test): a
  `ServiceRecord` with two images + one PDF survives
  `createRecord`/`updateRecord` → `getRecordById`; the refs land in the
  note's `attachments` column and **not** in `content`; a null or
  malformed `attachments` column deserializes to `NoteAttachments.empty`.
- **Save flow** (`mutate_service_record_state` test): pending picks on a
  **new** record persist under the new note id and surface as
  `VaultRef`s; on an **existing** record they merge with retained refs;
  removing an attachment calls `IVaultStore.delete` for its path;
  `cloudApi` mode leaves attachments empty (no vault writes).
- **`AttachmentsSection`** (widget test): renders image thumbnails vs.
  PDF document cards by content type; `editable: true` shows add +
  remove, `editable: false` hides them; tap wiring invokes the
  fullscreen/open callbacks. Use a tall test viewport
  (`t.view.physicalSize`) if rows fall below the fold.
- **Path safety**: assert generated paths go through
  `vaultRelativePathJoin`/validate (no hand-built strings) — covered
  implicitly by reusing the existing picker, but asserted in the save-
  flow test.

## Implementation order

Each step ships independently and keeps tests green.

1. **Entity:** add `attachments` (default `NoteAttachments.empty`) **and a
   `copyWith`** to `ServiceRecord`. Tests compile.
2. **Local repo:** round-trip the `attachments` column in
   `_deserialize` / `updateRecord` (and optionally `createRecord`).
   Repo round-trip test.
3. **Refactor:** lift `openAttachment` to core; repoint the notes
   import. Existing note tests stay green.
4. **Shared widget:** `AttachmentsSection` (flat, typed, editable flag).
   Widget test.
5. **Save flow:** pending-pick → persist → write-column wiring in
   `mutate_service_record_state`. Save-flow test.
6. **Form:** add the editable "Attachments" section to
   `service_record_form_screen` (hidden in `cloudApi`).
7. **Detail view:** add the read-only section to
   `service_records_screen`.

Steps 1–2 are data-only; step 4 is the first visible widget; steps 6–7
are the user-facing surfaces.
