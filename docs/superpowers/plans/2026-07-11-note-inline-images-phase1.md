# Inline Note Images (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user place images inline in a general note's Markdown body (OneNote-style), with the note content staying a plain-text Markdown string and image bytes staying in the vault.

**Architecture:** Inline images are standard Markdown images whose URL is a custom `hmm-attachment://<vault-path>` URI (pending picks use `hmm-attachment://pending/<uuid>`). A shared `NoteMarkdownBody` widget renders them via `flutter_markdown`'s `sizedImageBuilder`, resolving the URI to bytes through the existing `AttachmentImage` + resolver (or a staged-bytes map for unsaved picks). The editor inserts a pending placeholder at the cursor, stages bytes in memory, and on save persists each referenced pick to the vault and rewrites the placeholder to the real vault path. Retention is confirmation-gated: an image referenced inline is retained in the note's `attachments` column (so `vault_gc` never deletes it); removing an inline image on save prompts before dropping it.

**Tech Stack:** Flutter, Riverpod, Drift, `flutter_markdown ^0.7.7+1` (use the non-deprecated `sizedImageBuilder`), existing vault/attachment layer.

**Scope:** This is **Phase 1** of the umbrella spec `docs/superpowers/specs/2026-07-11-note-inline-refs-and-secure-attachments-design.md`. Images only, **general notes** (catalog `kGeneralCatalogName`), tiers `local` + `cloudStorage`. Links (`hmm-note://`), structured-note surfacing, and sensitive/encrypted attachments are later phases and are **out of scope here**.

## Global Constraints

- Note content stays a **plain-text Markdown string**; no binary, no base64 in content.
- Inline image URI scheme is exactly **`hmm-attachment://`**; pending form is **`hmm-attachment://pending/<uuid>`**. Vault path segment is the existing `VaultRef.path` (e.g. `attachments/note-123/photo.jpg`).
- Use `flutter_markdown`'s **`sizedImageBuilder`** (the `imageBuilder` param is `@Deprecated`); the two are mutually exclusive.
- Inline images render the **whole image** (`BoxFit.contain`), scaled to the column width, capped at **`maxHeight = 360.0`**, tap → `showFullscreenImage`.
- **Retention is confirmation-gated:** a stored image is never dropped from `attachments` as a silent side effect of editing text.
- Only `VaultRef` images are inline-eligible. `VaultResolver` resolves by `path` only — a render-only `VaultRef` may use placeholder `contentType`/`byteSize`.
- Follow existing test patterns: pure Dart unit tests; widget tests with a fake `IAttachmentResolver`; repo/integration tests with `HmmDatabase(NativeDatabase.memory())`.

**Reference signatures (verified against the codebase — do not re-derive):**

```dart
// lib/core/data/attachments/attachment_ref.dart
final class VaultRef extends AttachmentRef {
  const VaultRef({required this.path, this.originalName,
                  required this.contentType, required this.byteSize});
  final String path; final String? originalName;
  final String contentType; final int byteSize;
}
class NoteAttachments {
  NoteAttachments({this.primaryImage,
                   List<AttachmentRef> images = const [],
                   List<AttachmentRef> files = const []});
  static final NoteAttachments empty = NoteAttachments();
  final AttachmentRef? primaryImage;
  final List<AttachmentRef> images; final List<AttachmentRef> files;
  bool get isEmpty; bool get isNotEmpty;
}

// lib/core/data/attachments/resolver/attachment_resolver.dart
abstract interface class IAttachmentResolver { Future<Uint8List?> resolve(AttachmentRef ref); }

// lib/core/data/attachments/attachment_providers.dart
final attachmentResolverProvider = FutureProvider<IAttachmentResolver>(...); // AsyncValue<IAttachmentResolver>
final imageAttachmentPickerProvider = /* FutureProvider<IImageAttachmentPicker> */;
// lib/core/data/attachments/picker/image_attachment_picker.dart
Future<VaultRef> persistToVault({required int noteId, required Uint8List bytes,
    required String originalName, String? contentTypeHint});

// lib/core/data/attachments/widgets/attachment_image.dart
const AttachmentImage({required this.ref, required this.resolver, super.key,
  this.fit = BoxFit.cover, this.alignment = Alignment.center,
  this.loadingPlaceholder, this.errorPlaceholder, this.semanticLabel});
// lib/core/data/attachments/widgets/fullscreen_image.dart
void showFullscreenImage(BuildContext context, AttachmentRef ref);

// lib/core/util/uuid.dart
String generateUuid();

// lib/core/data/attachments/picker/image_byte_source.dart
class PickedImageBytes { PickedImageBytes({required this.bytes,
  required this.originalName, this.contentType});
  final Uint8List bytes; final String originalName; final String? contentType; }
final imageByteSourceProvider = Provider<ImageByteSource>(...);
// ImageByteSource: Future<PickedImageBytes?> pick(AttachmentPickSource source);

// lib/features/notes/states/mutate_note_state.dart
final mutateNoteProvider = Provider<MutateNote>((ref) => MutateNote(ref));
// MutateNote.createGeneral({required String subject, String? markdownBody, int? parentNoteId, DateTime? noteDate, NoteLocation? location}) -> Future<HmmNote>
// MutateNote.updateGeneral(int id, {String? subject, String? markdownBody, DateTime? noteDate, NoteLocation? location}) -> Future<HmmNote>
// MutateNote.attachImageBytes(int noteId, PickedImageBytes pick) -> Future<HmmNote?>

// flutter_markdown 0.7.7+1 (lib/src/builder.dart)
typedef MarkdownSizedImageBuilder = Widget Function(MarkdownImageConfig config);
class MarkdownImageConfig { final Uri uri; final String? title; final String? alt;
  final double? width; final double? height; }
```

