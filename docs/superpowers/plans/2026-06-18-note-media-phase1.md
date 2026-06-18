# Note Media — Phase 1 (Journal-style images) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show note images as Apple-Journal-style media cards in the editor and review screen, with image-first attach-on-save, a bottom media toolbar, and a shared tap-to-fullscreen viewer.

**Architecture:** A shared `showFullscreenImage` helper (extracted from the vehicle screen) and a shared `NoteMediaCardList` widget render large rounded image cards in both the editor and `NoteDetailScreen`. The editor holds picked images as in-state `PickedImageBytes` (via an injectable `ImageByteSource` seam) and attaches them to the note's vault on save (`MutateNote.attachImageBytes`). No data-model changes — uses the existing `NoteAttachments`/`VaultRef` vault.

**Tech Stack:** Flutter, Riverpod, `image_picker`, the existing attachments vault (`VaultImageAttachmentPicker`, `attachmentResolverProvider`, `AttachmentImage`).

**Spec:** `docs/superpowers/specs/2026-06-18-note-media-and-metadata-design.md` (Phase 1 only)

---

## File Structure

**Create:**
- `lib/core/data/attachments/widgets/fullscreen_image.dart` — `showFullscreenImage(context, ref)` shared viewer.
- `lib/core/data/attachments/picker/image_byte_source.dart` — `PickedImageBytes` + `ImageByteSource` seam + `imageByteSourceProvider`.
- `lib/features/notes/presentation/widgets/note_media_card_list.dart` — `NoteMediaCardList` (large rounded cards; readonly + editable modes).
- `lib/features/notes/presentation/widgets/media_toolbar.dart` — `MediaToolbar` (bottom round buttons).
- Test files mirrored under `test/...`.

**Modify:**
- `lib/core/data/attachments/picker/image_attachment_picker.dart` — expose `persistToVault` on the `IImageAttachmentPicker` interface.
- `lib/features/notes/states/mutate_note_state.dart` — add `attachImageBytes`.
- `lib/features/gas_log/presentation/screens/automobile_edit_screen.dart` — use the shared `showFullscreenImage`.
- `lib/features/notes/presentation/screens/note_editor_screen.dart` — pending picks, media card list, toolbar, attach-on-save.
- `lib/features/notes/presentation/screens/note_detail_screen.dart` — render media via `NoteMediaCardList` (tap → fullscreen).

---

## Task 1: Shared fullscreen image viewer

**Files:**
- Create: `lib/core/data/attachments/widgets/fullscreen_image.dart`
- Test: `test/core/data/attachments/widgets/fullscreen_image_test.dart`
- Modify: `lib/features/gas_log/presentation/screens/automobile_edit_screen.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/data/attachments/widgets/fullscreen_image_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';
import 'package:hmm_console/core/data/attachments/widgets/fullscreen_image.dart';

void main() {
  testWidgets('opens a zoomable dialog with the image', (t) async {
    const ref = VaultRef(path: 'attachments/note-1/a.jpg', contentType: 'image/jpeg', byteSize: 10);
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showFullscreenImage(ctx, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pump(); // open the dialog route
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(AttachmentImage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/attachments/widgets/fullscreen_image_test.dart`
Expected: FAIL — `fullscreen_image.dart` does not exist.

- [ ] **Step 3: Create the helper**

Create `lib/core/data/attachments/widgets/fullscreen_image.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../attachment_ref.dart';
import '../attachment_providers.dart';
import 'attachment_image.dart';

/// Opens [ref] full-screen in a zoomable, tap-to-dismiss dialog. Shared by the
/// note editor, the note review screen, and the vehicle screen so they all
/// view photos the same way.
void showFullscreenImage(BuildContext context, AttachmentRef ref) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => Consumer(builder: (context, ref2, _) {
      final resolverAsync = ref2.watch(attachmentResolverProvider);
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: resolverAsync.when(
              data: (resolver) => InteractiveViewer(
                child: AttachmentImage(ref: ref, resolver: resolver),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Could not load photo: $e',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      );
    }),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/attachments/widgets/fullscreen_image_test.dart`
