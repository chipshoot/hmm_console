# Base-Note Inline Images (Phase 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make inline images a reusable **base-note capability** by extracting the general-note editor's inline-image logic into a shared `InlineImageController`, then adopting it in the **service-record** editor (a structured note type) so its Markdown notes field supports inline images too.

**Architecture:** The inline-image mechanics (stage picked bytes → insert `hmm-attachment://pending/<uuid>` placeholder at the cursor → on save, persist picks and rewrite placeholders to real vault paths) become a small injectable controller. Each editor keeps its own attachment-reconciliation (a general note owns its images; a service record merges inline refs with its attachments gallery), calling the controller for the shared parts. No data-model change — every catalog's `HmmNote` already shares `content` + `attachments`.

**Tech Stack:** Flutter, Riverpod, existing Phase 1/2 pieces (`inline_insert.dart`, `NoteMarkdownBody`, `inline_ref_uri.dart` codec, vault/picker).

**Scope:** Phase 3 of `docs/superpowers/specs/2026-07-11-note-inline-refs-and-secure-attachments-design.md`. **In scope:** extract the shared controller + refactor the general note editor onto it (behavior-preserving) + wire inline images into the **service-record** notes field (insertion, live preview, save persist/rewrite, gallery dedup, retention-confirm). **Out of scope:** gas log / automobile / insurance / scheduled-service editors (they adopt the same controller in cheap follow-ups; some need an attachments field added first); sensitive/encrypted attachments (Phase 4). The comment-attachments *gallery* model for field-based notes is deferred with those editors — the service record already has both a Markdown notes field and an attachments gallery.

## Global Constraints

