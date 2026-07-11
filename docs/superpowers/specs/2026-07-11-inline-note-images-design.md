# Inline Note Images — Design Spec

**Date:** 2026-07-11
**Status:** Approved (brainstorming) — ready for planning

## Goal

Let users place images **in the flow of note text** (OneNote-style, good for
instruction demos), while keeping a note's content a **plain text string**
(Markdown) that is AI-friendly — never binary, never base64. The image bytes
stay in the vault; the text carries only a stable placeholder.

## Non-Goals

- No WYSIWYG / rich-text engine. Editing stays text-first (Markdown source)
  with an insert-at-cursor action and a live rendered preview.
- No new backend work. Note `content` remains opaque text on the wire.
- No drag-to-reposition. Repositioning an image = moving its Markdown line.
- No change to how non-image attachments (PDFs, audio) work.

## Core Decisions (locked during brainstorming)

1. **Content format:** Markdown text string. Inline images use standard
   Markdown image syntax.
2. **Image reference:** a custom URI, `hmm-attachment://<vault-path>`, that
   wraps the existing `VaultRef.path`. Only vault-backed images are eligible.
3. **Scope:** *everywhere notes render* — one shared renderer and one shared
   insert-at-cursor helper, used by the general notes editor/detail and the
   service-record notes field.
4. **Editor UX:** insert-at-cursor + live preview (not WYSIWYG).
5. **Inline render:** the **whole image**, scaled to fit the text column width
   (aspect ratio preserved, never upscaled past native size), capped at a max
   height, tap → the existing fullscreen zoom viewer.
6. **Retention is confirmation-gated:** a stored image is **never** deleted as
   a side effect of editing text. Removal is always a deliberate, confirmed act.

---

## Architecture

Five cohesive units. The first four are shared infrastructure; the fifth is the
per-surface wiring.

```
Markdown body string  ──parse──►  inline hmm-attachment:// refs
        ▲                                    │
        │ insert-at-cursor                   ▼ imageBuilder
   Editor (TextField)              NoteMarkdownBody (MarkdownBody + imageBuilder)
        │ pick bytes                         │ resolve
        ▼                                    ▼
   Pending bytes map ──save: persist+rewrite──►  Vault (bytes)  ◄── VaultResolver
        │                                    ▲
        ▼ save: reconcile (confirm on remove)│
   Note.attachments column (retention set) ──► vault_gc (unchanged)
```

### Unit 1 — Inline-image URI codec

**New file:** `lib/core/data/attachments/inline_image_uri.dart`

A tiny pure module that converts between a `VaultRef` and the inline Markdown
URI. No I/O, no Flutter deps.

- `const inlineImageScheme = 'hmm-attachment';`
- `String formatInlineImageUri(VaultRef ref)` →
  `hmm-attachment://attachments/note-123/login.png`
- `VaultRef? parseInlineImageUri(String uri)` → the `VaultRef` for a well-formed
  `hmm-attachment://<vault-path>`; `null` otherwise (malformed / other scheme /
  external `http(s)` image).
- **Pending form** (pre-save, note has no id yet):
  `hmm-attachment://pending/<uuid>`.
  - `String formatPendingUri(String uuid)`
  - `String? pendingUuidOf(String uri)` → the uuid if the URI is a pending one,
    else `null`.
- `bool isInlineImageUri(String uri)` → true for either real or pending form.

**Why a custom scheme, not a raw path/URL:** content stays pure text and
storage-layout coupling is contained to this one codec. An AI reading the note
sees `![Login screen](hmm-attachment://…)` — a clean, captioned placeholder.

**Why the vault path is the identity:** it is already the stable key
`VaultResolver` uses (`vaultStore.getBytes(ref.path)`) and already what
`vault_gc` scans for. Reusing it means the renderer, resolver, and GC need no
new identity concept. The `alt` text carries the human/AI-meaningful caption.