Expected: PASS.

- [ ] **Step 5: Refactor the vehicle screen to use it**

In `lib/features/gas_log/presentation/screens/automobile_edit_screen.dart`, add the import:

```dart
import '../../../../core/data/attachments/widgets/fullscreen_image.dart';
```

Replace the body of the existing `_showFullscreenPhoto(AttachmentRef ref_)` method (the `showDialog<void>( … );` block) with a single delegating call:

```dart
  void _showFullscreenPhoto(AttachmentRef ref_) {
    showFullscreenImage(context, ref_);
  }
```

(Remove the now-unused local `showDialog`/`Dialog`/`InteractiveViewer` code in that method. If `AttachmentImage`/`attachmentResolverProvider` imports become unused in this file, leave them — they are used elsewhere in the screen for the inline photo.)

- [ ] **Step 6: Verify the vehicle screen still builds + tests pass**

Run: `flutter analyze lib/features/gas_log/presentation/screens/automobile_edit_screen.dart && flutter test test/core/data/attachments/widgets/fullscreen_image_test.dart`
Expected: analyze clean; test PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/data/attachments/widgets/fullscreen_image.dart \
        test/core/data/attachments/widgets/fullscreen_image_test.dart \
        lib/features/gas_log/presentation/screens/automobile_edit_screen.dart
git commit -m "feat(attachments): shared showFullscreenImage; vehicle screen reuses it"
```

---

## Task 2: Pick-bytes seam + attach-on-save mutation

**Files:**
- Create: `lib/core/data/attachments/picker/image_byte_source.dart`
- Test: `test/core/data/attachments/picker/image_byte_source_test.dart`
- Modify: `lib/core/data/attachments/picker/image_attachment_picker.dart`
- Modify: `lib/features/notes/states/mutate_note_state.dart`
- Test: `test/features/notes/states/attach_image_bytes_test.dart`

- [ ] **Step 1: Write the failing test for the byte source model**

Create `test/core/data/attachments/picker/image_byte_source_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';

void main() {
  test('PickedImageBytes holds bytes + metadata', () {
    final pick = PickedImageBytes(
      bytes: Uint8List.fromList([1, 2, 3]),
      originalName: 'photo.jpg',
      contentType: 'image/jpeg',
    );
    expect(pick.bytes.length, 3);
    expect(pick.originalName, 'photo.jpg');
    expect(pick.contentType, 'image/jpeg');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/data/attachments/picker/image_byte_source_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Create the byte-source seam**

Create `lib/core/data/attachments/picker/image_byte_source.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'image_attachment_picker.dart';

/// Raw picked image, held in editor state until the note is saved (then
/// persisted to the vault). Carries bytes so a thumbnail renders immediately.
class PickedImageBytes {
  PickedImageBytes({
    required this.bytes,
    required this.originalName,
    this.contentType,
  });
  final Uint8List bytes;
  final String originalName;
  final String? contentType;
}

/// Picks image bytes WITHOUT writing to the vault (no note id needed). The
/// editor uses this so a photo can be added before the note exists.
abstract interface class ImageByteSource {
  Future<PickedImageBytes?> pick(AttachmentPickSource source);
}

class ImagePickerByteSource implements ImageByteSource {
  ImagePickerByteSource({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source == AttachmentPickSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (picked == null) return null;
    return PickedImageBytes(
      bytes: await picked.readAsBytes(),
      originalName: p.basename(picked.path),
      contentType: picked.mimeType,
    );
  }
}

/// Overridable in tests to return canned bytes without the platform picker.
final imageByteSourceProvider =
    Provider<ImageByteSource>((ref) => ImagePickerByteSource());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/data/attachments/picker/image_byte_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Expose `persistToVault` on the picker interface**

In `lib/core/data/attachments/picker/image_attachment_picker.dart`, add the `persistToVault` signature to the `IImageAttachmentPicker` interface (the concrete `VaultImageAttachmentPicker` already implements it). Add the `dart:typed_data` import is already present. Change the interface to:

```dart
abstract interface class IImageAttachmentPicker {
  /// Open the platform picker. Returns null if the user cancels.
  /// Throws [AttachmentPickerException] for too-large files or
  /// unsupported types.
  Future<VaultRef?> pickForNote({
    required int noteId,
    AttachmentPickSource source = AttachmentPickSource.gallery,
  });

  /// Persist already-picked bytes into the vault for [noteId]. Used by the
  /// editor to attach images held in state once the note is saved.
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
  });
}
```

(No change needed to `VaultImageAttachmentPicker.persistToVault` — it already matches this signature; it just now formally implements the interface member.)

- [ ] **Step 6: Write the failing test for `attachImageBytes`**

Create `test/features/notes/states/attach_image_bytes_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

const _ref = VaultRef(
    path: 'attachments/note-1/a.jpg', contentType: 'image/jpeg', byteSize: 3);

class _FakePicker implements IImageAttachmentPicker {
  Uint8List? gotBytes;
  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
  }) async {
    gotBytes = bytes;
    return _ref;
  }

  @override
  Future<VaultRef?> pickForNote(
          {required int noteId, source = AttachmentPickSource.gallery}) async =>
      null;
}

