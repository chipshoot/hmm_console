import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart' show VideoPlayerController;

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachments_pulled_signal.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/video/remote_video_index.dart';
import '../../../../core/data/attachments/video/video_cache.dart';
import '../../../../core/data/attachments/video/video_downloads.dart';
import '../../../../core/data/attachments/video/video_picker.dart';
import '../../../../core/data/attachments/video/video_platform.dart';
import '../../../../core/data/attachments/video/video_uploader.dart';
import '../../../../core/data/attachments/video_attachment.dart';
import '../../../../core/data/data_mode.dart';
import '../../../../core/data/sync/video_upload_scheduler.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../core/util/format_bytes.dart';
import '../../states/note_selection.dart' show kNotesWideBreakpoint;
import 'inline_video_player.dart';
import 'note_markdown_body.dart' show kInlineImageMaxHeight;
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/util/format_duration.dart';

/// Dark box with a film glyph: a video with no poster to show. Never reads
/// any bytes.
class VideoPosterPlaceholder extends StatelessWidget {
  const VideoPosterPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF1C1C1E),
    child: Center(
      child: Icon(Icons.movie_outlined, color: Colors.white54, size: 40),
    ),
  );
}

/// Shortest screen side (pt) from which videos play in place. Phones are
/// below it in either orientation (the largest iPhone is 440 pt); the
/// smallest iPad is 744 pt.
const double kInlineVideoMinShortestSide = 600;

/// A video in a note: poster, play button and length. Tap plays it with the
/// system player, or in place on a tablet; long press hands a
/// saved video to [onLongPress]. Exactly one of [saved] or [pending] is set.
class VideoTile extends ConsumerStatefulWidget {
  const VideoTile({
    super.key,
    this.saved,
    this.pending,
    this.resolver,
    this.onLongPress,
    this.inlineControllerFactory,
  }) : assert(
         (saved == null) != (pending == null),
         'set exactly one of saved or pending',
       );

  final VideoAttachment? saved;
  final PickedVideo? pending;
  final IAttachmentResolver? resolver;
  final void Function(VideoAttachment)? onLongPress;

  /// Test seam for the in-place player's controller.
  final VideoPlayerController Function(File)? inlineControllerFactory;

