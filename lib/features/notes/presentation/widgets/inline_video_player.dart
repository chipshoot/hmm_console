import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/widgets/adaptive_icon.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import 'video_link_card.dart';

/// Plays a video file in place, with a control bar: play/pause, a scrub
/// slider, elapsed and total time, and a full-screen button. Only built after
/// a tap, so it starts playing as soon as the file is open. Streams from the
/// file; never reads it into memory.
class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({
    super.key,
    required this.file,
    required this.aspectRatio,
    required this.onFullScreen,
    this.onInitFailed,
    this.controllerFactory,
  });

  final File file;

  /// Used until the file reports its own size.
  final double aspectRatio;

  /// Called after pausing, with the position to continue from.
  final void Function(Duration position) onFullScreen;

  /// The file could not be opened; the caller shows another player instead.
  final VoidCallback? onInitFailed;

  /// Test seam; defaults to [VideoPlayerController.file].
  final VideoPlayerController Function(File)? controllerFactory;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  late final VideoPlayerController _controller;

  /// Where the thumb sits while being dragged, so it doesn't jump back.
  double? _dragMs;

  @override
  void initState() {
    super.initState();
    final make = widget.controllerFactory ?? VideoPlayerController.file;
    _controller = make(widget.file);
    _controller.addListener(_changed);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.play();
    } catch (e) {
      // Type only: errors can carry file paths.
      debugPrint('InlineVideoPlayer: start failed (${e.runtimeType})');
      if (mounted) widget.onInitFailed?.call();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final v = _controller.value;
    if (v.isPlaying) {
      await _controller.pause();
      return;
    }
    // At the end: start again from the top.
    if (v.duration > Duration.zero && v.position >= v.duration) {
      await _controller.seekTo(Duration.zero);
    }
    await _controller.play();
  }

  Future<void> _fullScreen() async {
    await _controller.pause();
    if (!mounted) return;
    widget.onFullScreen(_controller.value.position);
  }

  static String _time(Duration d) => VideoLinkCard.formatDuration(d.inSeconds);

  Widget _bar(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = _controller.value;
    final totalMs = v.duration.inMilliseconds.toDouble();
    final posMs =
        _dragMs ??
        v.position.inMilliseconds.toDouble().clamp(
          0.0,
          totalMs > 0 ? totalMs : 0.0,
        );
    const text = TextStyle(color: Colors.white, fontSize: 12);
    final theme = Theme.of(context);
    // White glyphs on the dark bar, on every platform.
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(primary: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0x99000000)),
        child: Row(
          children: [
            HmmIconButton(
              icon: v.isPlaying
                  ? adaptiveIcon(
                      context,
                      material: Icons.pause,
                      apple: CupertinoIcons.pause_fill,
                    )
                  : adaptiveIcon(
                      context,
                      material: Icons.play_arrow,
                      apple: CupertinoIcons.play_fill,
                    ),
              tooltip: v.isPlaying ? l.notesVideoPause : l.notesVideoPlay,
              onPressed: v.isInitialized ? _togglePlay : null,
            ),
            Text(_time(Duration(milliseconds: posMs.round())), style: text),
            Expanded(
              child: Slider.adaptive(
                value: posMs.toDouble(),
                max: totalMs > 0 ? totalMs : 1,
                activeColor: Colors.white,
                onChanged: totalMs > 0
                    ? (ms) => setState(() => _dragMs = ms)
                    : null,
                onChangeEnd: (ms) async {
                  await _controller.seekTo(Duration(milliseconds: ms.round()));
                  if (mounted) setState(() => _dragMs = null);
                },
              ),
            ),
            Text(_time(v.duration), style: text),
            HmmIconButton(
              icon: adaptiveIcon(
                context,
                material: Icons.fullscreen,
                apple: CupertinoIcons.fullscreen,
              ),
              tooltip: l.notesVideoFullScreen,
              onPressed: v.isInitialized ? _fullScreen : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _controller.value;
    final aspect = v.isInitialized && v.aspectRatio > 0
        ? v.aspectRatio
        : widget.aspectRatio;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: v.isInitialized
                ? AspectRatio(
                    aspectRatio: aspect,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _bar(context)),
        ],
      ),
    );
  }
}