### Unit 2 — Staged (pending) bytes for the live preview

Freshly-picked, not-yet-saved images render in the editor's live preview by
handing the renderer an **in-memory staged-bytes map** — no new `AttachmentRef`
subtype, no resolver wrapper, no codec change.

- The editor holds `Map<String, Uint8List> _pendingBytes` (uuid → bytes).
- `NoteMarkdownBody` (Unit 3) takes an optional `pendingBytes` map. In its
  `imageBuilder`, a `pending/<uuid>` URI renders directly from
  `pendingBytes[uuid]` via `Image.memory` (using the same fit/size wrapper as a
  real image); a real `hmm-attachment://<path>` URI goes through
  `VaultRef` → the existing `VaultResolver` → `AttachmentImage`.

**Why not a `PendingRef` in the sealed `AttachmentRef` hierarchy:** `AttachmentRef`
is a `sealed` class, so a new subtype would force a `pending` branch into every
exhaustive switch — notably `NoteAttachmentsCodec` (persistence) — for a value
that must **never** be persisted. Keeping pending state as a transient bytes map
outside the ref type avoids that ripple entirely. A pending image is tappable to
fullscreen only **after save** (once it has a `VaultRef`); before save it renders
inline but tap is a no-op (or a lightweight bytes preview — a plan-level detail).

### Unit 3 — Shared inline-image Markdown renderer

**New file:** `lib/features/notes/presentation/widgets/note_markdown_body.dart`.
The existing `MarkdownView` in `markdown_view.dart` is **reimplemented to
delegate to `NoteMarkdownBody`** (a resolver-less call renders text + any real
inline images), so current call sites keep working unchanged.

A widget wrapping `flutter_markdown`'s `MarkdownBody` with a custom
`imageBuilder`:

```dart
NoteMarkdownBody(
  data: markdown,
  resolver: resolver,           // VaultResolver (read) — required for real inline images
  pendingBytes: pendingMap,     // optional; only the editor supplies staged bytes
  selectable: true,
)
```

`imageBuilder(uri, title, alt)`:
1. If `uri` is a **pending** `hmm-attachment://pending/<uuid>` URI → render
   `Image.memory(pendingBytes[uuid])` in the same sizing wrapper as below (tap =
   no-op until saved).
2. If `uri` is a **real** `hmm-attachment://<vault-path>` URI → build a
   `VaultRef` and render an **`InlineNoteImage`**:
   - `AttachmentImage(ref: ref, resolver: resolver, fit: BoxFit.contain,
     alignment: Alignment.topCenter)` — whole image.
   - Wrapped so it scales to the available column width, preserves aspect ratio,
     never upscales past native size, and is capped at a max height
     (`maxHeight`, e.g. 70% of the shortest viewport side or a fixed dp cap —
     final value set in the plan).
   - Wrapped in a `GestureDetector` → `showFullscreenImage(context, ref)`.
   - On resolve failure (missing file) → the existing `AttachmentImage`
     broken-image placeholder, inline, no crash.
3. Otherwise (external `http(s)` image or unrecognized) → default behavior /
   placeholder; Markdown never throws.

**Render sites that switch to `NoteMarkdownBody`:**
- `lib/features/notes/presentation/screens/note_detail_screen.dart` (note read view)
- `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart`
  (service-record notes live preview)
- The general notes editor live preview (see Unit 5)

### Unit 4 — Editor insert-at-cursor + save-time reconciliation

Shared helpers so each surface behaves identically.

**New file:** `lib/features/notes/presentation/widgets/inline_image_insert.dart`

- `insertInlineImageAtCursor(TextEditingController body, String uuid, String alt)`
  — inserts `\n\n![alt](hmm-attachment://pending/<uuid>)\n\n` at
  `body.selection` (or appends if no selection), and restores a sensible caret
  position after the inserted block.
- `List<String> inlineRefPathsIn(String markdown)` — every real
  `hmm-attachment://<path>` referenced in the body (used for reconciliation and
  trailing-card dedup).