  @override
  ConsumerState<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends ConsumerState<VideoTile> {
  /// The file playing in place (wide screens only); null shows the poster.
  File? _inline;

  VideoAttachment? get saved => widget.saved;
  PickedVideo? get pending => widget.pending;
  IAttachmentResolver? get resolver => widget.resolver;
  void Function(VideoAttachment)? get onLongPress => widget.onLongPress;

  @override
  void didUpdateWidget(VideoTile old) {
    super.didUpdateWidget(old);
    if (old.saved?.video.path != widget.saved?.video.path) _inline = null;
  }

  int? get _durationMs => saved?.durationMs ?? pending?.durationMs;

  double get _aspect {
    final w = saved?.width ?? pending?.width;
    final h = saved?.height ?? pending?.height;
    if (w != null && h != null && w > 0 && h > 0) return w / h;
    return 16 / 9;
  }

  Widget _poster(Listenable retryOn) {
    const dark = VideoPosterPlaceholder();
    final bytes = pending?.posterBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final poster = saved?.poster;
    final r = resolver;
    if (poster != null && r != null) {
      return AttachmentImage(
        ref: poster,
        resolver: r,
        fit: BoxFit.cover,
        errorPlaceholder: dark,
        // The poster can arrive by sync just after the note does.
        retryOn: retryOn,
      );
    }
    return dark;
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    // Read at tap time: a wide screen plays in place, a phone full screen.
    // In place only on tablets: a large phone on its side passes the notes
    // breakpoint but keeps the native full-screen player.
    final size = MediaQuery.sizeOf(context);
    final wide =
        size.width >= kNotesWideBreakpoint &&
        size.shortestSide >= kInlineVideoMinShortestSide;
    final platform = ref.read(videoPlatformProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final downloads = ref.read(videoDownloadsProvider.notifier);
    final storeFuture = ref.read(vaultFileStoreProvider.future);
    final cloud = ref.read(videoCloudEnabledProvider);
    final pend = pending;
    final video = saved;
    void say(String t) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
    try {
      if (pend != null) {
        // Not awaited: the native player may never answer if iOS declines to
        // present it, and the tile must not sit on a spinner.
        unawaited(platform.play(pend.tempPath));
        return;
      }
      final path = video!.video.path;
      if (ref.read(videoDownloadsProvider).containsKey(path)) {
        downloads.cancel(path);
        return;
      }
      final store = await storeFuture;
      var file = await store?.localFile(path);
      if (file == null) {
        if (!cloud) {
          say(l.notesVideoNotOnDevice);
          return;
        }
        final result = await downloads.fetch(path);
        switch (result.outcome) {
          case VideoFetchOutcome.ready:
            file = result.file;
          case VideoFetchOutcome.stillUploading:
            say(l.notesVideoStillUploading);
            return;
          case VideoFetchOutcome.failed:
            say(l.notesVideoDownloadFailed);
            return;
          case VideoFetchOutcome.cancelled:
            return;
        }
      }
      if (file == null) return;
      unawaited(touchVideo(ref.read(videoCacheIndexProvider.future), path));
      if (wide) {
        if (mounted) setState(() => _inline = file);
        return;
      }
      unawaited(platform.play(file.path));
    } catch (e) {
      debugPrint('VideoTile: play failed (${e.runtimeType})');
    }
  }

  Future<void> _askMobileData(
    BuildContext context,
    VideoUploader uploader,
    VideoUploadScheduler scheduler,
    String path,
    int bytes,
  ) async {
    final l = AppLocalizations.of(context);
    final platform = Theme.of(context).platform;
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final body = Text(l.notesVideoMobileDataBody(formatVideoSize(bytes)));
    final title = Text(l.notesVideoMobileDataTitle);
    final bool? ok;
    if (apple) {
      ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: title,
          content: body,
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.notesVideoMobileDataCancel),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.notesVideoMobileDataUpload),
            ),
          ],
        ),
      );
    } else {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: title,
          content: body,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.notesVideoMobileDataCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.notesVideoMobileDataUpload),
            ),
          ],
        ),
      );
    }
    if (ok == true) {
      // Set the flag, then run through the scheduler so the run holds an iOS
      // background task. Type only in the log: errors can carry URLs.
      unawaited(() async {
        try {
          await uploader.setMobileOk(path);
          await scheduler.maybeRun();
        } catch (e) {
          debugPrint('VideoTile: mobile data upload failed (${e.runtimeType})');
        }
      }());
    }
  }

  Widget _chip(String text, {VoidCallback? onTap}) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
    return Positioned(
      left: 8,
      top: 8,
      child: onTap == null ? box : GestureDetector(onTap: onTap, child: box),
    );
  }

  Widget _playButton({required bool cloud, double? progress}) {
    const bg = BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle);
    final glyph = Icon(
      cloud ? Icons.cloud_download_outlined : Icons.play_arrow_rounded,
      color: Colors.white,
      size: 40,
    );
    return Center(
      child: DecoratedBox(
        decoration: bg,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: progress == null
              ? glyph
              : SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                      const Icon(Icons.close, color: Colors.white, size: 18),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Full screen from the in-place player: continue at [position], and
  /// complete with where the user closed it.
  Future<Duration?> _fullScreen(File file, Duration position) async {
    final platform = ref.read(videoPlatformProvider);
    // Listen before presenting, so a quick close is not missed.
    final closed = platform.fullScreenClosed.first;
    try {
      await platform.play(file.path, positionMs: position.inMilliseconds);
      return Duration(milliseconds: await closed);
    } catch (e) {
      // Type only: errors can carry file paths.
      debugPrint('VideoTile: full screen failed (${e.runtimeType})');
      return null;
    }
  }

  /// The in-place player could not open the file: use the system player.
  void _inlineFailed(File file) {
    if (!mounted) return;
    setState(() => _inline = null);
    unawaited(ref.read(videoPlatformProvider).play(file.path));
  }

  /// Builds the hand-back for when the in-place player closes. The platform
  /// is read now: the player usually closes because this tile is going away,
  /// and `ref` is unusable by then.
  VoidCallback _releaseAudio() {
    final platform = ref.read(videoPlatformProvider);
    return () => unawaited(
      platform.releaseAudio().catchError((Object e) {
        debugPrint('VideoTile: audio release failed (${e.runtimeType})');
      }),
    );
  }

  Widget _inlinePlayer(File file, VoidCallback? longPress) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: kInlineImageMaxHeight),
    child: Align(
      alignment: Alignment.topCenter,
      child: AspectRatio(
        aspectRatio: _aspect,
        child: GestureDetector(
          onLongPress: longPress,
          child: InlineVideoPlayer(
            file: file,
            aspectRatio: _aspect,
            onFullScreen: (p) => _fullScreen(file, p),
            onInitFailed: () => _inlineFailed(file),
            onClosed: _releaseAudio(),
            controllerFactory: widget.inlineControllerFactory,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ms = _durationMs;
    final video = saved;
    final path = video?.video.path;
    final cloudMode = ref.watch(dataModeProvider) == DataMode.cloudStorage;
    final cloudEnabled = ref.watch(videoCloudEnabledProvider);
    final uploader = cloudMode ? ref.watch(videoUploaderProvider).value : null;
    final index = cloudMode ? ref.read(remoteVideoIndexProvider) : null;
    final progress = path == null
        ? null
        : ref.watch(videoDownloadsProvider.select((m) => m[path]));
    // Unknown while resolving: look like a local video rather than flicker.
    final isLocal = path == null
        ? true
        : (ref.watch(videoIsLocalProvider(path)).value ?? true);
    final longPress = video != null && onLongPress != null
        ? () => onLongPress!(video)
        : null;
    final inline = _inline;
    if (inline != null) return _inlinePlayer(inline, longPress);
    return ListenableBuilder(
      listenable: Listenable.merge([uploader?.states, index]),
      builder: (context, _) {
        final up = path == null ? null : uploader?.states.value[path];
        final fetchable = !isLocal && cloudEnabled;
        final stillUp = fetchable && index?.has(path) == false;
        final percent = progress == null ? 0 : (progress * 100).floor();
        final label = progress != null
            ? l.notesVideoDownloading('$percent')
            : (fetchable && !stillUp ? l.notesVideoDownload : l.notesVideoPlay);
        String? chipText;
        VoidCallback? chipTap;
        if (stillUp) {
          chipText = l.notesVideoStillUploading;
        } else if (isLocal && up != null) {
          switch (up.phase) {
            case VideoUploadPhase.uploading:
              chipText = l.notesVideoUploading(
                '${(up.fraction * 100).floor()}',
              );
            case VideoUploadPhase.waitingForWifi:
              chipText = l.notesVideoWaitingForWifi;
              chipTap = () => _askMobileData(
                context,
                uploader!,
                ref.read(videoUploadSchedulerProvider),
                path!,
                up.total,
              );
            case VideoUploadPhase.failed:
              chipText = l.notesVideoUploadRetry;
            case VideoUploadPhase.queued:
              break;
          }
        }
        final chip = chipText == null ? null : _chip(chipText, onTap: chipTap);
        return Semantics(
          button: true,
          // The chips are excluded below, so their text joins the label.
          label: chipText == null ? label : '$label, $chipText',
          excludeSemantics: true,
          customSemanticsActions: chipTap == null
              ? null
              : {
                  CustomSemanticsAction(label: l.notesVideoMobileDataUpload):
                      chipTap,
                },
          onTap: () => _play(context, ref),
          onLongPress: longPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: kInlineImageMaxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: AspectRatio(
                aspectRatio: _aspect,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _play(context, ref),
                  onLongPress: longPress,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _poster(ref.watch(attachmentsPulledSignalProvider)),
                      _playButton(
                        cloud: fetchable && !stillUp,
                        progress: progress,
                      ),
                      ?chip,
                      if (ms != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xB3000000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                formatVideoLength(ms),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Whether a saved video's file is on this device. Re-checks when a download
/// of it starts or ends.
final videoIsLocalProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  path,
) async {
  ref.watch(videoDownloadsProvider.select((m) => m.containsKey(path)));
  final store = await ref.watch(vaultFileStoreProvider.future);
  return await store?.localFile(path) != null;
});