class _FakeRepo implements IHmmNoteRepository {
  _FakeRepo(this.note);
  HmmNote note;
  NoteAttachments? written;
  @override
  Future<HmmNote?> getNoteById(int id) async => note;
  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    written = patch.attachments;
    return note;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('attachImageBytes persists + appends a VaultRef to the note', () async {
    final picker = _FakePicker();
    final repo = _FakeRepo(HmmNote(
        id: 1, uuid: 'u', subject: 's', authorId: 1,
        createDate: DateTime(2026, 1, 1)));
    final container = ProviderContainer(overrides: [
      imageAttachmentPickerProvider.overrideWith((ref) async => picker),
      hmmNoteRepositoryProvider.overrideWith((ref) => repo),
    ]);
    addTearDown(container.dispose);

    final mutate = container.read(mutateNoteProvider);
    await mutate.attachImageBytes(
      1,
      PickedImageBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          originalName: 'a.jpg',
          contentType: 'image/jpeg'),
    );

    expect(picker.gotBytes, isNotNull);
    expect(repo.written, isNotNull);
    expect(repo.written!.primaryImage, _ref); // first image becomes primary
  });
}
```

- [ ] **Step 7: Run it to verify it fails**

Run: `flutter test test/features/notes/states/attach_image_bytes_test.dart`
Expected: FAIL — `attachImageBytes` is not defined on `MutateNote`.

- [ ] **Step 8: Implement `attachImageBytes`**

In `lib/features/notes/states/mutate_note_state.dart`, add the import:

```dart
import '../../../core/data/attachments/picker/image_byte_source.dart';
```

Add this method to the `MutateNote` class (after `addImage`):

```dart
  /// Persist already-picked [pick] bytes into the note's vault and append the
  /// resulting VaultRef to the note's attachments (first image becomes the
  /// primary). Used by the editor's attach-on-save flow.
  Future<HmmNote?> attachImageBytes(int noteId, PickedImageBytes pick) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    final added = await picker.persistToVault(
      noteId: noteId,
      bytes: pick.bytes,
      originalName: pick.originalName,
      contentTypeHint: pick.contentType,
    );
    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current == null) return null;
    final existing = current.effectiveAttachments;
    final updated = NoteAttachments(
      primaryImage: existing.primaryImage ?? added,
      images: existing.primaryImage == null
          ? existing.images
          : [...existing.images, added],
    );
    return repo.updateNote(noteId, HmmNoteUpdate(attachments: updated));
  }
```

Confirm `mutate_note_state.dart` already imports `attachment_ref.dart` (it does, via `attachment_providers.dart` / `image_attachment_picker.dart`); `NoteAttachments` is in `attachment_ref.dart`. If `NoteAttachments` is not resolvable, add `import '../../../core/data/attachments/attachment_ref.dart';`.

- [ ] **Step 9: Run tests to verify they pass**

Run: `flutter test test/features/notes/states/attach_image_bytes_test.dart test/core/data/attachments/picker/image_byte_source_test.dart && flutter analyze lib/core/data/attachments/ lib/features/notes/states/mutate_note_state.dart`
Expected: PASS; analyze clean.

- [ ] **Step 10: Commit**

```bash
git add lib/core/data/attachments/picker/image_byte_source.dart \
        test/core/data/attachments/picker/image_byte_source_test.dart \
        lib/core/data/attachments/picker/image_attachment_picker.dart \
        lib/features/notes/states/mutate_note_state.dart \
        test/features/notes/states/attach_image_bytes_test.dart
