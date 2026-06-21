# Note Voice Recording + Playback (Phase 3b) — Design

**Date:** 2026-06-20
**Status:** Approved (brainstorm) — pending implementation plan
**Parent spec:** `docs/superpowers/specs/2026-06-18-note-media-and-metadata-design.md` (the **voice** half of **Phase 3 / N3 — Voice + PDF**). PDF + the generic `files` model shipped as Phase 3a; this builds directly on it.
**Repos touched:** `hmm_console` (Flutter client) **and** `hmm` (`Hmm.ServiceApi` backend) — backend change is one schema-enum addition.

## Goal

Let a note carry **voice recordings**: tap 🎤 in the editor, record in a modal sheet, and get an audio card with play/pause + seek. Recordings are stored, synced, and garbage-collected through the **existing Phase 3a `files` attachment list** — a recording is just a `VaultRef` with an audio content-type.

## What 3a already provides (no change needed)

The Phase 3a groundwork handles audio with zero model work:
- `NoteAttachments.files` (client + backend container, schema, codec) holds any `VaultRef`.
- `persistFileToVault` stores raw bytes (no transcoding) — exactly right for an audio file.
- `attachFileBytes` appends a picked file to `files`.
- The synced `attachments` column, vault GC, `NoteFileCardList`, editor `_pendingFiles`, and detail-view rendering all already cover any file ref.

**So Phase 3b adds only:** the audio content-type to the allowlists, a recorder + player dependency, a record sheet, and an audio card. No model/codec/sync/GC changes.

## Decisions (locked during brainstorm)

1. **Modal record sheet.** 🎤 → a bottom sheet with a live timer + Stop/Cancel. Stop attaches a pending audio card; Cancel discards.
2. **Lightweight audio card** — play/pause, `elapsed / total`, a seekable `Slider`. No waveform.
3. **Stack:** `record` (recorder + mic permission), `just_audio` (player), AAC/`.m4a`, content-type **`audio/mp4`**.
4. **Dispatch by content-type inside the existing file-card list** — `audio/*` → `NoteAudioCard`, else (PDF) → `NoteFileCard`. Not a separate sub-list.

---

## Part A — Backend (`hmm`)

One change: allow the audio content-type through schema validation (the codec decode validates against the schema).

- `src/Hmm.Core.Vault/Schemas/NoteAttachments.schema.json`: add `"audio/mp4"` to the shared `contentType` enum (where `application/pdf` was added in 3a).
- `src/Hmm.Core.Vault.Tests/NoteAttachmentsCodecTests.cs`: a round-trip test for a `files` entry with `contentType: "audio/mp4"` (mirrors the 3a PDF test).

No domain/DTO/mapping changes — `Files` already carries it.

---

## Part B — Client (`hmm_console`)

### Allowlists

- `lib/core/data/attachments/attachment_ref_codec.dart`: add `'audio/mp4'` to `_allowedContentTypes`.
- `lib/core/data/attachments/picker/image_attachment_picker.dart`: add `'audio/mp4'` to `_allowedFileContentTypes`, and an `'m4a'`/`'audio/mp4'` case to `_extFor` (so the stored vault path gets a `.m4a` extension).

### Dependencies + platform config

