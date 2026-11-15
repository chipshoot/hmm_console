import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// A [VideoPlayerController] that never touches the platform. Its player id
/// stays uninitialized, so [VideoPlayer] draws an empty box.
class FakeVideoController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  FakeVideoController({
    this.length = const Duration(seconds: 48),
    this.failInit = false,
  }) : super(const VideoPlayerValue.uninitialized());

  final Duration length;
  final bool failInit;
  final calls = <String>[];
  bool disposed = false;

  @override
  int get playerId => VideoPlayerController.kUninitializedPlayerId;

  @override
  Future<void> initialize() async {
    calls.add('initialize');
    if (failInit) throw StateError('no video');
    value = value.copyWith(
      isInitialized: true,
      duration: length,
      size: const Size(1920, 1080),
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    calls.add('seekTo ${position.inMilliseconds}');
    value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