git commit -m "feat(notes): pick-bytes seam + MutateNote.attachImageBytes (attach-on-save)"
```

---

## Task 3: NoteMediaCardList widget

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_media_card_list.dart`
- Test: `test/features/notes/presentation/widgets/note_media_card_list_test.dart`

> Renders a vertical list of large rounded image cards (Journal style). Two
> input lists: saved attachments (`AttachmentRef`, rendered via the resolver)
> and pending picks (`PickedImageBytes`, rendered from local bytes with a ✕).
> Readonly mode: tap a saved card → fullscreen; no ✕.

- [ ] **Step 1: Write the failing test**

Create `test/features/notes/presentation/widgets/note_media_card_list_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_media_card_list.dart';

PickedImageBytes _pick() => PickedImageBytes(
    bytes: Uint8List.fromList(List.filled(8, 0)), originalName: 'a.jpg');

void main() {
  testWidgets('renders one card per pending pick with a remove button',
      (t) async {
    var removed = -1;
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: NoteMediaCardList(
            saved: const [],
            pending: [_pick(), _pick()],
            onRemovePending: (i) => removed = i,
          ),
        ),
      ),
    ));
    expect(find.byType(NoteMediaCard), findsNWidgets(2));
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    await t.tap(find.byIcon(Icons.close).first);
    expect(removed, 0);
  });

  testWidgets('readonly (no pending) shows no remove buttons', (t) async {
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: NoteMediaCardList(saved: const [], pending: [_pick()], readOnly: true),
        ),
      ),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/widgets/note_media_card_list_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/features/notes/presentation/widgets/note_media_card_list.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/attachments/widgets/fullscreen_image.dart';

/// Apple-Journal-style media: large rounded image cards. Shows saved
/// attachments (resolved from the vault) and pending picks (from local bytes).
class NoteMediaCardList extends StatelessWidget {
  const NoteMediaCardList({
    super.key,
    required this.saved,
    this.pending = const [],
    this.onRemovePending,
    this.readOnly = false,
  });

  final List<AttachmentRef> saved;
  final List<PickedImageBytes> pending;
  final void Function(int index)? onRemovePending;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      for (final ref in saved)
        NoteMediaCard(
          child: _SavedImage(ref: ref),
          onTap: () => showFullscreenImage(context, ref),
        ),
      for (var i = 0; i < pending.length; i++)
        NoteMediaCard(
          child: Image.memory(pending[i].bytes,
              fit: BoxFit.cover, width: double.infinity),
          onRemove:
              readOnly ? null : () => onRemovePending?.call(i),
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final c in cards) Padding(padding: const EdgeInsets.only(top: 12), child: c)],
    );
  }
}

/// One rounded media card with an optional remove (✕) and tap handler.
class NoteMediaCard extends StatelessWidget {
  const NoteMediaCard({super.key, required this.child, this.onTap, this.onRemove});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(height: 180, width: double.infinity, child: child),
          ),
        ),
        if (onRemove != null)
          PositionedDirectional(
            top: 8, end: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 13, backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _SavedImage extends ConsumerWidget {
  const _SavedImage({required this.ref});
  final AttachmentRef ref;
  @override
  Widget build(BuildContext context, WidgetRef wref) {
    final resolverAsync = wref.watch(attachmentResolverProvider);
    return resolverAsync.when(
      data: (resolver) =>
          AttachmentImage(ref: ref, resolver: resolver, fit: BoxFit.cover),
      loading: () => const ColoredBox(
          color: Color(0xFFF2F2F7),
          child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const ColoredBox(
          color: Color(0xFFF2F2F7), child: Icon(Icons.broken_image_outlined)),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/widgets/note_media_card_list_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/widgets/note_media_card_list.dart \
        test/features/notes/presentation/widgets/note_media_card_list_test.dart
git commit -m "feat(notes): NoteMediaCardList — Journal-style image cards"
```

