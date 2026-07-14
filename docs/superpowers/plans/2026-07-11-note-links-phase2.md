# Note Links (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add inter-note links (`hmm-note://<uuid>`) and tappable external web/video links to note Markdown bodies, on the shared renderer built in Phase 1.

**Architecture:** Note links are standard Markdown links whose URL is `hmm-note://<note-uuid>` (the stable `HmmNote.uuid`, tier-independent). The shared `NoteMarkdownBody` gains an `onTapLink` handler that dispatches by scheme: `hmm-note://` → resolve the uuid to a local note and navigate (or show "unavailable"); `http(s)://` → open via `url_launcher`. Note links are inserted at the cursor via a "link to note" toolbar action backed by a note picker; web/video links are authored as standard Markdown and become tappable automatically.

**Tech Stack:** Flutter, Riverpod, `flutter_markdown ^0.7.7+1` (`onTapLink`), `url_launcher ^6.3.2` (new dep, already resolvable in pub-cache), GoRouter.

**Scope:** Phase 2 of `docs/superpowers/specs/2026-07-11-note-inline-refs-and-secure-attachments-design.md`. Note-level `hmm-note://<uuid>` + external `http(s)` links only. **Out of scope:** content/block-level anchors (`#anchor`), a backlinks index, sensitive attachments (Phase 4). Builds on merged Phase 1 (`NoteMarkdownBody`, `inline_ref_uri.dart`, `inline_insert.dart`).

## Global Constraints

- Note-link URI scheme is exactly **`hmm-note://<uuid>`**; the uuid is `HmmNote.uuid` (stable across local/cloudStorage/cloudApi — sync correlates by uuid).
- Link dispatch is **by scheme**: `hmm-note://` → navigate to that note; `http(s)://` → `url_launcher` (external app); anything else → ignored (no crash).
- A note-link whose target isn't present locally (deleted, or not yet synced) shows a **non-crashing "Linked note unavailable"** affordance — never throws, never navigates to a bad route.
- Links are **plain text** in content (no bytes) — no `vault_gc` interaction.
- Reuse Phase 1 pieces; do not duplicate the codec or renderer.

**Reference signatures (verified — do not re-derive):**

```dart
// flutter_markdown 0.7.7+1 (lib/src/widget.dart:32)
typedef MarkdownTapLinkCallback = void Function(String text, String? href, String title);
// MarkdownBody accepts: MarkdownTapLinkCallback? onTapLink

// lib/features/notes/presentation/widgets/note_markdown_body.dart (current)
class NoteMarkdownBody extends StatelessWidget {
  const NoteMarkdownBody({super.key, required this.data, this.resolver,
      this.pendingBytes, this.selectable = true});
  // build() returns MarkdownBody(data:, selectable:, sizedImageBuilder:)
}

// lib/core/data/local/local_hmm_note_repository.dart:41
Future<HmmNote?> getNoteByUuid(String uuid);
// provider: hmmNoteRepositoryProvider (lib/core/data/repository_providers.dart)

// Navigation — note detail route (lib/core/navigation/router_config.dart:290)
// path '/notes/:id' (int id); navigate: context.push('/notes/${note.id}')

// lib/features/notes/presentation/widgets/media_toolbar.dart:9
const MediaToolbar({super.key, required this.onPick, required this.onPickFile,
    required this.onRecord, this.onDismissKeyboard, this.enabled = true});

// lib/features/notes/states/notes_list_state.dart:223
// notesListStateProvider -> AsyncNotifier<NotesListData>; NotesListData.all : List<HmmNote>
// HmmNote: final int id; final String uuid; final String subject;
```

---

### Task 1: Codec — note-link URIs

**Files:**
- Modify: `lib/core/data/attachments/inline_ref_uri.dart`
- Test: `test/core/data/attachments/inline_ref_uri_test.dart` (extend)

**Interfaces:**
- Produces: `String formatNoteUri(String uuid)` → `'hmm-note://<uuid>'`; `String? parseNoteUri(String uri)` → uuid (ignoring any `#anchor` suffix) or null; `List<String> noteUuidsIn(String markdown)` → uuids of inline `hmm-note://` links.

- [ ] **Step 1: Write the failing test**

```dart
  test('format/parse note uri round-trips the uuid', () {
    expect(formatNoteUri('abc-1'), 'hmm-note://abc-1');
    expect(parseNoteUri('hmm-note://abc-1'), 'abc-1');
    expect(parseNoteUri('hmm-note://abc-1#block2'), 'abc-1'); // anchor ignored
    expect(parseNoteUri('hmm-attachment://x'), isNull);
    expect(parseNoteUri('https://x'), isNull);
  });

  test('noteUuidsIn extracts note-link uuids', () {
    const md = 'see [a](hmm-note://u1) and [b](https://x) and [c](hmm-note://u2)';
    expect(noteUuidsIn(md), ['u1', 'u2']);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/data/attachments/inline_ref_uri_test.dart`
