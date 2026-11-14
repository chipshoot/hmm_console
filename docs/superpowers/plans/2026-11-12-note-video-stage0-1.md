# Video in Notes — Stage 0 (compat) + Stage 1 (video links) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every build tolerate and preserve attachment data it doesn't understand (stage 0), then turn YouTube/Bilibili links on their own line into saved preview cards that open the video's app (stage 1).

**Architecture:** Stage 0 teaches `NoteAttachmentsCodec` to keep unknown entries and keys as raw JSON on `NoteAttachments` and write them back, and routes every reader that collects vault paths or rebuilds attachments through two new members (`vaultPaths`, `copyWith`). Stage 1 adds a `linkPreviews` list to `NoteAttachments`, a pure link parser/splitter, a Dio-based preview fetcher, a `VideoLinkCard` rendered by `NoteMarkdownBody` in place of a standalone URL line, and editor wiring (detect, fetch, persist on save, an "Add video link" toolbar button).

**Tech Stack:** Flutter, Riverpod 3, Drift, flutter_markdown, Dio 5, url_launcher, gen-l10n (en/zh).

**Spec:** `docs/superpowers/specs/2026-11-12-note-video-design.md` (§3 Delivery stages 0 and 1, §5.3, §5.5, §6.2).

## Global Constraints

