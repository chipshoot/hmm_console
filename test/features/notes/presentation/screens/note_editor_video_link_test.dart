import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref_codec.dart';
import 'package:hmm_console/core/data/attachments/link_preview.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/links/link_preview_fetcher.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/presentation/widgets/video_link_card.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

const _yt = 'https://youtu.be/dQw4w9WgXcQ';

/// A valid 1x1 PNG, so Image.memory decodes it cleanly.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeFetcher implements LinkPreviewFetcher {
  _FakeFetcher({this.fail = false, this.failFirst = false, this.delay});
  final bool fail;
  final bool failFirst;
  final Duration? delay;
  final calls = <String>[];

  @override
  Future<FetchedLinkPreview?> fetch(String url) async {
    calls.add(url);
    if (delay != null) await Future<void>.delayed(delay!);
    if (fail || (failFirst && calls.length == 1)) return null;
    return FetchedLinkPreview(
      url: url,
      provider: LinkProvider.youtube,
      title: 'Never gonna',
      durationSeconds: 213,
      thumbnailBytes: _png,
      thumbnailContentType: 'image/png',
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePicker implements IImageAttachmentPicker {
  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
    bool sensitive = false,
  }) async => VaultRef(
    path: 'attachments/note-$noteId/thumb.png',
    contentType: 'image/png',
    byteSize: bytes.length,
  );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeResolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTags implements ITagRepository {
  @override
  Stream<Map<int, List<NoteTagLabel>>> watchNoteTags() => Stream.value({});

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// One note held in memory.
class _MemRepo implements IHmmNoteRepository {
  HmmNote? note;
  int attachmentWrites = 0;

  @override
  Future<HmmNote?> getNoteById(int id) async => note;

  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    final n = note!;
    if (patch.attachments != null) attachmentWrites++;
    note = HmmNote(
      id: n.id,
      uuid: n.uuid,
      subject: patch.subject ?? n.subject,
      authorId: n.authorId,
      createDate: n.createDate,
      content: patch.content ?? n.content,
      attachments: patch.attachments ?? n.attachments,
    );
    return note!;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// The real MutateNote (so saveLinkPreviews is exercised), with create and
/// update writing straight to the in-memory repo.
class _TestMutate extends MutateNote {
  _TestMutate(super.ref, this.repo);
  final _MemRepo repo;
  int linkSaves = 0;

  @override
  Future<HmmNote> createGeneral({
    required String subject,
    String? markdownBody,
    int? parentNoteId,
    DateTime? noteDate,
    NoteLocation? location,
  }) async {
    repo.note = HmmNote(
      id: 1,
      uuid: 'u1',
      subject: subject,
      authorId: 1,
      createDate: DateTime(2026, 1, 1),
      content: markdownBody,
    );
    return repo.note!;
  }

  @override
  Future<HmmNote> updateGeneral(
    int id, {
    String? subject,
    String? markdownBody,
    DateTime? noteDate,
    NoteLocation? location,
  }) => repo.updateNote(
    id,
    HmmNoteUpdate(subject: subject, content: markdownBody),
  );

  @override
  Future<HmmNote?> saveLinkPreviews(
    int noteId, {
    required Set<String> presentUrls,
    required List<FetchedLinkPreview> added,
  }) {
    linkSaves++;
    return super.saveLinkPreviews(
      noteId,
      presentUrls: presentUrls,
      added: added,
    );
  }
}

class _Harness {
  _Harness({
    bool fail = false,
    bool failFirst = false,
    Duration? delay,
    this.initialLocation = '/new',
    this.platform,
  }) : fetcher = _FakeFetcher(fail: fail, failFirst: failFirst, delay: delay);
  final _FakeFetcher fetcher;
  final String initialLocation;
  final TargetPlatform? platform;
  final repo = _MemRepo();
  _TestMutate? mutate;
  late final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(path: 'new', builder: (c, s) => const NoteEditorScreen()),
          GoRoute(
            path: 'edit',
            builder: (c, s) => const NoteEditorScreen(noteId: 1),
          ),
        ],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkPreviewFetcherProvider.overrideWithValue(fetcher),
          imageAttachmentPickerProvider.overrideWith(
            (ref) async => _FakePicker(),
          ),
          attachmentResolverProvider.overrideWith(
            (ref) async => _FakeResolver(),
          ),
          hmmNoteRepositoryProvider.overrideWith((ref) => repo),
          tagRepositoryProvider.overrideWith((ref) => _FakeTags()),
          mutateNoteProvider.overrideWith(
            (ref) => mutate = _TestMutate(ref, repo),
          ),
          subsystemAnchorsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          theme: ThemeData(
            platform: platform,
            extensions: const [AppColors.light],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Finder get _body => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'Start writing…',
);

TextField _bodyField(WidgetTester tester) => tester.widget<TextField>(_body);

Future<void> _typeBody(WidgetTester tester, String text) async {
  await tester.enterText(_body, text);
  await tester.pump();
  // Past the 600 ms detect debounce, then let the fetch finish.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, {String title = 'Hi'}) async {
  await tester.enterText(find.widgetWithText(TextField, 'Title'), title);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// The attachments column as the database stores it.
Map<String, dynamic> _rawColumn(HmmNote note) =>
    jsonDecode(NoteAttachmentsCodec.encode(note.effectiveAttachments)!)
        as Map<String, dynamic>;

/// What the mocked clipboard holds; null = empty.
String? _clipboard;

void main() {
  // Clipboard reads go through the platform channel; answer them in the
  // test zone so the dialog opens on the next pump.
  setUp(() {
    _clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            final text = _clipboard;
            return text == null ? null : <String, dynamic>{'text': text};
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('pasting a link line shows a card in the preview after fetch', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await _typeBody(tester, 'Watch this\n$_yt\nlater');

    expect(h.fetcher.calls, [_yt]);
    expect(find.byType(VideoLinkCard), findsOneWidget);
    expect(find.text('Never gonna'), findsOneWidget);
  });

  testWidgets('link inside a sentence is not fetched', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _typeBody(tester, 'Watch $_yt now');

    expect(h.fetcher.calls, isEmpty);
    expect(find.byType(VideoLinkCard), findsNothing);
  });

  testWidgets('failed fetch leaves plain link', (tester) async {
    final h = _Harness(fail: true);
    await h.pump(tester);
    await _typeBody(tester, _yt);

    expect(h.fetcher.calls, [_yt]);
    expect(find.byType(VideoLinkCard), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    // Typing more does not refetch a link that already failed.
    await _typeBody(tester, '$_yt\nmore');
    expect(h.fetcher.calls, [_yt]);
  });

  testWidgets('a link line re-added after removal is fetched again', (
    tester,
  ) async {
    final h = _Harness(failFirst: true);
    await h.pump(tester);
    await _typeBody(tester, _yt);
    expect(h.fetcher.calls, [_yt]);
    expect(find.byType(VideoLinkCard), findsNothing);

    await _typeBody(tester, '');
    await _typeBody(tester, _yt);

    expect(h.fetcher.calls, [_yt, _yt]);
    expect(find.byType(VideoLinkCard), findsOneWidget);
  });

  testWidgets('add video link button inserts the url on its own line and '
      'fetches', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.enterText(_body, 'abcd');
    await tester.pump();
    // Cursor between "ab" and "cd".
    final field = _bodyField(tester);
    field.controller!.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();

    await tester.tap(find.byTooltip('Add video link'));
    await tester.pumpAndSettle();
    expect(find.text('Add video link'), findsWidgets);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '  $_yt ',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final ctrl = _bodyField(tester).controller!;
    expect(ctrl.text, 'ab\n$_yt\ncd');
    expect(ctrl.selection.baseOffset, 'ab\n$_yt\n'.length);
    expect(h.fetcher.calls, [_yt]);
    expect(find.byType(VideoLinkCard), findsOneWidget);
  });

  testWidgets('add video link at the start of a line adds no blank line', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.enterText(_body, 'first\n');
    await tester.pump();

    await tester.tap(find.byTooltip('Add video link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      _yt,
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final ctrl = _bodyField(tester).controller!;
    expect(ctrl.text, 'first\n$_yt');
    expect(ctrl.selection.baseOffset, ctrl.text.length);
  });

  testWidgets('add video link prefills from a clipboard link', (tester) async {
    _clipboard = _yt;
    final h = _Harness();
    await h.pump(tester);

    await tester.tap(find.byTooltip('Add video link'));
    await tester.pumpAndSettle();
    final dialogField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(dialogField.controller!.text, _yt);
  });

  testWidgets('invalid url shows inline error', (tester) async {
    final h = _Harness();
    await h.pump(tester);

    await tester.tap(find.byTooltip('Add video link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'not a link',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text("That doesn't look like a link"), findsOneWidget);
    expect(_bodyField(tester).controller!.text, isEmpty);
    expect(h.fetcher.calls, isEmpty);
  });

  testWidgets('save writes linkPreviews with a thumbnail', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _typeBody(tester, 'Watch\n$_yt');
    await _save(tester);

    expect(find.text('home'), findsOneWidget);
    final raw = _rawColumn(h.repo.note!);
    final previews = raw['linkPreviews'] as List;
    expect(previews, hasLength(1));
    final p = previews.first as Map<String, dynamic>;
    expect(p['url'], _yt);
    expect(p['title'], 'Never gonna');
    expect(
      (p['thumbnail'] as Map<String, dynamic>)['path'],
      'attachments/note-1/thumb.png',
    );
  });

  testWidgets('removed link line drops preview on save', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _typeBody(tester, 'Watch\n$_yt');
    await _save(tester);
    expect(h.repo.note!.effectiveAttachments.linkPreviews, hasLength(1));

    h.router.go('/edit');
    await tester.pumpAndSettle();
    await _typeBody(tester, 'Watch');
    await _save(tester);

    expect(h.repo.note!.effectiveAttachments.linkPreviews, isEmpty);
    // The dropped thumbnail is no longer retained, so GC can collect it.
    expect(
      h.repo.note!.effectiveAttachments.vaultPaths,
      isNot(contains('attachments/note-1/thumb.png')),
    );
  });

  testWidgets('second save keeps previews', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _typeBody(tester, 'Watch\n$_yt');
    await _save(tester);
    final writes = h.repo.attachmentWrites;
    expect(writes, 1);

    h.router.go('/edit');
    await tester.pumpAndSettle();
    // The saved preview is a card in the reopened editor, with no refetch.
    expect(find.byType(VideoLinkCard), findsOneWidget);
    await _typeBody(tester, 'Watch closely\n$_yt');
    await _save(tester);

    expect(h.fetcher.calls, [_yt]);
    // Unchanged previews are not rewritten.
    expect(h.repo.attachmentWrites, writes);
    final previews = h.repo.note!.effectiveAttachments.linkPreviews;
    expect(previews, hasLength(1));
    expect(previews.single.thumbnail?.path, 'attachments/note-1/thumb.png');
    expect(h.repo.note!.content, 'Watch closely\n$_yt');
  });

  testWidgets('plain web link is not fetched', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await _typeBody(tester, 'Read\nhttps://example.com/article');
    await _save(tester);

    expect(h.fetcher.calls, isEmpty);
    expect(h.repo.note!.effectiveAttachments.linkPreviews, isEmpty);
  });

  testWidgets('add video link does not read the clipboard on iOS', (
    tester,
  ) async {
    _clipboard = _yt;
    final h = _Harness(platform: TargetPlatform.iOS);
    await h.pump(tester);

    await tester.tap(find.byTooltip('Add video link'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final field = tester.widget<CupertinoTextField>(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('link pasted right before save still gets a card', (
    tester,
  ) async {
    final h = _Harness(delay: const Duration(seconds: 2));
    await h.pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Hi');
    await tester.enterText(_body, 'Watch\n$_yt');
    await tester.pump();
    // Save before the 600 ms debounce fires.
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(h.fetcher.calls, [_yt]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    final previews = h.repo.note!.effectiveAttachments.linkPreviews;
    expect(previews.single.url, _yt);
    expect(previews.single.thumbnail?.path, 'attachments/note-1/thumb.png');
  });

  testWidgets('slow fetch past the cap saves without card', (tester) async {
    final h = _Harness(delay: const Duration(seconds: 8));
    await h.pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Hi');
    await tester.enterText(_body, 'Watch\n$_yt');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(h.repo.note!.content, 'Watch\n$_yt');
    expect(h.repo.note!.effectiveAttachments.linkPreviews, isEmpty);
    // Let the abandoned fetch finish; the closed editor ignores it.
    await tester.pump(const Duration(seconds: 3));
    expect(h.repo.note!.effectiveAttachments.linkPreviews, isEmpty);
  });

  testWidgets('opening a note with an unpreviewed link line fetches it', (
    tester,
  ) async {
    final h = _Harness(initialLocation: '/edit');
    h.repo.note = HmmNote(
      id: 1,
      uuid: 'u1',
      subject: 'Old note',
      authorId: 1,
      createDate: DateTime(2026, 1, 1),
      content: 'Watch\n$_yt',
    );
    await h.pump(tester);

    expect(h.fetcher.calls, [_yt]);
    expect(find.byType(VideoLinkCard), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(h.repo.note!.effectiveAttachments.linkPreviews.single.url, _yt);
  });
}