- Add `record` (recorder; provides `hasPermission()` / `start` / `stop` / `isRecording`) and `just_audio` (player).
- iOS: add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist`.
- Android: add `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` to `android/app/src/main/AndroidManifest.xml`.

### Recorder seam (testable)

- New `lib/core/data/attachments/recorder/audio_recorder.dart`:
  - `abstract interface class AudioRecorderService { Future<bool> hasPermission(); Future<void> start(); Future<AudioRecording?> stop(); Future<void> cancel(); }`
  - `AudioRecording { Uint8List bytes; String fileName; String contentType; }` (contentType `audio/mp4`).
  - `RecordAudioRecorderService` — wraps the `record` package: `start` records to a temp `.m4a`; `stop` returns the file's bytes as an `AudioRecording`; `cancel` stops + deletes the temp file.
  - `audioRecorderProvider = Provider<AudioRecorderService>(...)` — overridable in tests.

### Record sheet

- New `lib/features/notes/presentation/widgets/record_sheet.dart` — `showRecordSheet(context, ref) → Future<PickedFileBytes?>`:
  - On open: `hasPermission()`; if false, close and return null (caller shows a SnackBar).
  - Starts recording; shows a live `mm:ss` timer (a periodic ticker) + **Stop** and **Cancel**.
  - **Stop** → `stop()` → returns a `PickedFileBytes(bytes, originalName: 'recording-<n>.m4a', contentType: 'audio/mp4')`.
  - **Cancel** (or dismiss) → `cancel()` → returns null.
  - Disposes the ticker; ensures the recorder is stopped on any close path.

### Audio card

- New `lib/features/notes/presentation/widgets/note_audio_card.dart` — `NoteAudioCard`:
  - Inputs: an audio **source** — for a saved ref, an `AttachmentRef` (resolved → temp file → player); for a pending pick, raw bytes (written to a temp file). To keep one widget, it takes a `Future<String> Function()` `resolvePath` (returns a playable local path) + `name`, plus `onRemove`/`readOnly`.
  - UI: play/pause button, `elapsed / total` text, a seekable `Slider` bound to the `just_audio` player's position/duration streams.
  - Lifecycle: lazily creates the player on first play; **disposes** it in `dispose()`. Playback errors → a disabled state, never a crash.

### File-card list dispatch

- `lib/features/notes/presentation/widgets/note_file_card_list.dart`: for each saved/pending entry, branch on content-type — `audio/*` → `NoteAudioCard`, else → `NoteFileCard`.
  - Saved audio: `resolvePath` resolves the `VaultRef` bytes via `attachmentResolverProvider` → per-ref temp file (reuse the 3a `openAttachment` temp-dir keying) → path.
  - Pending audio: write the `PickedFileBytes.bytes` to a per-pick temp file → path.
  - Content-type source: saved `VaultRef.contentType`; pending `PickedFileBytes.contentType`.

### Editor + toolbar

- `lib/features/notes/presentation/widgets/media_toolbar.dart`: add a 🎤 button (`Icons.mic_none_outlined`) with an `onRecord` callback (parallel to `onPickFile`).
- `lib/features/notes/presentation/screens/note_editor_screen.dart`: `_addRecording()` → `showRecordSheet`; a returned `PickedFileBytes` is added to the existing `_pendingFiles` (so it persists via the existing save loop → `attachFileBytes`). Deny/empty → SnackBar.

### Detail view

- No change needed — `NoteFileCardList(readOnly: true)` already renders the note's `files`; the new dispatch makes audio refs show as read-only `NoteAudioCard`s (play only, no ✕).

## Error handling / lifecycle

- Mic permission denied → SnackBar ("Microphone permission needed to record"), no sheet, nothing attached.
- Record start/stop failure → SnackBar, no card.
- Oversized recording → caught by the existing `kMaxAttachmentBytes` guard in `persistFileToVault` on save (surface the error).
- Every `just_audio` player and the recorder are disposed; temp files reuse the 3a per-ref temp-dir scheme (no collisions, OS-cleaned).

## Testing

- **Allowlists:** codec + picker accept `audio/mp4`; backend schema round-trips an `audio/mp4` ref.
- **`_extFor`:** `audio/mp4` → `m4a`.
- **Record sheet:** with a faked `AudioRecorderService`, Stop returns a `PickedFileBytes` (audio content-type); Cancel returns null; permission-denied returns null without recording.
- **`NoteAudioCard`:** renders play/pause + time; tapping play drives the (faked/abstracted) player; disposes cleanly.
- **Dispatch:** `NoteFileCardList` renders an `audio/mp4` ref as `NoteAudioCard` and a `application/pdf` ref as `NoteFileCard`.
- **Editor:** recording via the faked recorder shows a pending audio card; save persists it into `files` (reuses `attachFileBytes`).

## Sequencing

Backend first (schema enum, so `cloudApi` accepts audio refs later), then client. The client work ships independently for `local`/`cloudStorage`.

## Out of scope (Phase 3b)

- Waveform rendering (lightweight slider only).
- Recording pause/resume, trimming, or re-recording in place.
- Background/lock-screen playback controls.
- Transcription / speech-to-text.
- Non-`audio/mp4` audio formats (single format keeps the allowlist + playback simple).