- `List<String> pendingUuidsIn(String markdown)` — every `pending/<uuid>` in the
  body (used at save to know which staged picks are actually placed).
- `String rewritePendingToVault(String markdown, Map<String, String> uuidToPath)`
  — replaces each `pending/<uuid>` with its real vault path at save.

**Editor flow (general notes — `note_editor_screen.dart`):**
1. Image button (gallery/camera) → pick bytes → generate `uuid` → stage bytes in
   the editor's `_pendingBytes` map → `insertInlineImageAtCursor(_bodyCtrl,
   uuid, defaultAlt)`. `defaultAlt` = the picked file's base name; user can edit
   it in the text like any Markdown.
2. Live preview uses `NoteMarkdownBody` with the `_pendingBytes` map supplied,
   so the staged image shows immediately.
3. **On save:**
   a. For each `uuid` still referenced in the body (`pendingUuidsIn`), persist
      its bytes to the vault under the created note id
      (`attachments/note-{id}/<file>`) via the existing attach path, collecting
      `uuid -> vaultPath`.
   b. `rewritePendingToVault(body, uuidToPath)` → final content string.
   c. Reconcile the retention set (Unit 4/5 retention rules below).
   d. Discard staged bytes for any `uuid` no longer referenced in the body
      (user inserted then deleted before saving — nothing was ever persisted).

### Unit 5 — Retention, GC safety, and no-double-display

**Retention rule (confirmation-gated):** the vault copy of an image is **never
removed as a side effect of editing text.** `Note.attachments.images` (the set
`vault_gc` reads) changes only through explicit user confirmation.

On save, compute:
- `inlineRefs` = real vault paths referenced inline in the final body.
- `attachedRefs` = vault paths currently in `attachments.images`.
- `removed` = `attachedRefs − inlineRefs` (previously attached, no longer inline).

Then:
- New inline images (from persisted pending picks) are **added** to
  `attachments.images` — so `vault_gc` never deletes a live inline image.
- If `removed` is non-empty, show a **confirmation dialog** listing those images:
  **"Delete these stored images, or keep them attached?"**
  - **Delete** → drop those refs from `attachments.images`; their bytes become
    GC-eligible (reclaimed on the next user-triggered `vault_gc`, never mid-edit).
  - **Keep** → retain those refs in `attachments.images`; they render as trailing
    media cards below the text, so nothing is lost.
- If the user cancels the whole save, no attachment changes are written.

**No double display:** `NoteMediaCardList` (the trailing media cards) is filtered
to exclude any ref referenced inline (`inlineRefPathsIn(content)`). An inline
image renders exactly once, in place. "Kept" (removed-from-inline-but-retained)
images and legacy attachments show as trailing cards. Legacy notes with no inline
Markdown are unchanged.

**Note delete:** the existing delete-confirm dialog gains a line — *"This will
also remove N stored image(s)."* — so deleting a note-with-images is never a
surprise. (Delete still cascades as today; this is a messaging change.)

**Album reassurance (documented behavior):** picking from the photo library
*copies* bytes into the vault; the original library photo is untouched. Only the
note's vault copy is ever affected, and only via the confirmations above.

---

## Data Flow Summary

| Moment | What happens |
|--------|--------------|
| **Read/display** | `content` (Markdown) → `NoteMarkdownBody`; `imageBuilder` parses `hmm-attachment://` → `VaultRef` → `VaultResolver` → bytes → whole-image inline; tap → fullscreen. Trailing cards show only non-inline attachments. |
| **Insert (edit)** | pick bytes → stage under `uuid` in `_pendingBytes` → insert `![alt](hmm-attachment://pending/<uuid>)` at cursor → live preview renders the staged bytes via the `pendingBytes` map. |
| **Save** | persist referenced pending picks to vault → rewrite `pending/<uuid>`→real path → reconcile `attachments.images` (add new; confirm on `removed`) → write content + attachments. |
| **GC** | `vault_gc` unchanged: scans `attachments.images`; live inline images are always present there, so never orphaned. |

