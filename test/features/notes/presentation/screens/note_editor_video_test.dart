import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/attachments/video/video_attachment_store.dart';
import 'package:hmm_console/core/data/attachments/video/video_picker.dart';
import 'package:hmm_console/core/data/attachments/video/video_platform.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/hmm_note_input.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/note_location.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/data/vault/encrypted_vault_store.dart'
    show VaultLockedException;
import 'package:hmm_console/core/theme/app_colors.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/data/subsystem_anchor.dart';
import 'package:hmm_console/features/notes/links/link_preview_fetcher.dart';
import 'package:hmm_console/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:hmm_console/features/notes/states/mutate_note_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../../../../core/data/attachments/video/fake_video_platform.dart';

const _savedVideo = VideoAttachment(
  video: VaultRef(
    path: 'attachments/note-1/v1.mov',
    contentType: 'video/quicktime',
    byteSize: 5,
  ),
  poster: VaultRef(
    path: 'attachments/note-1/v1.jpg',
    contentType: 'image/jpeg',
    byteSize: 3,
  ),
  durationMs: 48000,
);

const _photo = VaultRef(
  path: 'attachments/note-1/p.png',
  contentType: 'image/png',
  byteSize: 3,
);

const _videoLine = '![Video](hmm-attachment://attachments/note-1/v1.jpg)';
const _photoLine = '![p](hmm-attachment://attachments/note-1/p.png)';

/// A valid 1x1 PNG, so Image.memory decodes it cleanly.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FixedDataMode extends DataModeNotifier {
  _FixedDataMode(this.mode);
  final DataMode mode;
  @override
  DataMode build() => mode;
}