Expected: FAIL — functions not defined.

- [ ] **Step 3: Implement**

Add to `inline_ref_uri.dart`:

```dart
const String _noteScheme = 'hmm-note://';

/// `abc` -> `hmm-note://abc`.
String formatNoteUri(String uuid) => '$_noteScheme$uuid';

/// The note uuid for a `hmm-note://<uuid>` link (any `#anchor` is dropped —
/// anchors are a reserved future feature), else null.
String? parseNoteUri(String uri) {
  if (!uri.startsWith(_noteScheme)) return null;
  var rest = uri.substring(_noteScheme.length);
  final hash = rest.indexOf('#');
  if (hash >= 0) rest = rest.substring(0, hash);
  return rest.isEmpty ? null : rest;
}

// Markdown link (not image): [text](url) — a leading '!' would make it an image.
final RegExp _linkMd = RegExp(r'(?<!\!)\[[^\]]*\]\(([^)\s]+)');

/// All inline `hmm-note://` link uuids, in document order.
List<String> noteUuidsIn(String markdown) => _linkMd
    .allMatches(markdown)
    .map((m) => m.group(1)!)
    .map(parseNoteUri)
    .whereType<String>()
    .toList();
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/core/data/attachments/inline_ref_uri_test.dart`
Expected: PASS (all, including the new 2).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/core/data/attachments/inline_ref_uri.dart test/core/data/attachments/inline_ref_uri_test.dart
git commit -m "feat(notes): codec for hmm-note:// links

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Link dispatch + renderer `onTapLink`

**Files:**
- Modify: `pubspec.yaml` (add `url_launcher: ^6.3.2`)
- Modify: `lib/features/notes/presentation/widgets/note_markdown_body.dart`
- Test: `test/features/notes/presentation/widgets/note_link_dispatch_test.dart`

**Interfaces:**
- Consumes: `parseNoteUri` (Task 1).
- Produces:
  - Pure dispatcher `void dispatchMarkdownLink(String? href, {required void Function(String uuid) onNote, required void Function(Uri url) onExternal})`.
  - `NoteMarkdownBody` gains `final void Function(String noteUuid)? onNoteLinkTap;` and `final void Function(Uri url)? onExternalLinkTap;` and wires `onTapLink`. Default external handler launches via `url_launcher`.

- [ ] **Step 1: Write the failing test** (the pure dispatcher — link taps in `MarkdownBody` can't be simulated in a widget test)

```dart
// test/features/notes/presentation/widgets/note_link_dispatch_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_markdown_body.dart';

