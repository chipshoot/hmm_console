import 'dart:async';
import 'dart:io';

import 'package:hmm_console/core/data/attachments/video/video_platform.dart';

class FakeVideoPlatform implements VideoPlatform {
  FakeVideoPlatform({
    this.writePoster = true,
    this.saveResult = true,
    this.probeThrows = false,
  });
  final bool writePoster;
  final bool probeThrows;
  bool saveResult;
  final played = <String>[];
  final playedAt = <int?>[];
  final saved = <String>[];
  final excluded = <String>[];
  final endedTasks = <int>[];
  int beganTasks = 0;
  int audioReleases = 0;
  final _closed = StreamController<int>.broadcast();

  /// Simulates the user closing the system player at [positionMs].
  void closeFullScreen(int positionMs) => _closed.add(positionMs);

  @override
  Stream<int> get fullScreenClosed => _closed.stream;

  @override
  Future<VideoProbe> probe(
    String videoPath, {
    required String posterPath,
  }) async {
    if (writePoster) await File(posterPath).writeAsBytes([1, 2, 3]);
    if (probeThrows) throw StateError('probe failed');
    return VideoProbe(
      durationMs: 48000,
      width: 1920,
      height: 1080,
      posterWritten: writePoster,
    );
  }

  @override
  Future<void> play(String videoPath, {int? positionMs}) async {
    played.add(videoPath);
    playedAt.add(positionMs);
  }

  @override
  Future<bool> saveToPhotos(String videoPath) async {
    saved.add(videoPath);
    return saveResult;
  }

  @override
  Future<void> excludeFromBackup(String path) async => excluded.add(path);

  @override
  Future<int?> beginBackgroundTask() async => ++beganTasks;

  @override
  Future<void> endBackgroundTask(int id) async => endedTasks.add(id);

  @override
  Future<void> releaseAudio() async => audioReleases++;
}