- Branch `feat/note-video`. Never push or merge without the user asking. Commit trailer exactly `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never amend.
- Never stage `/Users/fchy/Projects/hmm/CLAUDE.md`.
- `dart format` individual files only, never a directory.
- `flutter analyze` must stay at the current 2-issue baseline; full `flutter test` must pass.
- Icon buttons: `HmmIconButton` with a localized tooltip (no new raw `IconButton`; `test/core/help/icon_button_guard_test.dart` allow-list only shrinks). Apple glyph via `adaptiveIcon(context, material: …, apple: …)`.
- Every new user-facing string goes in both `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`, then `flutter gen-l10n`.
- Never `ref.watch` inside a `LayoutBuilder` builder.
- Fetch link previews directly from the device; no Hmm server; no Google API key.
- **Stage gate:** Stage 0 (Tasks 1–2) must be merged and installed on BOTH iPhone and iPad (backup first, install over, never uninstall) before any build containing Task 3+ is installed anywhere. The executor stops after Task 2 and asks the user.
- cloudApi mode has no note repository (`repository_providers.dart` throws `UnimplementedError`), so no cloudApi handling is needed in these stages.

## Review Focus

1. A note last saved by a newer build (with `video/*` refs and a `linkPreviews` key) is edited by a Stage-0 build — adding a photo, removing an inline image, attaching a PDF — and must keep every unknown entry byte-for-byte. Pinned in Task 2 (`mutate keeps preserved data`) and Task 1 round-trip test.
2. A link line inside a fenced code block must stay text, not become a card. Pinned in Task 4 (`splitCardSegments ignores fenced code`).
3. Preview fetch fails (offline, 404, Bilibili error code, non-image thumbnail): the line stays a plain link, no dialog, no crash, and a later edit of the URL retries. Pinned in Task 5 (`returns null on failure`) and Task 7 (`failed fetch leaves plain link`).
4. User deletes a card line, then saves: its preview is dropped from `linkPreviews` and its thumbnail becomes unreferenced (GC-able). Pinned in Task 7 (`removed link line drops preview on save`).
5. Saving twice in one editor session must not lose previews written on the first save (the inline-image reconcile builds from an older snapshot). Pinned in Task 7 (`second save keeps previews`).

---

## Stage 0 — compatibility build

### Task 1: NoteAttachments keeps what it doesn't understand

**Files:**
- Modify: `lib/core/data/attachments/attachment_ref.dart` (class `NoteAttachments`, ~line 175)
- Modify: `lib/core/data/attachments/attachment_ref_codec.dart`
- Test: `test/core/data/attachments/note_attachments_preserve_test.dart` (create)

**Interfaces:**
- Produces:
  - `class UnsupportedAttachmentException extends FormatException` (public, in `attachment_ref_codec.dart`). Thrown by `AttachmentRefCodec.fromJson` **only** for an unknown `kind` or a `contentType` not in `_allowedContentTypes`. All other violations keep throwing plain `FormatException`.
  - `NoteAttachments` new optional constructor params and final fields, all stored unmodifiable:
    - `List<Map<String, dynamic>> preservedImages = const []`
    - `List<Map<String, dynamic>> preservedFiles = const []`
    - `Map<String, dynamic> extra = const {}`: unknown top-level keys, plus the raw `primaryImage` when it is unsupported.
  - `NoteAttachments copyWith({AttachmentRef? primaryImage, bool clearPrimaryImage = false, List<AttachmentRef>? images, List<AttachmentRef>? files})`: carries preserved/extra fields unchanged.
  - `Set<String> get vaultPaths`: the paths of every `VaultRef` in primary/images/files, **plus** the `path` of every preserved entry (images, files, and an `extra['primaryImage']` map) whose `kind == 'vault'` and whose `path` is a non-empty `String`.
  - `isEmpty` is false when any preserved list or `extra` is non-empty.
  - `==`, `hashCode` and `toString` include the new fields (use `package:collection` `DeepCollectionEquality`).

- [ ] **Step 1: Write the failing tests** in `note_attachments_preserve_test.dart`:

```dart
const videoRef = {'kind': 'vault', 'path': 'attachments/note-1/clip.mov',
  'contentType': 'video/quicktime', 'byteSize': 900000000};
const photo = {'kind': 'vault', 'path': 'attachments/note-1/a.jpg',
  'contentType': 'image/jpeg', 'byteSize': 10};

test('unknown contentType in files is preserved, not thrown', () {
  final a = NoteAttachmentsCodec.decode(jsonEncode({'images': [photo], 'files': [videoRef]}));
  expect(a.files, isEmpty);
  expect(a.preservedFiles, [videoRef]);
  expect(a.images.single, isA<VaultRef>());
});
test('unknown kind in images is preserved', () {
  final odd = {'kind': 'future', 'x': 1};
  expect(NoteAttachmentsCodec.decode(jsonEncode({'images': [odd]})).preservedImages, [odd]);
});
test('unknown top-level key round-trips', () {
  final raw = jsonEncode({'images': [photo], 'linkPreviews': [{'url': 'https://youtu.be/x'}]});
  final out = jsonDecode(NoteAttachmentsCodec.encode(NoteAttachmentsCodec.decode(raw))!);
  expect(out['linkPreviews'], [{'url': 'https://youtu.be/x'}]);
});
test('unsupported primaryImage is preserved and re-emitted', () {
  final a = NoteAttachmentsCodec.decode(jsonEncode({'primaryImage': videoRef, 'images': []}));
  expect(a.primaryImage, isNull);
  expect(jsonDecode(NoteAttachmentsCodec.encode(a)!)['primaryImage'], videoRef);
});
test('full round trip keeps preserved entries after known ones', () {
  final a = NoteAttachmentsCodec.decode(jsonEncode({'images': [photo], 'files': [videoRef]}));
  final out = jsonDecode(NoteAttachmentsCodec.encode(a)!);
  expect(out['files'], [videoRef]);
  expect(out['images'], [photo]);
});
test('only-preserved payload is not empty and encodes', () {
  final a = NoteAttachmentsCodec.decode(jsonEncode({'files': [videoRef]}));
  expect(a.isEmpty, isFalse);
  expect(NoteAttachmentsCodec.encode(a), isNotNull);
});
test('copyWith keeps preserved data', () {
  final a = NoteAttachmentsCodec.decode(jsonEncode({'files': [videoRef], 'zz': 1}));
  final b = a.copyWith(images: [const VaultRef(path: 'attachments/note-1/b.jpg', contentType: 'image/jpeg', byteSize: 1)]);
  expect(b.preservedFiles, [videoRef]);
  expect(b.extra, {'zz': 1});
});
test('vaultPaths includes preserved vault entries', () {
  final a = NoteAttachmentsCodec.decode(jsonEncode({'images': [photo], 'files': [videoRef]}));
  expect(a.vaultPaths, {'attachments/note-1/a.jpg', 'attachments/note-1/clip.mov'});
});
test('structural errors still throw', () {
  expect(() => NoteAttachmentsCodec.decode('{"files": {}}'), throwsFormatException);
  expect(() => NoteAttachmentsCodec.decode(jsonEncode({'files': [
    {'kind': 'vault', 'contentType': 'image/jpeg', 'byteSize': 1}]})), throwsFormatException);
});
test('AttachmentRefCodec.fromJson still throws on unknown contentType', () {
  expect(() => AttachmentRefCodec.fromJson(videoRef),
      throwsA(isA<UnsupportedAttachmentException>()));
});
```

- [ ] **Step 2: Run** `flutter test test/core/data/attachments/note_attachments_preserve_test.dart`. Expected: FAIL (`preservedFiles` undefined).

- [ ] **Step 3: Implement.**
  - In the codec, `_validateContentType` and the unknown-`kind` branch throw `UnsupportedAttachmentException`.
  - `NoteAttachmentsCodec.fromJson` catches only `UnsupportedAttachmentException`, per entry:
    - A list entry goes into the matching preserved list as its raw map.
    - An unsupported `primaryImage` goes into `extra['primaryImage']`.
    - Every key other than `primaryImage`/`images`/`files` goes into `extra`.
  - `toJson` returns `{...extra, <known keys>}`, so a known non-null `primaryImage` overrides `extra['primaryImage']`.
    - `images` = known, then preserved.
    - `files` = known, then preserved; omitted when both are empty, so today's output stays byte-identical.
  - Disjointness stays enforced on the known refs only.

- [ ] **Step 4: Run** the new test and `flutter test test/core/data/attachments/`. Expected: all PASS (existing rejection tests unchanged).

- [ ] **Step 5: Commit** `feat(attachments): keep unknown attachment entries and keys on round trip`.

### Task 2: Every reader goes through `vaultPaths` / `copyWith`

**Files:**
- Modify: `lib/core/data/vault/vault_gc.dart:99-116`: `collectReferencedVaultPaths` → `paths.addAll(attachments.vaultPaths)`
- Modify: `lib/core/data/local/note_purge_service.dart:204-214`: `_vaultPathsOf` → `NoteAttachmentsCodec.decode(raw).vaultPaths`
- Modify: `lib/features/notes/states/mutate_note_state.dart:141,187,210`: the three `NoteAttachments(...)` rebuilds → `existing.copyWith(...)`
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart:461-464`: reconcile → `base.copyWith(primaryImage: primary, clearPrimaryImage: primary == null, images: images)`
- Modify: `CLAUDE.md`, Data layer & sync, the `vault/ + attachments/` bullet. Add one sentence: the codec preserves unknown entries and keys, and new code must rebuild with `copyWith` and collect paths with `vaultPaths`.
- Test: `test/core/data/vault/vault_gc_test.dart`, `test/features/notes/states/mutate_note_attach_test.dart` (add cases)

**Interfaces:**
- Consumes: Task 1 `copyWith`, `vaultPaths`.

- [ ] **Step 1: Write failing tests.**
  - In `vault_gc_test.dart`, `test('collectReferencedVaultPaths keeps a preserved video path', …)`:
    - Insert a note row whose `attachments` is `jsonEncode({'files': [videoRef]})`.
    - Expect the result to contain `'attachments/note-1/clip.mov'`, and a `VaultGc` sweep not to delete that file.
    - Use the file's existing in-memory DB setup.
  - In `mutate_note_attach_test.dart`, `test('mutate keeps preserved data', …)`:
    - Seed a note whose attachments decode to `{'files':[videoRef], 'linkPreviews':[{'url':'u'}]}`.
    - Run `attachFileBytes`, and `addImage` through the existing fake picker.
    - Re-read the raw column: `files` still contains `videoRef`, and `linkPreviews` is intact.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement** the edits listed in Files.
  - Afterwards, `grep -rn "NoteAttachments(" lib/features/notes` must show no rebuild of an existing note's attachments outside `copyWith`.
  - The automobile, cheatsheet and licence repositories build attachments for their own entity notes, so they stay unchanged.
- [ ] **Step 4: Run** `flutter test` (full) and `flutter analyze`. Expected: all pass, 2-issue baseline.
- [ ] **Step 5: Commit** `fix(attachments): readers preserve unknown attachment data (video compat)`.
- [ ] **Step 6: STOP — stage 0 gate.** Report to the user and ask to merge and install on iPhone and iPad (backup first). Do not start Task 3 until they confirm both devices run it.

---

## Stage 1 — video link cards

### Task 3: `LinkPreview` in `NoteAttachments`

**Files:**
- Create: `lib/core/data/attachments/link_preview.dart`
- Modify: `lib/core/data/attachments/attachment_ref.dart`, `attachment_ref_codec.dart`
- Test: `test/core/data/attachments/link_preview_codec_test.dart` (create)

**Interfaces:**
- Produces:
  - `enum LinkProvider { youtube, bilibili, web }`, with `wireName` and `fromWire(String)`. An unknown wire value maps to `web`.
  - `final class LinkPreview { final String url; final LinkProvider provider; final String title; final int? durationSeconds; final VaultRef? thumbnail; }` with `==`/`hashCode`, `Map<String,dynamic> toJson()`, `static LinkPreview fromJson(Map<String,dynamic>)`.
    - JSON: `{"url","provider","title","durationSeconds"?,"thumbnail"?}`, where `thumbnail` goes through `AttachmentRefCodec`.
    - `fromJson` throws `FormatException` when `url` or `title` is missing.
  - `NoteAttachments.linkPreviews` (`List<LinkPreview>`, default `const []`):
    - a `copyWith(linkPreviews:)` parameter;
    - included in `isEmpty` and equality;
    - `vaultPaths` adds each `thumbnail.path`.
  - `NoteAttachments.preservedLinkPreviews` (`List<Map<String,dynamic>>`).
  - Codec key `linkPreviews`, omitted when both lists are empty:
    - An entry that fails `LinkPreview.fromJson` is kept raw in `preservedLinkPreviews` and re-emitted after the valid ones.
    - A non-list value goes to `extra` unchanged.

- [ ] **Step 1: Write failing tests:**
  - `round-trips a youtube preview with thumbnail` (encode → decode equal)
  - `durationSeconds omitted when null`
  - `unknown provider decodes as web`
  - `invalid entry is preserved and re-emitted`
  - `vaultPaths includes link thumbnails`
  - `empty linkPreviews keeps old byte-identical output` (encode `{'images':[photo]}` unchanged)
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.** `linkPreviews` is now a known key, so it no longer lands in `extra`.
- [ ] **Step 4: Run** `flutter test test/core/data/attachments/`. PASS.
- [ ] **Step 5: Commit** `feat(notes): link previews in note attachments`.

### Task 4: Recognise video links and split a body into card segments

**Files:**
- Create: `lib/features/notes/links/video_link.dart`
- Test: `test/features/notes/links/video_link_test.dart`

**Interfaces:**
- Produces (pure Dart, no Flutter imports):
  - `sealed class VideoLinkTarget`, with `YouTubeTarget(String videoId)`, `BilibiliTarget({String? bvid, int? aid})`, and `ShortLinkTarget(Uri uri)` (b23.tv, needs a redirect).
  - `VideoLinkTarget? parseVideoLink(String url)`. Recognises, over http or https:
    - YouTube: `youtube.com/watch?v=ID`, `m.youtube.com/watch?v=ID`, `youtu.be/ID`, `youtube.com/shorts/ID`. ID is 11 chars `[A-Za-z0-9_-]`. Extra query params are allowed.
    - Bilibili: `bilibili.com/video/BV…` (`BV[0-9A-Za-z]{10}`), `bilibili.com/video/av123`, `m.bilibili.com/video/…`.
    - Short links: `b23.tv/<code>`.
    - Anything else returns null.
  - `String? standaloneUrl(String line)`: the trimmed line if it is exactly one `http(s)://` URL with no spaces, otherwise null.
  - `sealed class BodySegment`, with `MarkdownSegment(String text)` and `CardSegment(String url)`.
  - `List<BodySegment> splitCardSegments(String markdown, Set<String> cardUrls)`:
    - A line becomes a `CardSegment` when `standaloneUrl(line)` is in `cardUrls` and the line is outside a fenced code block. Fences toggle on lines starting with three backticks or `~~~`.
    - Consecutive other lines join with `\n` into one `MarkdownSegment`.
    - Empty segments are dropped.
  - `Set<String> standaloneUrlsIn(String markdown)`: every standalone URL outside fences.

- [ ] **Step 1: Write failing tests:**
  - One `parseVideoLink` expectation per pattern above.
  - `parseVideoLink('https://example.com/watch?v=dQw4w9WgXcQ') == null` and `parseVideoLink('https://youtube.com/watch?v=short') == null`.
  - `standaloneUrl('  https://youtu.be/dQw4w9WgXcQ ')` returns the URL; `standaloneUrl('see https://youtu.be/x')` returns null.
  - `splitCardSegments('a\nhttps://youtu.be/dQw4w9WgXcQ\nb', {'https://youtu.be/dQw4w9WgXcQ'})` → `[Markdown('a'), Card(url), Markdown('b')]`.
  - `splitCardSegments ignores fenced code`: the URL inside a fenced block stays inside one MarkdownSegment.
  - A URL not in `cardUrls` stays markdown.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** PASS.
- [ ] **Step 5: Commit** `feat(notes): recognise video links and card lines`.

### Task 5: Preview fetcher

**Files:**
- Create: `lib/features/notes/links/link_preview_fetcher.dart`
- Test: `test/features/notes/links/link_preview_fetcher_test.dart` (a fake `HttpClientAdapter` returning canned responses per URL)

**Interfaces:**
- Consumes: Task 4 `parseVideoLink`, `VideoLinkTarget`; Task 3 `LinkProvider`.
- Produces:
  - `class FetchedLinkPreview { final String url; final LinkProvider provider; final String title; final int? durationSeconds; final Uint8List? thumbnailBytes; final String? thumbnailContentType; }`
  - `class LinkPreviewFetcher { LinkPreviewFetcher(Dio dio); Future<FetchedLinkPreview?> fetch(String url); }`. It never throws and returns null on any failure. `url` in the result is the original string.
  - `final linkPreviewFetcherProvider = Provider<LinkPreviewFetcher>((ref) => LinkPreviewFetcher(Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 8), headers: {'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148'}))));`. This is a plain Dio, with none of the app's auth or logging interceptors.
- Fetch rules (values pinned):
  - **YouTube:** `GET https://www.youtube.com/oembed?url=<encoded original url>&format=json` → `title`, `thumbnail_url`. `durationSeconds` is null, so the YouTube length is hidden (spec §6.1).
  - **Bilibili:** `GET https://api.bilibili.com/x/web-interface/view?bvid=<bvid>` (or `?aid=<aid>`). Require `code == 0`, then read `data.title`, `data.pic` (rewrite `http://` to `https://`) and `data.duration` (int seconds).
  - **b23.tv:** `GET` the short URL with redirects followed, take `response.realUri`, run `parseVideoLink` on it, then fetch as Bilibili. The provider is `bilibili`.
  - **Web (any other http/https):**
    - `GET` the page as `ResponseType.plain`, reading the first 512 KiB.
    - Regex-extract the `og:title` and `og:image` meta tags (either attribute order), and HTML-unescape `&amp; &quot; &#39; &lt; &gt;`.
    - No `og:title` returns null. The provider is `web`.
  - **Thumbnail:** `GET` the bytes. Keep them only if they are ≤ 2 MiB and the content type is one of `image/jpeg`, `image/png`, `image/webp`; otherwise `thumbnailBytes` is null.

- [ ] **Step 1: Write failing tests**, one per rule, with canned JSON/HTML:
  - `youtube oembed`: title set, duration null, bytes set.
  - `bilibili view api`: duration 125, and the `http` pic is fetched over `https`.
  - `b23 short link follows redirect`.
  - `web og tags`.
  - `returns null on failure`: 404 / `code: -404` / timeout / no og:title.
  - `oversized or non-image thumbnail dropped`.
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** PASS.
- [ ] **Step 5: Commit** `feat(notes): fetch video link previews`.

### Task 6: `VideoLinkCard` and card rendering in note bodies

**Files:**
- Create: `lib/features/notes/presentation/widgets/video_link_card.dart`
- Modify: `lib/features/notes/presentation/widgets/note_markdown_body.dart` (`NoteMarkdownBody` and `MarkdownView`)
- Modify: `lib/features/notes/presentation/screens/note_detail_screen.dart:314`: `MarkdownView(markdown, linkCards: …)`, built from `d.note.effectiveAttachments.linkPreviews`
- Modify: `lib/core/help/help_registry.dart`: `HelpId.noteDetail` gains an entry with icon `Icons.smart_display_outlined`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/notes/presentation/widgets/video_link_card_test.dart`, plus new cases in `note_markdown_body_test.dart`

**Interfaces:**
- Consumes: Task 3 `LinkPreview`, `LinkProvider`; Task 4 `splitCardSegments`.
- Produces:
  - `class LinkCardData { final String url; final LinkProvider provider; final String title; final int? durationSeconds; final VaultRef? thumbnail; final Uint8List? thumbnailBytes; }`, plus factory `LinkCardData.fromPreview(LinkPreview)`.
  - `class VideoLinkCard extends StatefulWidget { const VideoLinkCard({super.key, required LinkCardData data, IAttachmentResolver? resolver, Future<bool> Function(Uri)? launch}); }`. `launch` defaults to `launchUrl(uri, mode: LaunchMode.externalApplication)`.
  - `NoteMarkdownBody` gets an optional `Map<String, LinkCardData> linkCards = const {}`:
    - When non-empty, it renders `Column(children: …)` over `splitCardSegments(data, linkCards.keys.toSet())`: a `MarkdownBody` per markdown segment (same builders and `onTapLink` as today) and a `VideoLinkCard` per card segment.
    - When empty, it renders exactly as today.
  - `MarkdownView(this.data, {this.linkCards = const {}})` passes it through.
- Card look (from the mockup):
  - Thumbnail: 16:9, rounded 12, `BoxFit.cover`, with a centred translucent white play circle (44 pt).
  - Length badge bottom-right, as `m:ss` (or `h:mm:ss` from 1 hour). Shown only when `durationSeconds != null`.
  - Below the thumbnail: the title (2 lines, ellipsis), then a small site label: `YouTube`, `Bilibili`, or the URL host for `web`.
  - No thumbnail: just the title row, with a leading play glyph.
  - The whole card is one tap target, with `Semantics(button: true, label: title)`.
  - When `launch` returns false or throws, `notesVideoLinkUnavailable` appears under the title.
- ARB keys (en / zh):
  - `notesVideoLinkUnavailable`: "May no longer be available" / "可能已无法观看"
  - `helpNoteDetailVideoLinkTitle`: "Video links" / "视频链接"
  - `helpNoteDetailVideoLinkBody`: "A YouTube or Bilibili link on its own line shows as a card. Tap it to watch in their app; the ◀ Hmm button at the top-left brings you back to this note." / "单独一行的 YouTube 或哔哩哔哩链接会显示为卡片。点按即可在对应应用中观看；左上角的 ◀ Hmm 按钮可返回此笔记。"

- [ ] **Step 1: Write failing tests:**
  - `card shows title, site label and length` (bilibili, 125 s → `2:05`)
  - `youtube card hides length when null`
  - `tap launches the original url externally` (inject `launch` and assert the Uri)
  - `failed launch shows unavailable text`
  - In `note_markdown_body_test.dart`:
    - `renders a card for a card line and markdown around it`
    - `no linkCards renders exactly as before` (one `MarkdownBody`, no `VideoLinkCard`)
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement**, then run `flutter gen-l10n`.
- [ ] **Step 4: Run** the two test files and `test/core/help/`. PASS.
- [ ] **Step 5: Commit** `feat(notes): video link cards in note view`.

### Task 7: Editor — detect, fetch, "Add video link", save

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Modify: `lib/features/notes/presentation/widgets/media_toolbar.dart` (new `onAddVideoLink` param)
- Modify: `lib/features/notes/states/mutate_note_state.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test:
  - `test/features/notes/presentation/screens/note_editor_video_link_test.dart` (create)
  - `test/features/notes/presentation/widgets/media_toolbar_test.dart`
  - `test/features/notes/states/mutate_note_link_previews_test.dart` (create)

**Interfaces:**
- Consumes: Tasks 3–6.
- Produces:
  - `MutateNote.saveLinkPreviews(int noteId, {required List<LinkPreview> kept, required List<FetchedLinkPreview> added}) → Future<HmmNote?>`:
    - Persists each `added.thumbnailBytes` via the existing picker `persistToVault(noteId:, bytes:, originalName: 'link-thumb', contentTypeHint: thumbnailContentType)`. A thumbnail that fails to persist leaves that preview without a thumbnail.
    - Then writes `current.effectiveAttachments.copyWith(linkPreviews: [...kept, ...addedAsPreviews])`, with the note read fresh from the repository.
  - `MediaToolbar({…, VoidCallback? onAddVideoLink})`: a `HmmIconButton` placed after the note-link button, with icon `adaptiveIcon(context, material: Icons.smart_display_outlined, apple: CupertinoIcons.play_rectangle)` and tooltip `l.notesAddVideoLinkTooltip`.
- Editor behaviour:
  - **State:**
    - `_savedLinks: Map<String, LinkPreview>`, loaded from the note
    - `_pendingLinks: Map<String, FetchedLinkPreview>`
    - `_linkAttempted: Set<String>`
  - **Detect:** runs on body change, debounced 600 ms. For each `standaloneUrlsIn(text)` not in saved, pending or attempted:
    - add it to attempted and call `ref.read(linkPreviewFetcherProvider).fetch(url)`;
    - on a non-null result while mounted, `setState(() => _pendingLinks[url] = r)`;
    - on null, do nothing, and the line stays a plain link.
  - **Preview section:** shown when the body contains `hmm-attachment://` **or** any saved or pending link is a standalone line. It passes `linkCards` built from saved (`fromPreview`) plus pending (`thumbnailBytes`).
  - **"Add video link" button:** opens a dialog (Cupertino on Apple, Material otherwise) with one text field.
    - The field is prefilled from the clipboard when it holds a single http(s) URL.
    - Actions: `commonCancel` / `notesAddVideoLinkAdd`.
    - On Add: if `standaloneUrl` is null, show `notesAddVideoLinkInvalid` inline. Otherwise insert `\n<url>\n` at the cursor, ensuring the URL sits on its own line, and run Detect immediately for that URL (no debounce).
  - **Save:** link reconcile runs **last**, after `_persistInlineImages`, file attach and tags.
    - `present = standaloneUrlsIn(_bodyCtrl.text)`
    - `kept = _savedLinks.values.where((p) => present.contains(p.url))`
    - `added = _pendingLinks.values.where((p) => present.contains(p.url))`
    - Call `saveLinkPreviews` only when the result differs from what is stored. Then refresh `_savedLinks` from the returned note and clear `_pendingLinks`.
- ARB keys (en / zh):
  - `notesAddVideoLinkTooltip`: "Add video link" / "添加视频链接"
  - `notesAddVideoLinkTitle`: "Add video link" / "添加视频链接"
  - `notesAddVideoLinkHint`: "Paste a YouTube or Bilibili link" / "粘贴 YouTube 或哔哩哔哩链接"
  - `notesAddVideoLinkAdd`: "Add" / "添加"
  - `notesAddVideoLinkInvalid`: "That doesn't look like a link" / "这不是有效的链接"

- [ ] **Step 1: Write failing tests.** Override `linkPreviewFetcherProvider` with a fake.
  - Editor (`note_editor_video_link_test.dart`):
    - `pasting a link line shows a card in the preview after fetch`
    - `link inside a sentence is not fetched`
    - `failed fetch leaves plain link` (fake returns null: no card, no dialog)
    - `add video link button inserts the url on its own line and fetches`
    - `invalid url shows inline error`
    - `save writes linkPreviews with a thumbnail` (the raw column has `linkPreviews[0].thumbnail.path`)
    - `removed link line drops preview on save`
    - `second save keeps previews` (save, edit text, save again: `linkPreviews` still present)
  - `media_toolbar_test`: `video link button shows with tooltip and calls back`
  - `mutate_note_link_previews_test`:
    - `failed thumbnail persist saves preview without thumbnail`
    - `keeps preserved and other attachments`
- [ ] **Step 2: Run.** FAIL.
- [ ] **Step 3: Implement**, then run `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter test` (full) and `flutter analyze`. PASS / baseline.
- [ ] **Step 5: Update `CLAUDE.md` and commit.** In the notes row, add one sentence: a YouTube or Bilibili link on its own line becomes a saved preview card (`linkPreviews` in attachments, fetched once, opens externally), with the spec path. Commit `feat(notes): video link cards in the editor`.

---

## After the plan

- **Stage 1 manual checks:** spec §8 Stage 1, on device.
- **Install, only when the user asks:**
  - iPad: `hmm-release.sh --target ipad --deploy --backup-first`.
  - iPhone: `scripts/deploy-prod-ios-device.sh`, backup first.
- **Tracker:** log the landed change through the feature-tracker agent.
- **Next:** stages 2–4 get their own plans.