void main() {
  test('dispatches a hmm-note link to onNote with the uuid', () {
    String? note; Uri? ext;
    dispatchMarkdownLink('hmm-note://u1',
        onNote: (u) => note = u, onExternal: (x) => ext = x);
    expect(note, 'u1');
    expect(ext, isNull);
  });

  test('dispatches an http(s) link to onExternal', () {
    String? note; Uri? ext;
    dispatchMarkdownLink('https://example.com/v',
        onNote: (u) => note = u, onExternal: (x) => ext = x);
    expect(ext, Uri.parse('https://example.com/v'));
    expect(note, isNull);
  });

  test('ignores null / unknown-scheme links', () {
    var calls = 0;
    dispatchMarkdownLink(null,
        onNote: (_) => calls++, onExternal: (_) => calls++);
    dispatchMarkdownLink('mailto:x@y.z',
        onNote: (_) => calls++, onExternal: (_) => calls++);
    expect(calls, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/note_link_dispatch_test.dart`
Expected: FAIL — `dispatchMarkdownLink` not defined.

- [ ] **Step 3: Add the dep**

In `pubspec.yaml` under `dependencies:` add:

```yaml
  url_launcher: ^6.3.2
```

Run: `cd ~/projects/hmm_console && flutter pub get`
Expected: resolves (url_launcher 6.3.2 already in pub-cache).

- [ ] **Step 4: Implement dispatcher + renderer wiring**

In `note_markdown_body.dart`, add the import and the top-level dispatcher:

```dart
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart'; // already imported

/// Routes a tapped Markdown link URL by scheme: a `hmm-note://<uuid>` link to
/// [onNote]; an `http(s)` link to [onExternal]; anything else is ignored.
void dispatchMarkdownLink(String? href,
    {required void Function(String uuid) onNote,
    required void Function(Uri url) onExternal}) {
  if (href == null) return;
  final uuid = parseNoteUri(href);
  if (uuid != null) {
    onNote(uuid);
    return;
  }
  final uri = Uri.tryParse(href);
  if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
    onExternal(uri);
  }
}
```

Add the callback fields to `NoteMarkdownBody` (after `selectable`):

```dart
  /// Tapped a `hmm-note://<uuid>` link. Null = note links are inert here.
  final void Function(String noteUuid)? onNoteLinkTap;

  /// Tapped an external `http(s)` link. Defaults to opening via url_launcher.
  final void Function(Uri url)? onExternalLinkTap;
```

Add them to the constructor param list. Then wire `onTapLink` in `build()`:

```dart
    return MarkdownBody(
      data: data,
      selectable: selectable,
      sizedImageBuilder: (config) => _buildImage(context, config),
      onTapLink: (text, href, title) => dispatchMarkdownLink(
        href,
        onNote: (uuid) => onNoteLinkTap?.call(uuid),
        onExternal: (url) =>
            (onExternalLinkTap ?? _launchExternal)(url),
      ),
    );
```

Add the default launcher method on the widget:

```dart
  void _launchExternal(Uri url) {
    // Fire-and-forget; failures (no handler app) are silently ignored.
    launchUrl(url, mode: LaunchMode.externalApplication);
  }
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/note_link_dispatch_test.dart && flutter analyze lib/features/notes`
Expected: PASS (3); `No issues found!`.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add pubspec.yaml pubspec.lock lib/features/notes/presentation/widgets/note_markdown_body.dart test/features/notes/presentation/widgets/note_link_dispatch_test.dart
git commit -m "feat(notes): renderer onTapLink dispatch (note vs external) + url_launcher

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Note-link navigation in `MarkdownView` (resolve + navigate / unavailable)

**Files:**
- Modify: `lib/features/notes/presentation/widgets/note_markdown_body.dart` (the `MarkdownView` wrapper)
- Test: `test/features/notes/presentation/widgets/note_link_nav_test.dart`

**Interfaces:**
- Consumes: `getNoteByUuid` via `hmmNoteRepositoryProvider`; GoRouter `/notes/:id`.
- Produces: `MarkdownView` resolves a tapped `hmm-note://<uuid>` to a local note and `context.push('/notes/<id>')`, or shows a "Linked note unavailable" SnackBar if not found.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/notes/presentation/widgets/note_link_nav_test.dart
// Pump a MarkdownView('[go](hmm-note://u1)') inside a GoRouter with a
// '/notes/:id' route and an overridden hmmNoteRepositoryProvider whose
// getNoteByUuid('u1') returns a note with id 7. Tapping the link should
// navigate to '/notes/7'. A second case: getNoteByUuid returns null →
// a SnackBar 'Linked note unavailable' shows, no navigation.
//
// NOTE: tapping a rendered Markdown link span is unreliable in widget tests;
// instead assert by invoking the wired callback path. Construct the
// MarkdownView, find the underlying NoteMarkdownBody via
// tester.widget<NoteMarkdownBody>(...), and call its onNoteLinkTap('u1')
// directly, then pumpAndSettle and assert the current route / SnackBar.
```

> Implementer: get the `NoteMarkdownBody` child of the `MarkdownView` with `tester.widget<NoteMarkdownBody>(find.byType(NoteMarkdownBody))`, invoke `onNoteLinkTap!('u1')`, `await tester.pumpAndSettle()`, then assert navigation (a `NoteDetailScreen`/route change) for the found case and a `'Linked note unavailable'` SnackBar for the null case. Use a fake `IHmmNoteRepository` (noSuchMethod) overriding only `getNoteByUuid`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/note_link_nav_test.dart`
Expected: FAIL — `MarkdownView` doesn't wire `onNoteLinkTap` yet.

- [ ] **Step 3: Implement**

In `note_markdown_body.dart`, update the `MarkdownView.build` to wire navigation:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(attachmentResolverProvider).value;
    return NoteMarkdownBody(
      data: data,
      resolver: resolver,
      onNoteLinkTap: (uuid) => _openNote(context, ref, uuid),
    );
  }

  Future<void> _openNote(
      BuildContext context, WidgetRef ref, String uuid) async {
    final note =
        await ref.read(hmmNoteRepositoryProvider).getNoteByUuid(uuid);
    if (!context.mounted) return;
    if (note != null) {
      context.push('/notes/${note.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Linked note unavailable')));
    }
  }