---

## Task 4: MediaToolbar widget

**Files:**
- Create: `lib/features/notes/presentation/widgets/media_toolbar.dart`
- Test: `test/features/notes/presentation/widgets/media_toolbar_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notes/presentation/widgets/media_toolbar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/features/notes/presentation/widgets/media_toolbar.dart';

void main() {
  testWidgets('photo + camera buttons fire onPick with the right source',
      (t) async {
    AttachmentPickSource? picked;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: MediaToolbar(onPick: (s) => picked = s),
      ),
    ));
    await t.tap(find.byIcon(Icons.photo_library_outlined));
    expect(picked, AttachmentPickSource.gallery);
    await t.tap(find.byIcon(Icons.camera_alt_outlined));
    expect(picked, AttachmentPickSource.camera);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/widgets/media_toolbar_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/features/notes/presentation/widgets/media_toolbar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/data/attachments/picker/image_attachment_picker.dart';
import '../../../../core/theme/app_colors.dart';

/// Bottom media toolbar (Apple-Journal style). Phase 1: Photos + Camera. More
/// buttons (voice, location, PDF) are added in later phases.
class MediaToolbar extends StatelessWidget {
  const MediaToolbar({super.key, required this.onPick, this.enabled = true});

  final void Function(AttachmentPickSource source) onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    Widget btn(IconData icon, AttachmentPickSource source) => IconButton(
          icon: Icon(icon),
          color: c.accent,
          onPressed: enabled ? () => onPick(source) : null,
        );
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: c.groupedBackground,
          border: Border(top: BorderSide(color: c.separator)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            btn(Icons.photo_library_outlined, AttachmentPickSource.gallery),
            btn(Icons.camera_alt_outlined, AttachmentPickSource.camera),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/widgets/media_toolbar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/widgets/media_toolbar.dart \
        test/features/notes/presentation/widgets/media_toolbar_test.dart
git commit -m "feat(notes): MediaToolbar (photo + camera)"
```

---

## Task 5: Editor integration — image-first + media cards + toolbar

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Test: `test/features/notes/presentation/note_editor_media_test.dart`

> The editor keeps everything (subsystem strip, title, date, divider, body) and
> adds: `_pendingPicks` state, a `NoteMediaCardList` between the divider and the
> body (saved attachments + pending picks), a `MediaToolbar` at the bottom, and
> attach-on-save. The nav photo `IconButton` is removed (the toolbar replaces
> it). Subject is still required to save; the message is generic.

- [ ] **Step 1: Write the failing test**

Create `test/features/notes/presentation/note_editor_media_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_media_card_list.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';

class _FakeSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(
          bytes: Uint8List.fromList(List.filled(8, 0)), originalName: 'a.jpg');
}

class _FakeMutate implements MutateNote {
  int attachCalls = 0;
  @override
  Future<HmmNote> createGeneral(
      {required String subject, String? markdownBody, int? parentNoteId}) async {
    return HmmNote(id: 1, uuid: 'u', subject: subject, authorId: 1,
        createDate: DateTime(2026, 1, 1));
  }

  @override
  Future<HmmNote?> attachImageBytes(int noteId, PickedImageBytes pick) async {
    attachCalls++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('add photo shows a pending card before save; save attaches it',
      (tester) async {
    final fake = _FakeMutate();
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(path: 'editor', builder: (c, s) => const NoteEditorScreen()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mutateNoteProvider.overrideWithValue(fake),
        imageByteSourceProvider.overrideWithValue(_FakeSource()),
        subsystemAnchorsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: const [AppColors.light]),
      ),
    ));
    await tester.pumpAndSettle();

    // Add a photo (gallery) — no subject yet.
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(NoteMediaCard), findsOneWidget); // pending card shown

    // Enter subject and save → the pending pick is attached.
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Hello');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(fake.attachCalls, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/note_editor_media_test.dart`
Expected: FAIL — the editor has no MediaToolbar / pending cards yet (no `photo_library_outlined` icon, etc.).

