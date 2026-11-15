import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/data/attachments/video/remote_video_index.dart';
import 'package:hmm_console/core/data/attachments/video/video_downloads.dart';
import 'package:hmm_console/core/data/attachments/video/video_platform.dart';
import 'package:hmm_console/core/data/attachments/video_attachment.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/vault/vault_file_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart' show VaultEntry;
import 'package:hmm_console/features/notes/presentation/widgets/inline_video_player.dart';
import 'package:hmm_console/features/notes/presentation/widgets/video_tile.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/data/attachments/video/fake_video_platform.dart';
import 'fake_video_controller.dart';

class _Files implements IVaultFileStore {
  _Files(this.file);
  final File? file;
  @override
  Future<List<VaultEntry>> listOffloaded() async => const [];
  @override
  Future<void> deleteOffloaded(String p) async {}
  @override
  Future<DateTime?> offloadedModified(String p) async => null;
  @override
  Future<int> deleteStaleParts() async => 0;
  @override
  Future<void> importFile(String p, File s) async {}
  @override
  Future<File?> localFile(String p) async => file;
  @override
  Future<void> offload(String p) async {}
  @override
  File? downloadTarget(String p) => null;
}

class _Mode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.cloudStorage;
}

class _CloudProv extends CloudSyncProvider {
  @override
  bool get supportsLargeFiles => true;
  @override
  Future<bool> largeFileExists(String path) async => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeDownloads extends VideoDownloads {
  _FakeDownloads(this.gate);
  final Completer<VideoFetchResult> gate;
  final fetched = <String>[];
  @override
  Future<VideoFetchResult> fetch(String path) {
    fetched.add(path);
    state = {path: 0.25};
    return gate.future.whenComplete(() {
      if (ref.mounted) state = const {};
    });
  }

  final cancelled = <String>[];
  @override
  void cancel(String path) => cancelled.add(path);
}

const _path = 'attachments/note-1/u1.mov';

const _saved = VideoAttachment(
  video: VaultRef(path: _path, contentType: 'video/quicktime', byteSize: 5),
  durationMs: 48000,
);

void main() {
  late FakeVideoPlatform platform;
  late List<FakeVideoController> controllers;

  setUp(() {
    platform = FakeVideoPlatform();
    controllers = [];
  });

  VideoPlayerController factory(File f) {
    final c = FakeVideoController();
    controllers.add(c);
    return c;
  }

  Future<void> pumpTile(
    WidgetTester tester, {
    required Size size,
    File? file,
    List<Override> extra = const [],
    VideoPlayerController Function(File)? controllerFactory,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoPlatformProvider.overrideWithValue(platform),
          vaultFileStoreProvider.overrideWith((ref) async => _Files(file)),
          ...extra,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: VideoTile(
                saved: _saved,
                inlineControllerFactory: controllerFactory ?? factory,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('on a wide screen, tapping a local video shows the inline '
      'player and does not call platform.play', (tester) async {
    await pumpTile(
      tester,
      size: const Size(1024, 768),
      file: File('/v/u1.mov'),
    );
    await tester.tap(find.byType(VideoTile));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(InlineVideoPlayer), findsOneWidget);
    expect(platform.played, isEmpty);
    expect(controllers.single.calls, ['initialize', 'play']);

    // Full screen pauses and hands the position to the native player.
    await controllers.single.seekTo(const Duration(seconds: 7));
    await tester.pump();
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    expect(controllers.single.calls.last, 'pause');
    expect(platform.played, ['/v/u1.mov']);
    expect(platform.playedAt, [7000]);
  });

  testWidgets('on a phone, tapping calls platform.play', (tester) async {
    await pumpTile(tester, size: const Size(390, 844), file: File('/v/u1.mov'));
    await tester.tap(find.byType(VideoTile));
    await tester.pump();
    await tester.pump();
    expect(find.byType(InlineVideoPlayer), findsNothing);
    expect(platform.played, ['/v/u1.mov']);
    expect(platform.playedAt, [null]);
    expect(controllers, isEmpty);
  });

  testWidgets('on a wide screen, a video not on the device downloads with '
      'the ring first, then plays inline', (tester) async {
    final gate = Completer<VideoFetchResult>();
    final downloads = _FakeDownloads(gate);
    final index = RemoteVideoIndex()..update({_path});
    await pumpTile(
      tester,
      size: const Size(1024, 768),
      extra: [
        videoCloudProvider.overrideWithValue(_CloudProv()),
        dataModeProvider.overrideWith(_Mode.new),
        remoteVideoIndexProvider.overrideWithValue(index),
        videoDownloadsProvider.overrideWith(() => downloads),
      ],
    );
    await tester.tap(find.byType(VideoTile));
    await tester.pump();
    await tester.pump();
    expect(downloads.fetched, [_path]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(InlineVideoPlayer), findsNothing);

    // A second tap while downloading cancels rather than starting another
    // fetch (the fake's cancel is a no-op, so the download carries on).
    await tester.tap(find.byType(VideoTile));
    await tester.pump();
    await tester.pump();
    expect(downloads.fetched, [_path]);
    expect(downloads.cancelled, [_path]);

    gate.complete(
      VideoFetchResult(VideoFetchOutcome.ready, File('/v/downloaded.mov')),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(InlineVideoPlayer), findsOneWidget);
    expect(downloads.fetched, [_path]);
    expect(platform.played, isEmpty);
  });

  testWidgets('nothing plays before a tap', (tester) async {
    await pumpTile(
      tester,
      size: const Size(1024, 768),
      file: File('/v/u1.mov'),
    );
    expect(find.byType(InlineVideoPlayer), findsNothing);
    expect(controllers, isEmpty);
    expect(platform.played, isEmpty);
  });

  testWidgets('on a wide screen, an inline player that cannot start falls '
      'back to the full-screen player', (tester) async {
    await pumpTile(
      tester,
      size: const Size(1024, 768),
      file: File('/v/u1.mov'),
      controllerFactory: (_) => FakeVideoController(failInit: true),
    );
    await tester.tap(find.byType(VideoTile));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(InlineVideoPlayer), findsNothing);
    expect(platform.played, ['/v/u1.mov']);
    expect(platform.playedAt, [null]);
  });
}