- No `pending/<uuid>` URI may ever survive into saved `content`/`notes` (a failed/missing pick is stripped) — preserve the Phase 1 guarantee.
- A stored image is never dropped from a note's `attachments` as a silent side effect of editing text — removing an inline image on save prompts (Keep/Delete), matching Phase 1.
- Inline-referenced images render once (inline in the preview) and are excluded from the trailing attachments cards/gallery (dedup).
- `.value` on AsyncValue, never `.valueOrNull` (not defined in this project's riverpod 3.0.3).
- Reuse Phase 1/2 pieces; the refactor of the general note editor must keep ALL existing tests green (behavior-preserving).
- Follow existing test patterns (pure unit tests; widget tests with fakes; the service-record editor tests live under `test/features/automobile_records/`).

**Reference signatures (verified — do not re-derive):**

```dart
// lib/core/data/attachments/inline_ref_uri.dart
String? parseImageUri(String); String formatPendingUri(String uuid);
String? pendingUuidOf(String); List<String> imageRefPathsIn(String md);
List<String> pendingUuidsIn(String md);
String rewritePendingToVault(String md, Map<String,String> uuidToPath);
String removePendingImage(String md, String uuid);
// lib/features/notes/presentation/widgets/inline_insert.dart
void insertImageAtCursor(TextEditingController c, String uuid, String alt);
// lib/core/util/uuid.dart -> String generateUuid();
// lib/core/data/attachments/picker/image_byte_source.dart
class PickedImageBytes { final Uint8List bytes; final String originalName; final String? contentType; }
final imageByteSourceProvider = Provider<ImageByteSource>(...); // .pick(AttachmentPickSource) -> Future<PickedImageBytes?>
// lib/core/data/attachments/attachment_ref.dart
final class VaultRef extends AttachmentRef { final String path; final String contentType; final int byteSize; ... }
class NoteAttachments { NoteAttachments({AttachmentRef? primaryImage, List<AttachmentRef> images, List<AttachmentRef> files}); static final empty; final images; final files; final primaryImage; }
// lib/features/notes/states/mutate_note_state.dart (MutateNote)
Future<VaultRef> persistInlineImage(int noteId, PickedImageBytes pick);
Future<HmmNote?> setAttachments(int noteId, NoteAttachments attachments);
Future<HmmNote> updateGeneral(int id, {String? markdownBody, ...});
// lib/features/automobile_records/states/mutate_service_record_state.dart (MutateServiceRecordState)
Future<ServiceRecord?> create(int autoId, ServiceRecord record);
Future<void> save({required int autoId, required ServiceRecord record, required bool isEdit,
  List<PickedImageBytes> pendingImages, List<PickedFileBytes> pendingFiles,
  List<VaultRef> retained, List<VaultRef> removed});
// service_record_form_screen.dart state: _notesCtrl, _pendingImages (gallery), _savedRefs, _removedRefs,
//   _existing (ServiceRecord?), widget.isEdit; NoteMarkdownBody preview already present.
// lib/core/data/attachments/picker/image_attachment_picker.dart
//   imageAttachmentPickerProvider.future -> IImageAttachmentPicker
//   Future<VaultRef> persistToVault({required int noteId, required Uint8List bytes,
//     required String originalName, String? contentTypeHint});
```

---

### Task 1: Extract `InlineImageController`

**Files:**
- Create: `lib/features/notes/presentation/widgets/inline_image_controller.dart`
- Test: `test/features/notes/presentation/widgets/inline_image_controller_test.dart`

**Interfaces:**
- Produces:
  - `class InlineImageController` with `Map<String,Uint8List> get pendingBytes`, `void stageAndInsert(TextEditingController body, PickedImageBytes pick)`, and `Future<InlineResolveResult> resolveAndRewrite({required int noteId, required TextEditingController body, required Future<VaultRef> Function(int, PickedImageBytes) persist})`.
  - `static List<String> InlineImageController.removedImagePaths(List<String> loadedInlinePaths, String currentBody)`.
  - `class InlineResolveResult { final List<VaultRef> newRefs; final bool hadFailures; }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/widgets/inline_image_controller_test.dart
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/features/notes/presentation/widgets/inline_image_controller.dart';

PickedImageBytes _pick() => PickedImageBytes(
    bytes: Uint8List.fromList([1, 2, 3]), originalName: 'a.jpg',
    contentType: 'image/jpeg');

void main() {
  test('stageAndInsert stages bytes and inserts a pending placeholder', () {
    final c = InlineImageController();
    final body = TextEditingController(text: 'x');
    body.selection = const TextSelection.collapsed(offset: 1);
    c.stageAndInsert(body, _pick());
    expect(body.text, contains('hmm-attachment://pending/'));
    expect(c.pendingBytes.values.single, _pick().bytes);
  });

  test('resolveAndRewrite persists picks, rewrites the body, clears state',
      () async {
    final c = InlineImageController();
    final body = TextEditingController();
    c.stageAndInsert(body, _pick());
    const ref = VaultRef(
        path: 'attachments/note-7/a.jpg', contentType: 'image/jpeg', byteSize: 3);

    final result = await c.resolveAndRewrite(
      noteId: 7, body: body, persist: (_, __) async => ref);

    expect(result.newRefs, [ref]);
    expect(result.hadFailures, isFalse);
    expect(body.text, contains('hmm-attachment://attachments/note-7/a.jpg'));
    expect(body.text, isNot(contains('pending/')));
    expect(c.pendingBytes, isEmpty);
  });

  test('resolveAndRewrite strips a placeholder whose pick fails', () async {
    final c = InlineImageController();
    final body = TextEditingController();
    c.stageAndInsert(body, _pick());

    final result = await c.resolveAndRewrite(
      noteId: 7, body: body, persist: (_, __) async => throw Exception('boom'));

    expect(result.newRefs, isEmpty);
    expect(result.hadFailures, isTrue);
    expect(body.text, isNot(contains('pending/')));
    expect(body.text, isNot(contains('hmm-attachment://')));
  });

  test('removedImagePaths returns loaded paths no longer in the body', () {
    final removed = InlineImageController.removedImagePaths(
      ['attachments/note-1/a.png', 'attachments/note-1/b.png'],
      'kept ![b](hmm-attachment://attachments/note-1/b.png)',
    );
    expect(removed, ['attachments/note-1/a.png']);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/inline_image_controller_test.dart`
Expected: FAIL — class doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/notes/presentation/widgets/inline_image_controller.dart
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/util/uuid.dart';
import 'inline_insert.dart';

/// Outcome of resolving staged inline images on save.
class InlineResolveResult {
  const InlineResolveResult({required this.newRefs, required this.hadFailures});

  /// Vault refs for the picks that were persisted this save.
  final List<VaultRef> newRefs;

  /// True if any referenced pick failed/was missing and its placeholder was
  /// stripped from the body.
  final bool hadFailures;
}

/// Reusable inline-image editing capability shared by note editors (general
/// notes, service records, ...). Owns the staged pending picks + placeholder
/// insertion; on save persists the picks and rewrites the body's
/// `pending/<uuid>` placeholders to real vault paths.
///
/// It deliberately does NOT reconcile the note's attachment set — that differs
/// per editor — it only returns the new refs so the caller composes retention.
class InlineImageController {
  final Map<String, Uint8List> _pendingBytes = {};
  final Map<String, PickedImageBytes> _pendingPickByUuid = {};

  /// Staged bytes keyed by uuid — pass to `NoteMarkdownBody(pendingBytes:)`.
  Map<String, Uint8List> get pendingBytes => _pendingBytes;

  /// Stages [pick] and inserts a pending image placeholder at [body]'s caret.
  void stageAndInsert(TextEditingController body, PickedImageBytes pick) {
    final uuid = generateUuid();
    _pendingBytes[uuid] = pick.bytes;
    _pendingPickByUuid[uuid] = pick;
    insertImageAtCursor(body, uuid, pick.originalName);
  }

  /// Persists every staged pick still referenced in [body] (via [persist]),
  /// rewrites its placeholder to the real vault path, and STRIPS any
  /// placeholder whose pick failed/was missing so no `pending/` URI survives.
  /// Mutates `body.text` to the resolved string and clears staged state.
  Future<InlineResolveResult> resolveAndRewrite({
    required int noteId,
    required TextEditingController body,
    required Future<VaultRef> Function(int noteId, PickedImageBytes pick) persist,
  }) async {
    final uuidToPath = <String, String>{};
    final newRefs = <VaultRef>[];
    final failed = <String>[];
    for (final uuid in pendingUuidsIn(body.text)) {
      final pick = _pendingPickByUuid[uuid];
      if (pick == null) {
        failed.add(uuid);
        continue;
      }
      try {
        final vref = await persist(noteId, pick);
        uuidToPath[uuid] = vref.path;
        newRefs.add(vref);
      } catch (_) {
        failed.add(uuid);
      }
    }
    var text = rewritePendingToVault(body.text, uuidToPath);
    for (final uuid in failed) {
      text = removePendingImage(text, uuid);
    }
    body.text = text;
    _pendingBytes.clear();
    _pendingPickByUuid.clear();
    return InlineResolveResult(
        newRefs: newRefs, hadFailures: failed.isNotEmpty);
  }

  /// Vault paths referenced inline at load but no longer in [currentBody] — the
  /// caller confirms before dropping them from the note's retention set.
  static List<String> removedImagePaths(
      List<String> loadedInlinePaths, String currentBody) {
    final current = imageRefPathsIn(currentBody).toSet();
    return loadedInlinePaths
        .where((p) => !current.contains(p))
        .toList();
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/inline_image_controller_test.dart`
Expected: PASS (4).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/widgets/inline_image_controller.dart test/features/notes/presentation/widgets/inline_image_controller_test.dart
git commit -m "feat(notes): extract reusable InlineImageController

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Refactor the general note editor onto the controller (behavior-preserving)

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Tests: none new — ALL existing note tests must stay green (`test/features/notes/...`: media, inline-save, retention, dedup).

**Interfaces:**
- Consumes: `InlineImageController` (Task 1).

- [ ] **Step 1: Replace the inline state + logic with the controller**

In `_NoteEditorScreenState`:

Replace the two maps
```dart
  final Map<String, Uint8List> _pendingBytes = {};
  final Map<String, PickedImageBytes> _pendingPickByUuid = {};
```
with
```dart
  final InlineImageController _inline = InlineImageController();
```

Update `_addMedia` to use the controller:
```dart
  Future<void> _addMedia(AttachmentPickSource source) async {
    final pick = await ref.read(imageByteSourceProvider).pick(source);
    if (pick == null || !mounted) return;
    setState(() => _inline.stageAndInsert(_bodyCtrl, pick));
  }
```

Replace the whole `_persistInlineImages` body's step 1 (persist/rewrite loop) with the controller, keeping steps 2–3 (removal confirm + reconciliation) in the editor:
```dart
  Future<void> _persistInlineImages(int noteId, MutateNote mutate) async {
    // 1) Persist + rewrite via the shared controller.
    final result = await _inline.resolveAndRewrite(
      noteId: noteId, body: _bodyCtrl, persist: mutate.persistInlineImage);
    if (mounted) setState(() {}); // body text + pendingBytes changed
    if (result.hadFailures && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Some images couldn't be added and were skipped."),
        ),
      );
    }

    // 2) Removal confirm (unchanged policy).
    final removed = InlineImageController.removedImagePaths(
            _loadedInlinePaths, _bodyCtrl.text)
        .toSet();
    var deleteRemoved = false;
    if (removed.isNotEmpty && mounted) {
      deleteRemoved = await _confirmRemoveImages(removed.length);
    }

    // 3) Reconcile retention (unchanged).
    if (result.newRefs.isEmpty && removed.isEmpty) return;
    bool keep(AttachmentRef r) =>
        r is! VaultRef || !(deleteRemoved && removed.contains(r.path));
    final base = _savedAttachments ?? NoteAttachments.empty;
    final images = <AttachmentRef>[
      ...base.images.where(keep),
      for (final r in result.newRefs)
        if (!base.images.contains(r)) r,
    ];
    final primary = (base.primaryImage != null && keep(base.primaryImage!))
        ? base.primaryImage
        : null;
    await mutate.setAttachments(
      noteId,
      NoteAttachments(primaryImage: primary, images: images, files: base.files),
    );
  }
```

Update the live-preview and dedup references from `_pendingBytes` to `_inline.pendingBytes` (grep the file for `_pendingBytes` / `_pendingPickByUuid` and replace all remaining uses — the preview `NoteMarkdownBody(pendingBytes: _inline.pendingBytes, ...)`). Add the import:
```dart
import '../widgets/inline_image_controller.dart';
```
Remove the now-unused `dart:typed_data` import ONLY if nothing else needs it (the `Uint8List` maps are gone — verify with the analyzer).

- [ ] **Step 2: Run the whole notes suite + analyze**

Run: `cd ~/projects/hmm_console && flutter analyze lib/features/notes && flutter test test/features/notes`
Expected: `No issues found!`; every existing test passes (media insert, inline save rewrite, retention Keep/Delete, dedup, failed-pick strip). Fix any missed `_pendingBytes` reference the analyzer flags.

- [ ] **Step 3: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/screens/note_editor_screen.dart
git commit -m "refactor(notes): general editor uses InlineImageController (no behavior change)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Service-record notes — inline insert action, live preview, gallery dedup

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart`
- Test: `test/features/automobile_records/service_record_inline_insert_test.dart`

**Interfaces:**
- Consumes: `InlineImageController` (Task 1); the form's existing `_notesCtrl`, `_savedRefs`, `NoteMarkdownBody` preview, `imageByteSourceProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/automobile_records/service_record_inline_insert_test.dart
// Pump ServiceRecordFormScreen for a NEW record (mode local so the notes
// section shows). Override imageByteSourceProvider to return a fixed
// PickedImageBytes (tiny PNG). Enter some Notes text to reveal the notes
// section, tap the new "insert image into notes" action (Icons.image_outlined
// / tooltip 'Insert image into notes'), and assert the Notes field controller
// text now contains 'hmm-attachment://pending/' and the preview shows an
// Image. Mirror the pump/override scaffolding from the existing
// service_record_form_edit_test.dart.
```

> Implementer writes this out from `test/features/automobile_records/service_record_form_edit_test.dart` (same ProviderScope overrides + `_StubMode`/repo). Assert (a) the Notes `TextField` controller text contains `hmm-attachment://pending/`, (b) `find.byType(Image)` in the preview.

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/service_record_inline_insert_test.dart`
Expected: FAIL — no insert action exists.

- [ ] **Step 3: Add the controller + insert action + preview pendingBytes + gallery dedup**

Add the field to `_ServiceRecordFormScreenState`:
```dart
  final InlineImageController _inline = InlineImageController();
  List<String> _loadedInlinePaths = const [];
```
Import:
```dart
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../notes/presentation/widgets/inline_image_controller.dart';
```

Add an insert handler:
```dart
  Future<void> _insertInlineImage() async {
    final pick = await ref
        .read(imageByteSourceProvider)
        .pick(AttachmentPickSource.gallery);
    if (pick == null || !mounted) return;
    setState(() => _inline.stageAndInsert(_notesCtrl, pick));
  }
```

Add an insert button just above the Notes field's preview (near line 247-253), a left-aligned `Row` with:
```dart
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.image_outlined),
                        tooltip: 'Insert image into notes',
                        onPressed: _insertInlineImage,
                      ),
                    ),