- [ ] **Step 3: Edit `note_editor_screen.dart`**

Add imports (with the existing ones):

```dart
import '../../../../core/data/attachments/picker/image_attachment_picker.dart'
    show AttachmentPickSource;
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../widgets/media_toolbar.dart';
import '../widgets/note_media_card_list.dart';
```

In `_NoteEditorScreenState`, add state + the existing attachments list:

```dart
  final List<PickedImageBytes> _pendingPicks = [];
  List<AttachmentRef> _savedImages = [];
```

(Add `import '../../../../core/data/attachments/attachment_ref.dart';` for `AttachmentRef`.)

In `_loadExisting`, after setting subject/body, populate `_savedImages` from the note's attachments:

```dart
      _savedImages = [
        if (note.effectiveAttachments.primaryImage != null)
          note.effectiveAttachments.primaryImage!,
        ...note.effectiveAttachments.images,
      ];
```

Add the pick handler:

```dart
  Future<void> _addMedia(AttachmentPickSource source) async {
    final pick = await ref.read(imageByteSourceProvider).pick(source);
    if (pick != null && mounted) {
      setState(() => _pendingPicks.add(pick));
    }
  }
```

Replace the OLD `_addImage` method entirely (it is no longer used) and replace the nav `_buildNav` "Add image" `CupertinoButton`/`IconButton` so the nav has ONLY the Save button. In `_buildNav`, delete the image button from BOTH the apple and material branches (keep only Save). In the apple branch the `trailing` becomes just the Save `CupertinoButton`; in the material branch `actions` becomes just the Save `TextButton`.

In `_save`, after the note is created/updated and BEFORE `return _noteId;`, attach pending picks:

```dart
      // Attach any photos added this session, then clear them.
      if (_pendingPicks.isNotEmpty && _noteId != null) {
        for (final pick in _pendingPicks) {
          await mutate.attachImageBytes(_noteId!, pick);
        }
        if (mounted) setState(() => _pendingPicks.clear());
        ref.invalidate(noteDetailProvider(_noteId!));
      }
```

In `build`, add the media card list between the divider and the body `Expanded`, and add the toolbar as the Scaffold's bottom bar. Specifically, inside the page `Column` (after the `Divider` + its trailing `SizedBox`), insert:

```dart
                    NoteMediaCardList(
                      saved: _savedImages,
                      pending: _pendingPicks,
                      onRemovePending: (i) =>
                          setState(() => _pendingPicks.removeAt(i)),
                    ),
```

And give the `Scaffold` a bottom toolbar — change the `Scaffold(...)` in `build` to include:

```dart
      bottomNavigationBar: MediaToolbar(
        onPick: _busy ? (_) {} : _addMedia,
        enabled: !_busy,
      ),
```

(The `_addMedia` signature matches `void Function(AttachmentPickSource)`.)

- [ ] **Step 4: Run the editor tests**

