import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/video/video_picker.dart';
import '../../../../core/data/attachments/video/video_platform.dart';
import '../../../../core/data/attachments/video_attachment.dart';
import '../../../../l10n/gen/app_localizations.dart';
import 'note_markdown_body.dart' show kInlineImageMaxHeight;
import 'video_link_card.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';

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

/// A video in a note: poster, play button and length. Tap plays it with the
/// system player; long press hands a saved video to [onLongPress]. Exactly
/// one of [saved] or [pending] is set.
class VideoTile extends ConsumerWidget {
  const VideoTile({
    super.key,
    this.saved,
    this.pending,
    this.resolver,
    this.onLongPress,
  }) : assert(
         (saved == null) != (pending == null),
         'set exactly one of saved or pending',
       );

  final VideoAttachment? saved;
  final PickedVideo? pending;
  final IAttachmentResolver? resolver;
  final void Function(VideoAttachment)? onLongPress;

  static String formatLength(int ms) =>
      VideoLinkCard.formatDuration(ms ~/ 1000);

  int? get _durationMs => saved?.durationMs ?? pending?.durationMs;

  double get _aspect {
    final w = saved?.width ?? pending?.width;
    final h = saved?.height ?? pending?.height;
    if (w != null && h != null && w > 0 && h > 0) return w / h;
    return 16 / 9;
  }

  Widget _poster() {
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
      );
    }
    return dark;
  }

  void _play(BuildContext context, WidgetRef ref) {
    final platform = ref.read(videoPlatformProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final pend = pending;
    final video = saved;
    // Not awaited: the native player may never answer if iOS declines to
    // present it, and the tile must not sit on a spinner.
    unawaited(() async {
      try {
        if (pend != null) {
          await platform.play(pend.tempPath);
          return;
        }
        final store = await ref.read(vaultFileStoreProvider.future);
        final file = await store?.localFile(video!.video.path);
        if (file == null) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.notesVideoNotOnDevice)),
          );
          return;
        }
        await platform.play(file.path);
      } catch (e) {
        debugPrint('VideoTile: play failed (${e.runtimeType})');
      }
    }());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ms = _durationMs;
    final video = saved;
    final longPress = video != null && onLongPress != null
        ? () => onLongPress!(video)
        : null;
    return Semantics(
      button: true,
      label: l.notesVideoPlay,
      excludeSemantics: true,
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
                  _poster(),
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
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
                            formatLength(ms),
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
  }
}