```

Wire the preview's staged bytes (the existing `NoteMarkdownBody`, line 261-266):
```dart
                      NoteMarkdownBody(
                        data: _notesCtrl.text,
                        resolver: ref.watch(attachmentResolverProvider).value,
                        pendingBytes: _inline.pendingBytes,
                        selectable: false,
                      ),
```

Dedup the gallery: exclude refs referenced inline in the notes from the saved images shown in `_attachmentItems` (line 310-317):
```dart
  List<AttachmentItem> get _attachmentItems {
    final inline = imageRefPathsIn(_notesCtrl.text).toSet();
    return [
      for (final p in _pendingImages) PendingImageItem(p),
      for (final r in _savedRefs)
        if (r.contentType.startsWith('image/') && !inline.contains(r.path))
          SavedAttachmentItem(r),
      for (final p in _pendingFiles) PendingFileItem(p),
      for (final r in _savedRefs)
        if (!r.contentType.startsWith('image/')) SavedAttachmentItem(r),
    ];
  }
```

Capture the loaded inline paths where the record loads and `_savedRefs` is set (~line 112, in the load path): add
```dart
      _loadedInlinePaths = imageRefPathsIn(record.notes ?? '');
```

- [ ] **Step 4: Run to verify it passes + analyze**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/service_record_inline_insert_test.dart && flutter analyze lib/features/automobile_records`
Expected: PASS; `No issues found!`.

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/presentation/screens/service_record_form_screen.dart test/features/automobile_records/service_record_inline_insert_test.dart
git commit -m "feat(automobile): inline image insertion in service-record notes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Service-record save — persist/rewrite inline, merge into attachments, retention