---

## Error Handling

- **Unresolvable inline ref** (missing vault file, deleted out-of-band): inline
  broken-image placeholder via `AttachmentImage`'s existing error state. Markdown
  keeps rendering the rest of the body.
- **Malformed / non-`hmm-attachment` image URI**: `imageBuilder` returns a
  placeholder (or default handling for `http(s)`), never throws.
- **Pending uuid missing from the map** (shouldn't happen; defensive):
  placeholder, no crash.
- **Save with a pending pick whose bytes failed to persist**: surface the error
  via the existing mutate error path; do not rewrite that `pending/<uuid>` (it
  stays a pending placeholder the user can retry), and do not add a missing ref
  to `attachments.images`.

---

## Backend / Data-mode Notes

- No backend change. `content` stays opaque text; images ride the existing vault
  path (`local_vault_store` for `local`/`cloudStorage`, `api_vault_store` →
  `/v1/notes/{noteId}/vault/{filename}` for `cloudApi`). The `hmm-attachment://`
  URI encodes the same `VaultRef.path` the resolver already uses in every mode.
- Service-record notes reference the **owning note's** vault/attachments (the
  existing read-through projection), so the shared units apply unchanged there.

---

## Testing

**Unit — URI codec (`inline_image_uri.dart`):**
- `formatInlineImageUri` ↔ `parseInlineImageUri` round-trip for a `VaultRef`.
- Pending form: `formatPendingUri` / `pendingUuidOf` round-trip.
- Malformed / other-scheme / `http` URI → `parseInlineImageUri` returns `null`;
  `isInlineImageUri` false.

**Unit — insert/rewrite helpers (`inline_image_insert.dart`):**
- `insertInlineImageAtCursor` places the block at the selection and leaves a
  valid caret.
- `inlineRefPathsIn` / `pendingUuidsIn` extract exactly the referenced refs.
- `rewritePendingToVault` replaces every pending uuid with its mapped path and
  leaves unmapped text intact.

**Widget — renderer (`NoteMarkdownBody`):**
- An `hmm-attachment://<path>` body renders an image (fake resolver returns
  bytes); tap invokes the fullscreen viewer.
- A `pending/<uuid>` body renders from the supplied `pendingBytes` map.
- A malformed image URI renders a placeholder, and surrounding Markdown text
  still renders.

**Widget/integration — editor:**
- Insert-at-cursor puts the pending URI at the caret and the live preview shows
  the staged image.
- Save persists the pending pick, rewrites the body to the real vault path, and
  adds the ref to `attachments.images`.
- Trailing-card dedup: an inline-referenced image is **not** shown as a trailing
  card; a non-inline attachment **is**.

**Retention/GC:**
- Save with a removed inline link triggers the confirm dialog; **Delete** drops
  the ref (then a `vault_gc` run reclaims its bytes); **Keep** retains the ref
  (shown as a trailing card) and `vault_gc` does not delete it.
- A live inline-referenced ref is present in `attachments.images` and survives
  `vault_gc`.
- Note-delete confirm text reports the stored-image count.

---

## Suggested Phasing (for the plan)

1. **Shared infra:** URI codec, `NoteMarkdownBody` with `imageBuilder` (+ staged
   `pendingBytes` support), insert/rewrite helpers, trailing-card dedup filter —
   with their unit/widget tests. No surface behavior change yet beyond the
   renderer swap at read sites.
2. **General notes surface:** wire insert-at-cursor + live preview + save
   reconciliation + confirm-on-remove into `note_editor_screen.dart`; update the
   note-delete confirm text.
3. **Service-record notes surface:** wire the same shared helpers into the
   service-record notes field + preview.

Each phase is independently testable and shippable.