---

### Task 1: Inline-reference URI codec

**Files:**
- Create: `lib/core/data/attachments/inline_ref_uri.dart`
- Test: `test/core/data/attachments/inline_ref_uri_test.dart`

**Interfaces:**
- Produces:
  - `String formatImageUri(String vaultPath)` → `'hmm-attachment://<vaultPath>'`
  - `String? parseImageUri(String uri)` → vault path for a real (non-pending) image URI, else `null`
  - `String formatPendingUri(String uuid)` → `'hmm-attachment://pending/<uuid>'`
  - `String? pendingUuidOf(String uri)` → uuid for a pending URI, else `null`
  - `List<String> imageRefPathsIn(String markdown)` → all real inline image vault paths
  - `List<String> pendingUuidsIn(String markdown)` → all pending uuids referenced inline
  - `String rewritePendingToVault(String markdown, Map<String, String> uuidToPath)`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/data/attachments/inline_ref_uri_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/inline_ref_uri.dart';

void main() {
  test('format/parse real image uri round-trips the vault path', () {
    const path = 'attachments/note-123/Login.png';
    final uri = formatImageUri(path);
    expect(uri, 'hmm-attachment://attachments/note-123/Login.png');
    expect(parseImageUri(uri), path);
  });

  test('pending uri round-trips the uuid', () {
    final uri = formatPendingUri('abc-1');
    expect(uri, 'hmm-attachment://pending/abc-1');
    expect(pendingUuidOf(uri), 'abc-1');
    expect(parseImageUri(uri), isNull); // pending is not a real image path
  });

  test('non-attachment / malformed uris return null', () {
    expect(parseImageUri('https://example.com/x.png'), isNull);
    expect(parseImageUri('hmm-note://uuid-1'), isNull);
    expect(pendingUuidOf('hmm-attachment://attachments/note-1/x.png'), isNull);
  });

  test('imageRefPathsIn and pendingUuidsIn extract inline refs', () {
    const md = 'a\n\n![x](hmm-attachment://attachments/note-1/a.png)\n\n'
        'b ![y](hmm-attachment://pending/u9) c\n'
        '![z](https://ext/x.png)';
    expect(imageRefPathsIn(md), ['attachments/note-1/a.png']);
    expect(pendingUuidsIn(md), ['u9']);
  });

  test('rewritePendingToVault replaces pending uris with real image uris', () {
    const md = '![y](hmm-attachment://pending/u9) and text';
    final out = rewritePendingToVault(md, {'u9': 'attachments/note-5/y.png'});
    expect(out, '![y](hmm-attachment://attachments/note-5/y.png) and text');
    expect(pendingUuidsIn(out), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/data/attachments/inline_ref_uri_test.dart`
Expected: FAIL — target library/functions don't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/data/attachments/inline_ref_uri.dart

/// Custom URI scheme for inline note images. The content string carries only
/// these text placeholders; the bytes stay in the vault.
const String _scheme = 'hmm-attachment://';
const String _pendingPrefix = 'pending/';

/// `attachments/note-1/x.png` -> `hmm-attachment://attachments/note-1/x.png`.
String formatImageUri(String vaultPath) => '$_scheme$vaultPath';

/// The vault path for a real (non-pending) image URI, else null.
String? parseImageUri(String uri) {
  if (!uri.startsWith(_scheme)) return null;
  final rest = uri.substring(_scheme.length);
  if (rest.isEmpty || rest.startsWith(_pendingPrefix)) return null;
  return rest;
}

/// `abc` -> `hmm-attachment://pending/abc`.
String formatPendingUri(String uuid) => '$_scheme$_pendingPrefix$uuid';

/// The uuid for a pending URI, else null.
String? pendingUuidOf(String uri) {
  if (!uri.startsWith(_scheme)) return null;
  final rest = uri.substring(_scheme.length);
  if (!rest.startsWith(_pendingPrefix)) return null;
  final uuid = rest.substring(_pendingPrefix.length);
  return uuid.isEmpty ? null : uuid;
}

// Markdown image: ![alt](url) — capture the url.
final RegExp _imageMd = RegExp(r'!\[[^\]]*\]\(([^)]+)\)');

Iterable<String> _inlineUrls(String markdown) =>
    _imageMd.allMatches(markdown).map((m) => m.group(1)!);

/// All real inline image vault paths, in document order.
List<String> imageRefPathsIn(String markdown) => _inlineUrls(markdown)
    .map(parseImageUri)
    .whereType<String>()
    .toList();

/// All pending uuids referenced inline, in document order.
List<String> pendingUuidsIn(String markdown) => _inlineUrls(markdown)
    .map(pendingUuidOf)
    .whereType<String>()
    .toList();

/// Replace every `pending/<uuid>` image URI with its real vault image URI.
String rewritePendingToVault(String markdown, Map<String, String> uuidToPath) {
  var out = markdown;
  uuidToPath.forEach((uuid, path) {
    out = out.replaceAll(formatPendingUri(uuid), formatImageUri(path));
  });
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/core/data/attachments/inline_ref_uri_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/core/data/attachments/inline_ref_uri.dart test/core/data/attachments/inline_ref_uri_test.dart
git commit -m "feat(notes): inline image URI codec (hmm-attachment scheme)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Shared `NoteMarkdownBody` renderer + `MarkdownView` delegate

**Files:**
- Create: `lib/features/notes/presentation/widgets/note_markdown_body.dart`
- Modify: `lib/features/notes/presentation/widgets/markdown_view.dart` (reimplement to delegate)
- Test: `test/features/notes/presentation/widgets/note_markdown_body_test.dart`

**Interfaces:**
- Consumes: `parseImageUri`, `pendingUuidOf` (Task 1); `AttachmentImage`, `IAttachmentResolver`, `showFullscreenImage`.
- Produces:
  - `NoteMarkdownBody({required String data, IAttachmentResolver? resolver, Map<String, Uint8List>? pendingBytes, bool selectable = true})`
  - `MarkdownView(String data)` unchanged for callers (now a `ConsumerWidget` that supplies the resolver).
  - `const double kInlineImageMaxHeight = 360.0;`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/widgets/note_markdown_body_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_markdown_body.dart';

class _FakeResolver implements IAttachmentResolver {
  const _FakeResolver(this.bytes);
  final Uint8List? bytes;
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => bytes;
}

// Smallest valid PNG.
final Uint8List _png = Uint8List.fromList(<int>[
  0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,0,0,0,0x0D,0x49,0x48,0x44,0x52,
  0,0,0,1,0,0,0,1,8,6,0,0,0,0x1F,0x15,0xC4,0x89,0,0,0,0x0A,0x49,0x44,0x41,
  0x54,0x78,0x9C,0x63,0,1,0,0,5,0,1,0x0D,0x0A,0x2D,0xB4,0,0,0,0,0x49,0x45,
  0x4E,0x44,0xAE,0x42,0x60,0x82,
]);

void main() {
  testWidgets('renders a real inline image via the resolver', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(
          data: '![x](hmm-attachment://attachments/note-1/a.png)',
          resolver: _FakeResolver(_png),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders a pending inline image from the staged bytes map',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteMarkdownBody(
          data: '![x](hmm-attachment://pending/u1)',
          pendingBytes: {'u1': _png},
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders plain markdown text with no inline image', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NoteMarkdownBody(data: 'hello **world**')),
    ));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/note_markdown_body_test.dart`
Expected: FAIL — `NoteMarkdownBody` doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/notes/presentation/widgets/note_markdown_body.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/attachments/widgets/fullscreen_image.dart';

/// Max on-screen height of an inline image; the whole image scales to the
/// column width and is capped here so a tall image doesn't dominate.
const double kInlineImageMaxHeight = 360.0;

/// Renders a Markdown [data] string, resolving `hmm-attachment://` image URIs
/// to inline images (whole image, fit-to-width, tap → fullscreen). Unsaved
/// picks resolve from [pendingBytes] (uuid → bytes).
class NoteMarkdownBody extends StatelessWidget {
  const NoteMarkdownBody({
    super.key,
    required this.data,
    this.resolver,
    this.pendingBytes,
    this.selectable = true,
  });

  final String data;
  final IAttachmentResolver? resolver;
  final Map<String, Uint8List>? pendingBytes;
  final bool selectable;

  Widget _box(Widget child) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: kInlineImageMaxHeight),
        child: child,
      );

  Widget _placeholder() => _box(
        const ColoredBox(
          color: Color(0xFFF2F2F7),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );

  Widget _buildImage(BuildContext context, MarkdownImageConfig config) {
    final url = config.uri.toString();

    final pendingUuid = pendingUuidOf(url);
    if (pendingUuid != null) {
      final bytes = pendingBytes?[pendingUuid];
      if (bytes == null) return _placeholder();
      return _box(Image.memory(bytes,
          fit: BoxFit.contain, alignment: Alignment.topCenter));
    }

    final path = parseImageUri(url);
    if (path != null && resolver != null) {
      // Render-only ref: VaultResolver resolves by path; the other fields are
      // unused for display.
      final ref = VaultRef(
          path: path, contentType: 'application/octet-stream', byteSize: 0);
      return _box(GestureDetector(
        onTap: () => showFullscreenImage(context, ref),
        child: AttachmentImage(
          ref: ref,
          resolver: resolver!,
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          semanticLabel: config.alt,
        ),
      ));
    }

    return _placeholder();
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      sizedImageBuilder: (config) => _buildImage(context, config),
    );
  }
}

/// Backwards-compatible read-only Markdown view. Existing call sites use
/// `MarkdownView(markdown)`; it now resolves inline images too.
class MarkdownView extends ConsumerWidget {
  const MarkdownView(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(attachmentResolverProvider).valueOrNull;
    return NoteMarkdownBody(data: data, resolver: resolver);
  }
}
```

Note: delete the old `MarkdownView` body in `markdown_view.dart` and replace its file contents with a re-export so both the old path and the new widget resolve to one definition:

```dart
// lib/features/notes/presentation/widgets/markdown_view.dart
export 'note_markdown_body.dart' show MarkdownView, NoteMarkdownBody;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/note_markdown_body_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run the existing markdown/detail tests + analyze**

Run: `cd ~/projects/hmm_console && flutter analyze lib/features/notes && flutter test test/features/notes`
Expected: `No issues found!`; existing note tests still pass (the `MarkdownView(markdown)` call sites compile via the re-export).

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/widgets/note_markdown_body.dart lib/features/notes/presentation/widgets/markdown_view.dart test/features/notes/presentation/widgets/note_markdown_body_test.dart
git commit -m "feat(notes): NoteMarkdownBody renders inline hmm-attachment images

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Insert-at-cursor helper

**Files:**
- Create: `lib/features/notes/presentation/widgets/inline_insert.dart`
- Test: `test/features/notes/presentation/widgets/inline_insert_test.dart`

**Interfaces:**
- Consumes: `formatPendingUri` (Task 1).
- Produces: `void insertImageAtCursor(TextEditingController c, String uuid, String alt)` — inserts `\n\n![alt](hmm-attachment://pending/<uuid>)\n\n` at the caret (or appends if no valid selection), leaving the caret after the inserted block.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/widgets/inline_insert_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/inline_insert.dart';

void main() {
  test('inserts a pending image at the caret and moves the caret past it', () {
    final c = TextEditingController(text: 'ABCD');
    c.selection = const TextSelection.collapsed(offset: 2); // between B and C
    insertImageAtCursor(c, 'u1', 'photo.png');
    expect(c.text,
        'AB\n\n![photo.png](hmm-attachment://pending/u1)\n\nCD');
    // caret sits right after the inserted block (before "CD")
    expect(c.selection.baseOffset, 'AB\n\n![photo.png](hmm-attachment://pending/u1)\n\n'.length);
  });

  test('appends when there is no valid selection', () {
    final c = TextEditingController(text: 'X');
    // default selection is -1 (invalid)
    insertImageAtCursor(c, 'u2', 'a.png');
    expect(c.text, 'X\n\n![a.png](hmm-attachment://pending/u2)\n\n');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/inline_insert_test.dart`
Expected: FAIL — function doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/notes/presentation/widgets/inline_insert.dart
import 'package:flutter/widgets.dart';

import '../../../../core/data/attachments/inline_ref_uri.dart';

/// Inserts a pending inline-image placeholder at the controller's caret,
/// surrounded by blank lines so Markdown renders it as its own block. The
/// caret is left immediately after the inserted block.
void insertImageAtCursor(
    TextEditingController controller, String uuid, String alt) {
  final block = '\n\n![$alt](${formatPendingUri(uuid)})\n\n';
  final text = controller.text;
  final sel = controller.selection;
  final at = (sel.isValid && sel.start >= 0) ? sel.start : text.length;

  final next = text.substring(0, at) + block + text.substring(at);
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: at + block.length),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/inline_insert_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/widgets/inline_insert.dart test/features/notes/presentation/widgets/inline_insert_test.dart
git commit -m "feat(notes): insert-at-cursor helper for inline images

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Mutate-provider helpers for inline persistence & reconciliation

**Files:**
- Modify: `lib/features/notes/states/mutate_note_state.dart`
- Test: `test/features/notes/states/mutate_note_inline_test.dart`

**Interfaces:**
- Consumes: `imageAttachmentPickerProvider` (`persistToVault → Future<VaultRef>`), `hmmNoteRepositoryProvider`, `HmmNoteUpdate`.
- Produces on `MutateNote`:
  - `Future<VaultRef> persistInlineImage(int noteId, PickedImageBytes pick)` — persists bytes to the vault, returns the `VaultRef`; does **not** touch the note's attachments.
  - `Future<HmmNote?> setAttachments(int noteId, NoteAttachments attachments)` — writes the attachments column verbatim.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/states/mutate_note_inline_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/local/database.dart';
// NOTE: import the providers the app wires for local mode; see existing
// mutate_note tests in test/features/notes/states/ for the exact override set
// (hmmNoteRepositoryProvider, imageAttachmentPickerProvider, vaultStoreProvider).

void main() {
  test('persistInlineImage returns a VaultRef and does not change attachments',
      () async {
    // Arrange a local note repo + in-memory vault following the existing
    // mutate_note_state test harness (test/features/notes/states/).
    // (See that harness for the exact ProviderContainer overrides.)
    // 1. create a general note -> noteId
    // 2. final ref = await mutate.persistInlineImage(noteId, pick);
    // 3. expect(ref, isA<VaultRef>());
    // 4. expect((await repo.getNoteById(noteId))!.effectiveAttachments.images, isEmpty);
  }, skip: 'Fill in using the existing mutate_note_state test harness overrides');

  test('setAttachments writes the attachments column', () async {
    // 1. create note; 2. await mutate.setAttachments(noteId,
    //    NoteAttachments(images: [ref]));
    // 3. expect(reloaded.effectiveAttachments.images, [ref]);
  }, skip: 'Fill in using the existing mutate_note_state test harness overrides');
}
```

> The implementer must replace the two `skip`ped tests with real ones by copying the ProviderContainer override set from the existing `test/features/notes/states/` mutate tests (same `HmmDatabase(NativeDatabase.memory())` + local repo + in-memory vault wiring). Do not ship the `skip`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/states/mutate_note_inline_test.dart`
Expected: FAIL/compile-error once the `skip`s are replaced — the two methods don't exist yet.

- [ ] **Step 3: Add the two methods to `MutateNote`**

In `lib/features/notes/states/mutate_note_state.dart`, add inside the `MutateNote` class (alongside `attachImageBytes`):

```dart
  /// Persists [pick]'s bytes to the vault under [noteId] and returns the
  /// resulting VaultRef. Does not modify the note's attachments column —
  /// the caller reconciles attachments once after rewriting the body.
  Future<VaultRef> persistInlineImage(int noteId, PickedImageBytes pick) async {
    final picker = await ref.read(imageAttachmentPickerProvider.future);
    return picker.persistToVault(
      noteId: noteId,
      bytes: pick.bytes,
      originalName: pick.originalName,
      contentTypeHint: pick.contentType,
    );
  }

  /// Writes the attachments column verbatim (retention set for vault_gc).
  Future<HmmNote?> setAttachments(int noteId, NoteAttachments attachments) {
    return ref
        .read(hmmNoteRepositoryProvider)
        .updateNote(noteId, HmmNoteUpdate(attachments: attachments));
  }
```

Ensure `VaultRef` and `NoteAttachments` are imported (they are used by the existing `attachImageBytes`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/states/mutate_note_inline_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/states/mutate_note_state.dart test/features/notes/states/mutate_note_inline_test.dart
git commit -m "feat(notes): mutate helpers to persist inline images + set attachments

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Editor — insert inline images + live preview

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Test: `test/features/notes/presentation/note_editor_inline_test.dart`

**Interfaces:**
- Consumes: `insertImageAtCursor` (Task 3), `generateUuid`, `NoteMarkdownBody` (Task 2), `pendingUuidsIn` (Task 1), `PickedImageBytes`.
- Produces: image picks are inserted inline; a `Map<String, Uint8List> _pendingBytes` (uuid → bytes) drives a live preview.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/note_editor_inline_test.dart
// A widget test that pumps NoteEditorScreen (new general note), taps the
// gallery button (MediaToolbar's first btn), and asserts an inline pending
// placeholder text appears in the body controller + the live preview shows an
// Image. Use an override for imageByteSourceProvider returning a fixed
// PickedImageBytes (a tiny PNG), mirroring existing note_editor_media_test.dart.
//
// Assertions:
//  - after tapping gallery: the body text contains 'hmm-attachment://pending/'
//  - the live preview (NoteMarkdownBody) renders one Image widget
//
// Copy the ProviderScope/override scaffolding from
// test/features/notes/presentation/note_editor_media_test.dart.
```

> The implementer fills this in from `note_editor_media_test.dart` (same overrides). It must assert (a) the body contains a `hmm-attachment://pending/` placeholder after an image pick, and (b) `find.byType(Image)` in the preview.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/note_editor_inline_test.dart`
Expected: FAIL — the editor still appends to trailing picks and has no inline preview.

- [ ] **Step 3: Wire inline insertion + preview into the editor**

In `note_editor_screen.dart`:

Add the staged-bytes map near the controllers (line ~40-50 area):

```dart
  final Map<String, Uint8List> _pendingBytes = {}; // uuid -> staged image bytes
```

Add the imports:

```dart
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/util/uuid.dart';
import '../widgets/inline_insert.dart';
import '../widgets/note_markdown_body.dart';
```

Change `_addMedia` (currently appends to `_pendingPicks`) to insert inline and stage bytes:

```dart
  Future<void> _addMedia(AttachmentPickSource source) async {
    final pick = await ref.read(imageByteSourceProvider).pick(source);
    if (pick == null || !mounted) return;
    final uuid = generateUuid();
    setState(() {
      _pendingBytes[uuid] = pick.bytes;
      _pendingPickByUuid[uuid] = pick; // keep the pick for save-time persistence
      insertImageAtCursor(_bodyCtrl, uuid, pick.originalName);
    });
  }
```

Add the companion map (next to `_pendingBytes`):

```dart
  final Map<String, PickedImageBytes> _pendingPickByUuid = {};
```

Remove/replace the old `final List<PickedImageBytes> _pendingPicks = [];` usage for images (files/audio keep `_pendingFiles`). If `_pendingPicks` is referenced elsewhere (e.g. a trailing preview list), delete those image-only references — Phase 1 renders images inline, not as trailing cards.

Add a live preview beneath the body `TextField` (only when the body has inline refs). Wrap the body area so the preview appears under it; e.g. after the `TextField(controller: _bodyCtrl, …)`:

```dart
            if (_bodyCtrl.text.contains('hmm-attachment://')) ...[
              const SizedBox(height: 12),
              const Divider(),
              Text('Preview', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              NoteMarkdownBody(
                data: _bodyCtrl.text,
                pendingBytes: _pendingBytes,
                // resolver for already-saved refs in an existing note:
                resolver: ref.watch(attachmentResolverProvider).valueOrNull,
                selectable: false,
              ),
            ],
```

Make the body `TextField` rebuild the preview as the user types by adding `onChanged: (_) => setState(() {})` to it (only if it doesn't already trigger rebuilds).

Add the import for the resolver provider if not present:

```dart
import '../../../../core/data/attachments/attachment_providers.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/note_editor_inline_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + full notes tests**

Run: `cd ~/projects/hmm_console && flutter analyze lib/features/notes && flutter test test/features/notes`
Expected: `No issues found!`; existing editor tests pass (fix any references to the removed image `_pendingPicks` list).

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/note_editor_inline_test.dart
git commit -m "feat(notes): editor inserts inline images at cursor with live preview

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Editor save — persist picks, rewrite body, reconcile attachments

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart` (the save method, lines ~146-177)
- Test: `test/features/notes/presentation/note_editor_inline_save_test.dart`

**Interfaces:**
- Consumes: `MutateNote.persistInlineImage` + `setAttachments` (Task 4), `pendingUuidsIn` + `rewritePendingToVault` + `imageRefPathsIn` (Task 1).

**Save algorithm (both new and existing notes):**
1. Create (new) or update (existing) the note with the **current** body (still containing `pending/<uuid>` URIs) → obtain `noteId`.
2. `referenced = pendingUuidsIn(_bodyCtrl.text)`.
3. For each referenced uuid with a staged pick: `ref = await mutate.persistInlineImage(noteId, pick)`, collect `uuidToPath[uuid] = ref.path` and `newRefs.add(ref)`.
4. `rewritten = rewritePendingToVault(_bodyCtrl.text, uuidToPath)`; `await mutate.updateGeneral(noteId, markdownBody: rewritten)`.
5. Reconcile attachments: `existing = (await repo.getNoteById(noteId))!.effectiveAttachments`; retained = existing images/primary that are still referenced by `imageRefPathsIn(rewritten)` **plus** `newRefs`; write via `mutate.setAttachments`. (Removal-confirmation is Task 7; here just **add** new refs and keep existing.)

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/note_editor_inline_save_test.dart
// Widget/integration test: new general note, insert one inline image (staged),
// tap Save. Then load the note from the repo and assert:
//   - note.content contains 'hmm-attachment://attachments/note-' (rewritten,
//     no 'pending/')
//   - note.effectiveAttachments.images has exactly one VaultRef whose path
//     matches the URL in the content
// Use the same local-repo + in-memory-vault overrides as
// test/features/notes/states/ mutate tests + the editor scaffolding from
// note_editor_media_test.dart.
```

> Implementer fills in with the combined harness (local repo + vault + editor). Assert the saved content has no `pending/` and one matching `VaultRef` in `images`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/note_editor_inline_save_test.dart`
Expected: FAIL — save still uses the old `attachImageBytes` loop over `_pendingPicks`.

- [ ] **Step 3: Rewrite the save method**

Replace the image portion of the save method. Keep the file/audio `_pendingFiles` loop as-is. Replace the create/update + `_pendingPicks` block with:

```dart
    // 1) Create or update with the current body (pending URIs intact).
    if (_noteId == null) {
      final note = await mutate.createGeneral(
        subject: subject,
        markdownBody: _bodyCtrl.text,
        parentNoteId: _parentId,
        noteDate: _noteDate.toUtc(),
        location: _pendingLocation,
      );
      _noteId = note.id;
    } else {
      await mutate.updateGeneral(
        _noteId!,
        subject: subject,
        markdownBody: _bodyCtrl.text,
        noteDate: _noteDate.toUtc(),
        location: _locationCleared ? NoteLocation.empty : null,
      );
      if (_parentTouched) {
        await mutate.setParent(_noteId!, _parentId);
      }
    }
    final noteId = _noteId!;

    // 2) Persist each still-referenced pending pick to the vault.
    final uuidToPath = <String, String>{};
    final newRefs = <VaultRef>[];
    for (final uuid in pendingUuidsIn(_bodyCtrl.text)) {
      final pick = _pendingPickByUuid[uuid];
      if (pick == null) continue;
      final vref = await mutate.persistInlineImage(noteId, pick);
      uuidToPath[uuid] = vref.path;
      newRefs.add(vref);
    }

    // 3) Rewrite pending URIs -> real vault URIs and save the final body.
    final rewritten = rewritePendingToVault(_bodyCtrl.text, uuidToPath);
    if (rewritten != _bodyCtrl.text) {
      await mutate.updateGeneral(noteId, markdownBody: rewritten);
      _bodyCtrl.text = rewritten;
    }

    // 4) Reconcile attachments: keep existing refs + add the new inline refs.
    final repo = ref.read(hmmNoteRepositoryProvider);
    final current = await repo.getNoteById(noteId);
    if (current != null) {
      final existing = current.effectiveAttachments;
      final images = <AttachmentRef>[
        ...existing.images,
        for (final r in newRefs)
          if (!existing.images.contains(r)) r,
      ];
      await mutate.setAttachments(
        noteId,
        NoteAttachments(primaryImage: existing.primaryImage, images: images,
            files: existing.files),
      );
    }

    // Files/audio: unchanged.
    if (_pendingFiles.isNotEmpty) {
      for (final pick in _pendingFiles) {
        await mutate.attachFileBytes(noteId, pick);
      }
    }
```

Add imports if missing:

```dart
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/local/... hmmNoteRepositoryProvider source'; // match the existing import used by mutate
```

(Use the same `hmmNoteRepositoryProvider` import path the codebase already uses; grep `hmmNoteRepositoryProvider` for the exact source.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/note_editor_inline_save_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + full notes suite**

Run: `cd ~/projects/hmm_console && flutter analyze lib/features/notes && flutter test test/features/notes`
Expected: `No issues found!`; all notes tests pass.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/note_editor_inline_save_test.dart
git commit -m "feat(notes): save persists inline picks, rewrites body, reconciles attachments

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Retention confirm-on-remove + trailing-card dedup + read-site wiring

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart` (save: removal confirm)
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart` (dedup trailing cards)
- Modify: `lib/features/automobile_records/presentation/screens/service_record_form_screen.dart` (read-site: use `NoteMarkdownBody` for the notes preview)
- Test: `test/features/notes/presentation/note_editor_retention_test.dart`
- Test: `test/features/notes/presentation/note_detail_dedup_test.dart`

**Interfaces:**
- Consumes: `imageRefPathsIn` (Task 1).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/notes/presentation/note_detail_dedup_test.dart
// Pump NoteDetailScreen for a note whose content references one image inline
// (hmm-attachment://attachments/note-1/a.png) AND whose attachments.images
// contains that same VaultRef plus a second, non-inline VaultRef.
// Assert the trailing NoteMediaCardList receives only the non-inline ref
// (find one NoteMediaCard for the non-inline image; the inline one is not
// duplicated as a trailing card).
```

```dart
// test/features/notes/presentation/note_editor_retention_test.dart
// Existing note has one saved inline image. Open the editor, delete the inline
// markdown line, tap Save. Assert a confirmation dialog appears
// ("Delete these stored images, or keep them attached?"). Tapping "Keep"
// leaves the ref in attachments.images; tapping "Delete" removes it.
```

> Implementer fills both in using existing note_detail / note_editor test harnesses.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/note_detail_dedup_test.dart test/features/notes/presentation/note_editor_retention_test.dart`
Expected: FAIL — dedup + confirm not implemented.

- [ ] **Step 3a: Trailing-card dedup in note detail**

In `note_detail_screen.dart`, where `NoteMediaCardList(saved: …)` is built, exclude refs referenced inline in the rendered content:

```dart
    final inlinePaths = imageRefPathsIn(d.note.content ?? '').toSet();
    final trailing = atts.images
        .where((r) => !(r is VaultRef && inlinePaths.contains(r.path)))
        .toList();
    // ...pass `trailing` to NoteMediaCardList(saved: trailing)
```

(Ensure `imageRefPathsIn` and `VaultRef` are imported. `atts` is the note's `effectiveAttachments`.)

- [ ] **Step 3b: Confirm-on-remove in the editor save**

In `note_editor_screen.dart` save, before writing the reconciled attachments (Task 6, step 4), compute removed refs and confirm:

```dart
    // Refs previously attached but no longer referenced inline (existing notes).
    final inlineNow = imageRefPathsIn(rewritten).toSet();
    final removed = existing.images
        .whereType<VaultRef>()
        .where((r) => !inlineNow.contains(r.path))
        .toList();
    var keepRemoved = false;
    if (removed.isNotEmpty) {
      keepRemoved = await _confirmRemoveImages(removed.length) == false;
      // dialog returns true = Delete, false = Keep
    }
    final retained = <AttachmentRef>[
      // keep inline-referenced existing refs
      ...existing.images.where((r) =>
          r is! VaultRef || inlineNow.contains(r.path)),
      // optionally keep the removed ones
      if (keepRemoved) ...removed,
      // add newly persisted inline refs
      for (final r in newRefs)
        if (!existing.images.contains(r)) r,
    ];
    await mutate.setAttachments(
      noteId,
      NoteAttachments(primaryImage: existing.primaryImage, images: retained,
          files: existing.files),
    );
```

Add the dialog helper:

```dart
  /// Returns true = Delete the stored images, false = Keep them attached.
  Future<bool> _confirmRemoveImages(int count) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove stored images?'),
        content: Text(
            'You removed $count image${count == 1 ? '' : 's'} from this note. '
            'Delete the stored image${count == 1 ? '' : 's'}, or keep '
            '${count == 1 ? 'it' : 'them'} attached?'),
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
    return res ?? false; // dismissed = keep
  }
```

This replaces the simpler "keep existing + add new" reconciliation from Task 6 step 4 (the `removed`/confirm branch supersedes it).

- [ ] **Step 3c: Read-site — service-record notes preview**

In `service_record_form_screen.dart`, replace the notes-preview `MarkdownBody(data: _notesCtrl.text)` with:

```dart
              NoteMarkdownBody(
                data: _notesCtrl.text,
                resolver: ref.watch(attachmentResolverProvider).valueOrNull,
                selectable: false,
              ),
```

Add imports:

```dart
import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../notes/presentation/widgets/note_markdown_body.dart';
```

(This is render-only; service-record notes carry no inline refs yet — a later phase wires insertion there. Plain markdown renders unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/note_detail_dedup_test.dart test/features/notes/presentation/note_editor_retention_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + full suite**

Run: `cd ~/projects/hmm_console && flutter analyze && flutter test`
Expected: `No issues found!`; full suite green.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/screens/note_editor_screen.dart lib/features/notes/presentation/screens/note_detail_screen.dart lib/features/automobile_records/presentation/screens/service_record_form_screen.dart test/features/notes/presentation/note_detail_dedup_test.dart test/features/notes/presentation/note_editor_retention_test.dart
git commit -m "feat(notes): confirm-on-remove retention + trailing-card dedup + read sites

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (Phase 1 rows of the umbrella spec):**
- U1 codec → Task 1. ✓
- U2 pending bytes → Task 2 (`pendingBytes` map) + Task 5 (`_pendingBytes`). ✓
- U3 renderer (sizedImageBuilder, whole image, max-height, tap→fullscreen, placeholder) → Task 2. ✓
- U4 insert + rewrite → Task 3 (insert) + Task 1 (rewrite) + Task 6 (save rewrite). ✓
- U5 retention (confirm-on-remove) + no-double-display + GC safety (refs added to `attachments.images`) → Task 6 (add) + Task 7 (confirm + dedup). ✓
- Read sites (note detail via `MarkdownView` delegate; service-record preview) → Task 2 + Task 7. ✓
- General-notes editor wiring → Tasks 5-6. ✓

**Placeholder scan:** Tasks 4-7 contain `skip`ped/described test bodies to be filled from the *named* existing harnesses (`test/features/notes/states/`, `note_editor_media_test.dart`) — these are pointers to concrete existing patterns, not vague requirements; the implementer must replace them with real tests (called out explicitly) before the task's tests can fail→pass. All implementation code is complete and concrete.

**Type consistency:** `formatImageUri`/`parseImageUri`/`formatPendingUri`/`pendingUuidOf`/`imageRefPathsIn`/`pendingUuidsIn`/`rewritePendingToVault` (Task 1) are used verbatim in Tasks 2, 3, 6, 7. `NoteMarkdownBody({data, resolver, pendingBytes, selectable})` (Task 2) matches its uses in Tasks 5 & 7. `persistInlineImage`/`setAttachments` (Task 4) match Task 6. `VaultRef`/`NoteAttachments`/`persistToVault`/`createGeneral`/`updateGeneral` signatures match the verified references block.

**Note on Task 6 vs Task 7:** Task 6 lands a simpler "add new + keep existing" reconciliation to get the save path green; Task 7 supersedes step 4 with the removal-confirmation branch. This is intentional incremental layering (each task independently testable); the reviewer should treat Task 7's reconciliation as the final form.