**Files:**
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart` (`_submit`)
- Test: `test/features/automobile_records/service_record_inline_save_test.dart`

**Interfaces:**
- Consumes: `InlineImageController.resolveAndRewrite` + `removedImagePaths` (Task 1); `MutateServiceRecordState.create` + `.save`; `imageAttachmentPickerProvider`.

**Algorithm (two-phase, mirroring the general editor):** a NEW record must be created first to get its note id before inline picks can be persisted (vault path = `attachments/note-{id}/…`). So `_submit` ensures the id, resolves inline (persist + rewrite the notes body), merges the inline refs into the `retained` set passed to `save`, and confirms any removed inline image before dropping it.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/automobile_records/service_record_inline_save_test.dart
// New record: insert an inline image into Notes (staged), fill required
// fields (mileage/date/types), tap Save. Then load the saved record via the
// repo and assert: record.notes contains 'hmm-attachment://attachments/note-'
// (rewritten, no 'pending/'), and record.attachments.images contains a
// VaultRef whose path matches the notes URL. Use the local Drift repo +
// in-memory vault overrides (mirror the service-record mutate tests) plus the
// form scaffolding.
```

> Implementer writes this from the existing service-record mutate/form test harnesses. Assert the saved `notes` has no `pending/` and a matching `VaultRef` in `attachments.images`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/automobile_records/service_record_inline_save_test.dart`
Expected: FAIL — `_submit` doesn't resolve inline images yet.

- [ ] **Step 3: Resolve inline in `_submit` before saving**

Replace the tail of `_submit` (the single `notifier.save(...)` call, lines 517-526) with the resolve-then-save flow. Build the `record` as today (its `notes` still holds `pending/` placeholders), then:

```dart
    final notifier = ref.read(mutateServiceRecordStateProvider.notifier);

    // If there are staged inline images, resolve them against a note id.
    if (_inline.pendingBytes.isNotEmpty) {
      // Ensure a note id: create the record first if new.
      int noteId;
      ServiceRecord base = record;
      if (!widget.isEdit) {
        final created = await notifier.create(widget.automobileId, record);
        if (created == null) return; // create failed; state surfaced the error
        base = created;
        noteId = created.id;
      } else {
        noteId = record.id;
      }

      final picker = await ref.read(imageAttachmentPickerProvider.future);
      final result = await _inline.resolveAndRewrite(
        noteId: noteId,
        body: _notesCtrl,
        persist: (id, pick) => picker.persistToVault(
          noteId: id, bytes: pick.bytes,
          originalName: pick.originalName, contentTypeHint: pick.contentType),
      );
      if (mounted) setState(() {});
      if (result.hadFailures && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Some images couldn't be added and were skipped.")));
      }

      // Confirm any inline image the user removed from the notes text.
      final removedPaths = InlineImageController.removedImagePaths(
              _loadedInlinePaths, _notesCtrl.text)
          .toSet();
      final removedRefs = <VaultRef>[..._removedRefs];
      var retainedRefs = <VaultRef>[..._savedRefs];
      if (removedPaths.isNotEmpty && mounted) {
        final del = await _confirmRemoveInlineImages(removedPaths.length);
        if (del) {
          removedRefs.addAll(
              _savedRefs.where((r) => removedPaths.contains(r.path)));
          retainedRefs = retainedRefs
              .where((r) => !removedPaths.contains(r.path))
              .toList();
        }
      }
      // Merge the freshly-persisted inline refs into the retention set.
      for (final r in result.newRefs) {
        if (!retainedRefs.any((e) => e.path == r.path)) retainedRefs.add(r);
      }

      await notifier.save(
        autoId: widget.automobileId,
        record: base.copyWith(
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text),
        isEdit: true, // the record now exists (created above or already did)
        pendingImages: _pendingImages,
        pendingFiles: _pendingFiles,
        retained: retainedRefs,
        removed: removedRefs,
      );
      return;
    }

    // No inline images — unchanged path.
    await notifier.save(
      autoId: widget.automobileId,
      record: record,
      isEdit: widget.isEdit,
      pendingImages: _pendingImages,
      pendingFiles: _pendingFiles,
      retained: _savedRefs,
      removed: _removedRefs,
    );