```

Add imports to the file:

```dart
import 'package:go_router/go_router.dart';
import '../../../../core/data/repository_providers.dart';
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/note_link_nav_test.dart && flutter analyze lib/features/notes`
Expected: PASS; `No issues found!`.

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/widgets/note_markdown_body.dart test/features/notes/presentation/widgets/note_link_nav_test.dart
git commit -m "feat(notes): tap a note link to navigate, or show unavailable

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Insert-note-link helper

**Files:**
- Modify: `lib/features/notes/presentation/widgets/inline_insert.dart`
- Test: `test/features/notes/presentation/widgets/inline_insert_test.dart` (extend)

**Interfaces:**
- Consumes: `formatNoteUri` (Task 1).
- Produces: `void insertNoteLinkAtCursor(TextEditingController c, String uuid, String label)` — inserts `[label](hmm-note://<uuid>)` at the caret, leaving the caret after it.

- [ ] **Step 1: Write the failing test**

```dart
  test('inserts a note link at the caret', () {
    final c = TextEditingController(text: 'see  here');
    c.selection = const TextSelection.collapsed(offset: 4); // after "see "
    insertNoteLinkAtCursor(c, 'u1', 'Setup');
    expect(c.text, 'see [Setup](hmm-note://u1) here');
    expect(c.selection.baseOffset, 'see [Setup](hmm-note://u1)'.length);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/inline_insert_test.dart`
Expected: FAIL — function not defined.

- [ ] **Step 3: Implement**

Add to `inline_insert.dart`:

```dart
/// Inserts an inline `[label](hmm-note://<uuid>)` link at the caret, leaving the
/// caret immediately after the inserted link.
void insertNoteLinkAtCursor(
    TextEditingController controller, String uuid, String label) {
  final link = '[$label](${formatNoteUri(uuid)})';
  final text = controller.text;
  final sel = controller.selection;
  final at = (sel.isValid && sel.start >= 0) ? sel.start : text.length;
  final next = text.substring(0, at) + link + text.substring(at);
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: at + link.length),
  );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/inline_insert_test.dart`
Expected: PASS (all).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/widgets/inline_insert.dart test/features/notes/presentation/widgets/inline_insert_test.dart
git commit -m "feat(notes): insert-note-link-at-cursor helper

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Toolbar "link to note" action + note picker + editor wiring

**Files:**
- Modify: `lib/features/notes/presentation/widgets/media_toolbar.dart` (add `onLinkToNote`)
- Create: `lib/features/notes/presentation/widgets/note_link_picker.dart`
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart` (wire the action)
- Test: `test/features/notes/presentation/widgets/note_link_picker_test.dart`
- Test: `test/features/notes/presentation/note_editor_link_test.dart`

**Interfaces:**
- Consumes: `notesListStateProvider` → `NotesListData.all` (`List<HmmNote>`), `insertNoteLinkAtCursor` (Task 4).
- Produces:
  - `MediaToolbar` gains `final VoidCallback? onLinkToNote;` with a link IconButton (only shown when non-null).
  - `Future<HmmNote?> showNoteLinkPicker(BuildContext context, WidgetRef ref, {int? excludeNoteId})` — a modal that lists notes (subject), filters by a search field, excludes `excludeNoteId`, returns the chosen note.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/notes/presentation/widgets/note_link_picker_test.dart
// Override notesListStateProvider to expose 3 notes (subjects A/B/C). Pump a
// button that calls showNoteLinkPicker; tap it; the sheet lists A/B/C. Type
// 'B' in the search field -> only B shows. Tap B -> the future completes with
// note B (assert via a captured variable). If excludeNoteId is one of them,
// that note is not listed.
```

```dart
// test/features/notes/presentation/note_editor_link_test.dart
// Pump NoteEditorScreen (new note) with notesListStateProvider overridden to a
// single note (id 9, uuid 'u9', subject 'Target'). Tap the toolbar link action
// (Icons.link), choose 'Target' in the picker, and assert the body controller
// text now contains '[Target](hmm-note://u9)'.
```

> Implementer fills both in using existing note-editor test scaffolding (`note_editor_media_test.dart`) and a `notesListStateProvider` override. `NotesListData` requires `all` + `catalogsById` (pass `{}`); construct notes with `HmmNote(id:, uuid:, subject:, authorId:1, createDate: DateTime(2026,1,1))`.

- [ ] **Step 2: Run to verify they fail**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/note_link_picker_test.dart test/features/notes/presentation/note_editor_link_test.dart`
Expected: FAIL — picker + toolbar action don't exist.

- [ ] **Step 3a: MediaToolbar link action**

In `media_toolbar.dart`, add the field to the constructor and class:

```dart
  final VoidCallback? onLinkToNote;
```

(add `this.onLinkToNote,` to the constructor). In the `Row` children (after the mic IconButton), add:

```dart
            if (onLinkToNote != null)
              IconButton(
                icon: const Icon(Icons.link),
                color: c.accent,
                tooltip: 'Link to a note',
                onPressed: enabled ? onLinkToNote : null,
              ),
```

- [ ] **Step 3b: Note picker**

Create `lib/features/notes/presentation/widgets/note_link_picker.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/hmm_note.dart';
import '../../states/notes_list_state.dart';

/// Modal note picker for inserting a link. Returns the chosen note, or null.
Future<HmmNote?> showNoteLinkPicker(BuildContext context, WidgetRef ref,
    {int? excludeNoteId}) {
  return showModalBottomSheet<HmmNote>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _NoteLinkPicker(excludeNoteId: excludeNoteId),
  );
}

class _NoteLinkPicker extends ConsumerStatefulWidget {
  const _NoteLinkPicker({this.excludeNoteId});
  final int? excludeNoteId;
  @override
  ConsumerState<_NoteLinkPicker> createState() => _NoteLinkPickerState();
}

class _NoteLinkPickerState extends ConsumerState<_NoteLinkPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(notesListStateProvider).value?.all ?? const [];
    final q = _query.trim().toLowerCase();
    final items = all
        .where((n) => n.id != widget.excludeNoteId)
        .where((n) => q.isEmpty || n.subject.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Search notes', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final n in items)
                    ListTile(
                      title: Text(n.subject),
                      onTap: () => Navigator.of(context).pop(n),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3c: Wire into the editor**

In `note_editor_screen.dart`, add imports:

```dart
import '../widgets/note_link_picker.dart';
```

Add a handler method (near `_addMedia`):

```dart
  Future<void> _addNoteLink() async {
    final note = await showNoteLinkPicker(context, ref, excludeNoteId: _noteId);
    if (note == null || !mounted) return;
    setState(() => insertNoteLinkAtCursor(_bodyCtrl, note.uuid, note.subject));
  }
```

Pass it to the toolbar:

```dart
          MediaToolbar(
            onPick: _addMedia,
            onPickFile: _addFile,
            onRecord: _addRecording,
            onLinkToNote: _addNoteLink,
            enabled: !_busy,
            onDismissKeyboard:
                keyboardUp ? () => FocusScope.of(context).unfocus() : null,
          ),
```

- [ ] **Step 4: Run to verify they pass**

Run: `cd ~/projects/hmm_console && flutter test test/features/notes/presentation/widgets/note_link_picker_test.dart test/features/notes/presentation/note_editor_link_test.dart && flutter analyze lib/features/notes`
Expected: PASS; `No issues found!`.

- [ ] **Step 5: Full suite**

Run: `cd ~/projects/hmm_console && flutter analyze && flutter test`
Expected: `No issues found!`; full suite green.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/notes/presentation/widgets/media_toolbar.dart lib/features/notes/presentation/widgets/note_link_picker.dart lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/widgets/note_link_picker_test.dart test/features/notes/presentation/note_editor_link_test.dart
git commit -m "feat(notes): link-to-note toolbar action + note picker

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (Phase 2 rows):** note-link codec → Task 1; `onTapLink` scheme dispatch (note + `http(s)`) → Task 2; resolve-and-navigate + deleted-target affordance → Task 3; insert helpers (note link; web links authored as standard Markdown, tappable via Task 2) → Task 4; toolbar action + note picker + editor wiring → Task 5. Anchors/backlinks explicitly out of scope. ✓

**Placeholder scan:** Tasks 1, 2, 4 have complete test + code. Tasks 3 and 5 describe their widget/integration test bodies with the exact harness + assertions to use (invoke the wired `onNoteLinkTap`; override `notesListStateProvider`) — the implementer writes them out; all implementation code is complete. ✓

**Type consistency:** `formatNoteUri`/`parseNoteUri`/`noteUuidsIn` (Task 1) reused in Tasks 2 & 4; `dispatchMarkdownLink(href, {onNote, onExternal})` (Task 2) matches its call in `NoteMarkdownBody.onTapLink`; `onNoteLinkTap`/`onExternalLinkTap` names consistent across Tasks 2–3; `insertNoteLinkAtCursor(c, uuid, label)` (Task 4) matches its use in Task 5; `showNoteLinkPicker(context, ref, {excludeNoteId})` returns `HmmNote?` used in Task 5. `getNoteByUuid`, `/notes/:id`, `notesListStateProvider.all`, and `MediaToolbar` fields match the verified references. ✓
