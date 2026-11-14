import 'dart:io';

import 'package:hmm_console/core/data/attachments/video/video_platform.dart';

class FakeVideoPlatform implements VideoPlatform {
  FakeVideoPlatform({this.writePoster = true, this.saveResult = true});
  final bool writePoster;
  bool saveResult;
  final played = <String>[];
  final saved = <String>[];

  @override
  Future<VideoProbe> probe(
    String videoPath, {
    required String posterPath,
  }) async {
    if (writePoster) await File(posterPath).writeAsBytes([1, 2, 3]);
    return VideoProbe(
      durationMs: 48000,
      width: 1920,
      height: 1080,
      posterWritten: writePoster,
    );
  }

  @override
  Future<void> play(String videoPath) async => played.add(videoPath);

  @override
  Future<bool> saveToPhotos(String videoPath) async {
    saved.add(videoPath);
    return saveResult;
  }
}