class _FakeFetcher implements LinkPreviewFetcher {
  @override
  Future<FetchedLinkPreview?> fetch(String url) async => null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeImagePicker implements IImageAttachmentPicker {
  _FakeImagePicker({this.throwLocked = false});
  final bool throwLocked;
  var _n = 0;

  @override
  Future<VaultRef> persistToVault({
    required int noteId,
    required Uint8List bytes,
    required String originalName,
    String? contentTypeHint,
    bool sensitive = false,
  }) async {
    if (throwLocked) throw const VaultLockedException('x');
    return VaultRef(
      path: 'attachments/note-$noteId/img${_n++}.png',
      contentType: 'image/png',
      byteSize: bytes.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeImageSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(
        bytes: _png,
        originalName: 'photo.png',
        contentType: 'image/png',
      );
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

/// Returns [result] or throws [error] from pick().
class _FakeVideoPicker implements VideoPicker {
  _FakeVideoPicker({this.result, this.error});
  PickedVideo? result;
  VideoPickException? error;
  int calls = 0;

  @override
  Future<PickedVideo?> pick() async {
    calls++;
    if (error != null) throw error!;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeVideoStore implements VideoAttachmentStore {
  final persisted = <PickedVideo>[];

  @override
  Future<VideoAttachment> persist({
    required int noteId,
    required PickedVideo pick,
  }) async {
    persisted.add(pick);
    return VideoAttachment(
      video: VaultRef(
        path: 'attachments/note-$noteId/new.mov',
        contentType: pick.contentType,
        byteSize: pick.byteSize,
      ),
      poster: VaultRef(
        path: 'attachments/note-$noteId/new.jpg',
        contentType: 'image/jpeg',
        byteSize: 3,
      ),
      durationMs: pick.durationMs,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _MemRepo implements IHmmNoteRepository {
  HmmNote? note;

  @override
  Future<HmmNote?> getNoteById(int id) async => note;

  @override
  Future<HmmNote> updateNote(int id, HmmNoteUpdate patch) async {
    final n = note!;
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

class _TestMutate extends MutateNote {
  _TestMutate(super.ref, this.repo);
  final _MemRepo repo;

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
}

class _Harness {
  _Harness({
    this.mode = DataMode.local,
    this.initialLocation = '/new',
    PickedVideo? pick,
    VideoPickException? error,
    this.imageLocked = false,
  }) : picker = _FakeVideoPicker(result: pick, error: error);
  final DataMode mode;
  final bool imageLocked;
  final String initialLocation;
  final _FakeVideoPicker picker;
  final store = _FakeVideoStore();
  final repo = _MemRepo();

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
          dataModeProvider.overrideWith(() => _FixedDataMode(mode)),
          videoPlatformProvider.overrideWithValue(FakeVideoPlatform()),
          videoPickerProvider.overrideWithValue(picker),
          videoAttachmentStoreProvider.overrideWith((ref) async => store),
          linkPreviewFetcherProvider.overrideWithValue(_FakeFetcher()),
          imageByteSourceProvider.overrideWithValue(_FakeImageSource()),
          imageAttachmentPickerProvider.overrideWith(
            (ref) async => _FakeImagePicker(throwLocked: imageLocked),
          ),
          attachmentResolverProvider.overrideWith(
            (ref) async => _FakeResolver(),
          ),
          hmmNoteRepositoryProvider.overrideWith((ref) => repo),
          tagRepositoryProvider.overrideWith((ref) => _FakeTags()),
          mutateNoteProvider.overrideWith((ref) => _TestMutate(ref, repo)),
          subsystemAnchorsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          theme: ThemeData(extensions: const [AppColors.light]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Finder get _body => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'Start writing…',
);

TextEditingController _bodyCtrl(WidgetTester tester) =>
    tester.widget<TextField>(_body).controller!;

Future<void> _save(WidgetTester tester, {String? title = 'Hi'}) async {
  if (title != null) {
    await tester.enterText(find.widgetWithText(TextField, 'Title'), title);
  }
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Future<void> _tapAddVideo(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Add video'));
  await tester.pumpAndSettle();
}

/// Lets real file I/O started inside the fake-async zone finish.
Future<bool> _exists(WidgetTester tester, String path) async {
  var exists = true;
  await tester.runAsync(() async {
    for (var i = 0; i < 20; i++) {
      exists = File(path).existsSync();
      if (!exists) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  return exists;
}

late Directory _tmp;

PickedVideo _pickOf(String name, {int byteSize = 1000}) {
  final f = File('${_tmp.path}/$name')..writeAsBytesSync(const [0, 1, 2]);
  return PickedVideo(
    tempPath: f.path,
    originalName: name,
    contentType: 'video/quicktime',
    byteSize: byteSize,
    posterBytes: _png,
    durationMs: 5000,
    width: 1920,
    height: 1080,
  );
}

HmmNote _loaded({NoteAttachments? atts, String? body}) => HmmNote(
  id: 1,
  uuid: 'u1',
  subject: 'Trip',
  authorId: 1,
  createDate: DateTime(2026, 1, 1),
  content: body ?? 'a\n\n$_videoLine\n\n$_photoLine\n\nb',
  attachments:
      atts ?? NoteAttachments(images: [_photo], videos: [_savedVideo]),
);

void main() {
  setUp(() {
    _tmp = Directory.systemTemp.createTempSync('note_editor_video_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    try {
      _tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('new video and new image saved together', (tester) async {
    final pick = _pickOf('clip.mov');
    final h = _Harness(pick: pick);
    await h.pump(tester);

    await _tapAddVideo(tester);
    expect(_bodyCtrl(tester).text, contains('![Video](hmm-attachment://pending/'));
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(find.text('home'), findsOneWidget);
    expect(h.store.persisted, [pick]);
    final note = h.repo.note!;
    expect(note.content, isNot(contains('pending/')));
    expect(
      note.content,
      contains('![Video](hmm-attachment://attachments/note-1/new.jpg)'),
    );
    expect(note.content, contains('hmm-attachment://attachments/note-1/img0.png'));
    final atts = note.effectiveAttachments;
    expect(atts.images.map((r) => (r as VaultRef).path), [
      'attachments/note-1/img0.png',
    ]);
    expect(atts.videos, hasLength(1));
    expect(atts.videos.single.video.path, 'attachments/note-1/new.mov');
    expect(atts.videos.single.inlinePath, 'attachments/note-1/new.jpg');
  });

  testWidgets('image step locked after a video persisted: video recorded', (
    tester,
  ) async {
    final pick = _pickOf('clip.mov');
    final h = _Harness(pick: pick, imageLocked: true);
    await h.pump(tester);

    await _tapAddVideo(tester);
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await _save(tester);

    // The save aborted at the image step: still on the editor.
    expect(find.text('home'), findsNothing);
    expect(h.store.persisted, [pick]);
    final note = h.repo.note!;
    expect(
      note.content,
      contains('![Video](hmm-attachment://attachments/note-1/new.jpg)'),
    );
    final videos = note.effectiveAttachments.videos;
    expect(videos, hasLength(1));
    expect(videos.single.video.path, 'attachments/note-1/new.mov');
  });

  testWidgets('pending video removed before save leaves nothing', (
    tester,
  ) async {
    final pick = _pickOf('clip.mov');
    final h = _Harness(pick: pick);
    await h.pump(tester);

    await _tapAddVideo(tester);
    expect(_bodyCtrl(tester).text, contains('pending/'));
    await tester.enterText(_body, 'just text');
    await tester.pump();
    await _save(tester);

    expect(find.text('home'), findsOneWidget);
    expect(h.store.persisted, isEmpty);
    expect(await _exists(tester, pick.tempPath), isFalse);
    expect(h.repo.note!.effectiveAttachments.videos, isEmpty);
    expect(h.repo.note!.content, 'just text');
  });

  for (final remove in [false, true]) {
    testWidgets('deleting a saved video line asks once, about videos '
        '(${remove ? 'Remove' : 'Keep'})', (tester) async {
      final h = _Harness(initialLocation: '/edit');
      h.repo.note = _loaded();
      await h.pump(tester);

      await tester.enterText(_body, 'a\n\n$_photoLine\n\nb');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Remove 1 video from this note?'), findsOneWidget);
      expect(find.text('Remove stored images?'), findsNothing);
      await tester.tap(find.text(remove ? 'Remove' : 'Keep'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      final atts = h.repo.note!.effectiveAttachments;
      expect(atts.videos.length, remove ? 0 : 1);
      expect(atts.images, [_photo]);
    });
  }

  testWidgets('cloudApi shows the OneDrive message and never picks', (
    tester,
  ) async {
    final h = _Harness(mode: DataMode.cloudApi, pick: _pickOf('clip.mov'));
    await h.pump(tester);
    await _tapAddVideo(tester);

    expect(find.text('Videos need OneDrive sync for now'), findsOneWidget);
    expect(h.picker.calls, 0);
    expect(_bodyCtrl(tester).text, isEmpty);
  });

  testWidgets('sensitive note blocks videos and never picks', (tester) async {
    final h = _Harness(initialLocation: '/edit', pick: _pickOf('clip.mov'));
    h.repo.note = _loaded(
      body: 'secret',
      atts: NoteAttachments(
        images: [
          VaultRef(
            path: 'sensitive/note-1/s.png',
            contentType: 'image/png',
            byteSize: 3,
            sensitive: true,
          ),
        ],
      ),
    );
    await h.pump(tester);
    await _tapAddVideo(tester);

    expect(
      find.text("Videos can't be added to notes with sensitive items yet"),
      findsOneWidget,
    );
    expect(h.picker.calls, 0);
    expect(_bodyCtrl(tester).text, 'secret');
  });

  testWidgets('large video asks; Cancel adds nothing and deletes the temp', (
    tester,
  ) async {
    final pick = _pickOf('big.mov', byteSize: 600 * 1024 * 1024);
    final h = _Harness(pick: pick);
    await h.pump(tester);
    await _tapAddVideo(tester);

    expect(find.text('Large video'), findsOneWidget);
    expect(
      find.text('This video is 600 MB. It uses that much space on this device.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Large video'), findsNothing);
    expect(_bodyCtrl(tester).text, isEmpty);
    expect(await _exists(tester, pick.tempPath), isFalse);
  });

  testWidgets('large video in cloudStorage names OneDrive; Add inserts it', (
    tester,
  ) async {
    final pick = _pickOf('big.mov', byteSize: 1395864371); // ~1.3 GB
    final h = _Harness(mode: DataMode.cloudStorage, pick: pick);
    await h.pump(tester);
    await _tapAddVideo(tester);

    expect(
      find.text('This video is 1.3 GB. It uses that much OneDrive space.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(_bodyCtrl(tester).text, contains('![Video](hmm-attachment://pending/'));
  });

  testWidgets('too large shows the message and adds nothing', (tester) async {
    final h = _Harness(
      error: const VideoPickException(VideoPickError.tooLarge),
    );
    await h.pump(tester);
    await _tapAddVideo(tester);

    expect(
      find.text("This video is over 2 GB and can't be added"),
      findsOneWidget,
    );
    expect(h.picker.calls, 1);
    expect(_bodyCtrl(tester).text, isEmpty);
  });

  testWidgets('unsupported shows the message', (tester) async {
    final h = _Harness(
      error: const VideoPickException(VideoPickError.unsupported),
    );
    await h.pump(tester);
    await _tapAddVideo(tester);

    expect(find.text("This video format isn't supported"), findsOneWidget);
    expect(_bodyCtrl(tester).text, isEmpty);
  });
}