```

Add the confirm dialog helper (mirrors the general editor's):
```dart
  Future<bool> _confirmRemoveInlineImages(int count) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove stored images?'),
        content: Text('You removed $count image${count == 1 ? '' : 's'} from '
            'the notes. Delete the stored image${count == 1 ? '' : 's'}, or '
            'keep ${count == 1 ? 'it' : 'them'} attached?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep attached')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    return res ?? false;
  }
```

`VaultRef` and `imageAttachmentPickerProvider` may need imports — add them if the analyzer flags (`../../../../core/data/attachments/attachment_ref.dart` is already imported; `../../../../core/data/attachments/attachment_providers.dart` is already imported for `attachmentResolverProvider`, which also exports `imageAttachmentPickerProvider`).

- [ ] **Step 4: Run to verify it passes + full suite + analyze**

Run: `cd ~/projects/hmm_console && flutter analyze && flutter test`
Expected: `No issues found!`; full suite green (the new inline-save test + all existing service-record and notes tests).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/automobile_records/presentation/screens/service_record_form_screen.dart test/features/automobile_records/service_record_inline_save_test.dart
git commit -m "feat(automobile): persist + reconcile inline images on service-record save

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (Phase 3):** shared base-note capability extracted (Task 1); general editor adopts it with no behavior change (Task 2); structured (service-record) editor gains inline images — insertion + preview + gallery dedup (Task 3) and persist/rewrite/reconcile/retention on save (Task 4). Detail display already renders inline images for any note via `NoteMarkdownBody` (the service-record form preview and the shared note-detail screen); no separate display task needed. Gas log / other editors explicitly deferred. ✓

**Placeholder scan:** Tasks 1–2 have complete code. Tasks 3–4 give complete implementation code plus test bodies described against the *named* existing harnesses (`service_record_form_edit_test.dart`, the service-record mutate tests) — the implementer writes those two tests out; all production code is concrete. ✓

**Type consistency:** `InlineImageController` API (`stageAndInsert`, `resolveAndRewrite` → `InlineResolveResult{newRefs, hadFailures}`, static `removedImagePaths`) is used identically in Tasks 2, 3, 4. The service-record save reuses `MutateServiceRecordState.create`/`save` verbatim (signatures quoted above); `persistToVault(noteId:, bytes:, originalName:, contentTypeHint:)` matches the picker. `.value` used throughout; no `.valueOrNull`. ✓

**Risk note (for the reviewer):** Task 4 is the integration-heavy one — the two-phase create-then-save for new records means two writes and two `mutateServiceRecordStateProvider` transitions; confirm the form's state listener (error/navigation) behaves correctly across both, and that `isEdit: true` on the second call is correct after the create.
