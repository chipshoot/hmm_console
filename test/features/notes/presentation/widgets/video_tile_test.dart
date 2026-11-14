import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/attachments_pulled_signal.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/data/attachments/video/video_picker.dart';
import 'package:hmm_console/core/data/attachments/video/video_platform.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/core/data/attachments/widgets/attachment_image.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/features/notes/presentation/widgets/note_markdown_body.dart';
import 'package:hmm_console/features/notes/presentation/widgets/video_tile.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../../../../core/data/attachments/video/fake_video_platform.dart';

class _Files implements IVaultFileStore {
  _Files(this.file);
  final File? file;
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  Future<File?> localFile(String p) async => file;
}

class _Resolver implements IAttachmentResolver {
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(Widget child, FakeVideoPlatform platform, {File? file}) =>
    ProviderScope(
      overrides: [
        videoPlatformProvider.overrideWithValue(platform),
        vaultFileStoreProvider.overrideWith((ref) async => _Files(file)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

const _saved = VideoAttachment(
  video: VaultRef(
    path: 'attachments/note-1/u1.mov',
    contentType: 'video/quicktime',
    byteSize: 5,
  ),
  poster: VaultRef(
    path: 'attachments/note-1/u1.jpg',
    contentType: 'image/jpeg',
    byteSize: 5,
  ),
  durationMs: 48000,
);

void main() {
  testWidgets('shows the length', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VideoTile(saved: _saved, resolver: _Resolver()),
        FakeVideoPlatform(),
      ),
    );
    expect(find.text('0:48'), findsOneWidget);
  });

  testWidgets('tapping a pending tile plays the temp file', (tester) async {
    final platform = FakeVideoPlatform();
    await tester.pumpWidget(
      _wrap(
        const VideoTile(
          pending: PickedVideo(
            tempPath: '/tmp/x.mov',
            originalName: 'x.mov',
            contentType: 'video/quicktime',
            byteSize: 3,
          ),
        ),
        platform,
      ),
    );
    await tester.tap(find.byType(VideoTile));
    await tester.pump();
    expect(platform.played, ['/tmp/x.mov']);
  });

  testWidgets('missing local file shows not-on-device', (tester) async {
    final platform = FakeVideoPlatform();
    await tester.pumpWidget(_wrap(const VideoTile(saved: _saved), platform));
    await tester.tap(find.byType(VideoTile));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('This video is only on the device that added it, for now.'),
      findsOneWidget,
    );
    expect(platform.played, isEmpty);
  });

  testWidgets('a saved tile with a local file plays it', (tester) async {
    final platform = FakeVideoPlatform();
    await tester.pumpWidget(
      _wrap(const VideoTile(saved: _saved), platform, file: File('/v/u1.mov')),
    );
    await tester.tap(find.byType(VideoTile));
    await tester.pump();
    await tester.pump();
    expect(platform.played, ['/v/u1.mov']);
  });

  testWidgets('VoiceOver gets the long-press menu of a saved tile', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    VideoAttachment? pressed;
    await tester.pumpWidget(
      _wrap(
        VideoTile(saved: _saved, onLongPress: (v) => pressed = v),
        FakeVideoPlatform(),
      ),
    );
    final node = tester.getSemantics(find.byType(VideoTile));
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.longPress),
      isTrue,
    );
    tester.semantics.longPress(find.semantics.byLabel('Play video'));
    expect(pressed, same(_saved));
    handle.dispose();
  });

  testWidgets('body renders one video tile and one image', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NoteMarkdownBody(
          data:
              '![Video](hmm-attachment://attachments/note-1/u1.jpg)\n\n'
              '![Photo](hmm-attachment://attachments/note-1/p.jpg)',
          resolver: _Resolver(),
          videos: {'attachments/note-1/u1.jpg': _saved},
          selectable: false,
        ),
        FakeVideoPlatform(),
      ),
    );
    await tester.pump();
    expect(find.byType(VideoTile), findsOneWidget);
    // The video's poster and the photo both load through AttachmentImage.
    expect(find.byType(AttachmentImage), findsNWidgets(2));
  });

  testWidgets('a poster that synced in after the first try appears when the '
      'sync reports downloaded files', (tester) async {
    final resolver = _LateResolver();
    await tester.pumpWidget(
      _wrap(
        VideoTile(saved: _saved, resolver: resolver),
        FakeVideoPlatform(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VideoPosterPlaceholder), findsOneWidget);

    resolver.bytes = _png;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VideoTile)),
    );
    container
        .read(attachmentsPulledSignalProvider)
        .onSyncResult(
          SyncResult(
            pulledNotes: 0,
            pulledAttachments: 1,
            pushedNotes: 0,
            pushedAttachments: 0,
            completedAt: DateTime.utc(2026, 11, 14),
          ),
        );
    await tester.pumpAndSettle();

    expect(find.byType(VideoPosterPlaceholder), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}

class _LateResolver implements IAttachmentResolver {
  Uint8List? bytes;
  @override
  Future<Uint8List?> resolve(AttachmentRef ref) async => bytes;
}

// 1x1 PNG.
final Uint8List _png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