Run: `flutter test test/features/notes/presentation/note_editor_media_test.dart test/features/notes/presentation/note_editor_screen_test.dart test/features/notes/presentation/note_editor_parent_test.dart test/features/notes/presentation/note_editor_attach_test.dart`
Expected: all PASS. (The existing editor tests don't tap the old image button, so removing it doesn't break them. If `note_editor_attach_test`/`note_editor_screen_test` reference the removed image `IconButton`, they don't — they only use 'Save' and the 'Title' field.)

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/notes/presentation/screens/note_editor_screen.dart`
Expected: clean. (If `_addImage`/`AttachmentPickerException` imports are now unused, remove them.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/notes/presentation/screens/note_editor_screen.dart \
        test/features/notes/presentation/note_editor_media_test.dart
git commit -m "feat(notes): editor media — image-first picks, cards, bottom toolbar, attach-on-save"
```

---

## Task 6: Review screen — media cards + tap-to-fullscreen

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart`
- Test: `test/features/notes/presentation/note_detail_media_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/notes/presentation/note_detail_media_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_media_card_list.dart';

void main() {
  testWidgets('detail renders attachments as media cards', (tester) async {
    final note = HmmNote(
      id: 1, uuid: 'u', subject: 'Car', authorId: 1,
      createDate: DateTime(2026, 1, 1),
      attachments: NoteAttachments(primaryImage: const VaultRef(
          path: 'attachments/note-1/a.jpg', contentType: 'image/jpeg', byteSize: 9)),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        noteDetailProvider(1).overrideWith(
            (ref) async => NoteDetailData(note, null)),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const NoteDetailScreen(noteId: 1),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NoteMediaCardList), findsOneWidget);
    expect(find.byType(NoteMediaCard), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/note_detail_media_test.dart`
Expected: FAIL — the detail screen still uses `AttachmentGallery`, not `NoteMediaCardList`.

- [ ] **Step 3: Edit `note_detail_screen.dart`**

Replace the import of the gallery:

```dart
import '../widgets/note_media_card_list.dart';
```

(Remove `import '../widgets/attachment_gallery.dart';`.)

In the `data:` builder, replace the attachments block:

```dart
                  if (atts.isNotEmpty) ...[
                    AttachmentGallery(refs: atts),
                    const SizedBox(height: 12),
                  ],
```

with:

```dart
                  if (atts.isNotEmpty)
                    NoteMediaCardList(saved: atts, readOnly: true),
```

(The leading `SizedBox(height: 12)` is no longer needed — `NoteMediaCardList` pads each card with a top margin.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/notes/presentation/note_detail_media_test.dart && flutter analyze lib/features/notes/presentation/screens/note_detail_screen.dart`
Expected: PASS; analyze clean.

- [ ] **Step 5: Remove the now-unused gallery (only if no other referrers)**

Run: `grep -rn "AttachmentGallery" lib/ test/`
If the only references are the (now-removed) detail import and `attachment_gallery.dart` itself + its test, delete them:

```bash
git rm lib/features/notes/presentation/widgets/attachment_gallery.dart
# remove its test if one exists:
test -f test/features/notes/presentation/widgets/attachment_gallery_test.dart && git rm test/features/notes/presentation/widgets/attachment_gallery_test.dart || true
```

If anything else still imports it, leave it in place and skip this step.

- [ ] **Step 6: Commit**

```bash
git add lib/features/notes/presentation/screens/note_detail_screen.dart \
        test/features/notes/presentation/note_detail_media_test.dart
git commit -m "feat(notes): review screen uses NoteMediaCardList (tap → fullscreen)"
```

---

## Task 7: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Analyze the whole project**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS (incl. the new media tests and all pre-existing tests).

- [ ] **Step 3: On-device eyeball (iOS sim)**

Run: `flutter run -d <booted-sim-id>`. Manually verify on the Notes feature:
- New note → tap the **photo** button in the bottom toolbar → a media card appears immediately (before any save/subject).
- Type a subject → Save → reopen the note → the image shows as a large card.
- Tap the card → fullscreen, pinch-zoom, tap to dismiss.
- Vehicle screen photo still opens fullscreen (shared viewer regression check).

Expected: matches the Journal-style spec; no overflow.

- [ ] **Step 4: Commit any polish fixes**

```bash
git add -A
git commit -m "fix(notes): media polish from on-device verification"
```

---

## Self-Review Notes

- **Spec coverage:** I1 (image-first attach-on-save, Task 2/5) · I2 (media cards in editor, Task 3/5) · I3 (tap → fullscreen, Task 1/6) · media toolbar (Task 4/5) · keep subsystem strip (Task 5 preserves it) · shared viewer reused by vehicle (Task 1). Phase 2/3 intentionally excluded.
- **Type consistency:** `PickedImageBytes`, `ImageByteSource`/`imageByteSourceProvider`, `MutateNote.attachImageBytes`, `NoteMediaCardList`/`NoteMediaCard`, `MediaToolbar`, `showFullscreenImage`, `persistToVault` (interface) are used identically across tasks.
- **No new deps.** Uses existing `image_picker` + vault.
