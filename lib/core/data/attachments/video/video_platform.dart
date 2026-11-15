import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

/// What the platform could read from a video file. Every field is optional:
/// a video we cannot read is still a video we can attach.
class VideoProbe {
  const VideoProbe({
    this.durationMs,
    this.width,
    this.height,
    this.posterWritten = false,
  });

  final int? durationMs;
  final int? width;
  final int? height;
  final bool posterWritten;
}

/// Platform calls for attached videos. Works from file paths only, so a
/// multi-gigabyte video never passes through Dart memory.
abstract interface class VideoPlatform {
  /// Reads duration and size and writes a JPEG poster to [posterPath].
  Future<VideoProbe> probe(String videoPath, {required String posterPath});

  /// Plays the video full screen with the system player, from [positionMs]
  /// when given (else from the start).
  Future<void> play(String videoPath, {int? positionMs});

  /// Saves the video to the photo library. False means permission was denied.
  Future<bool> saveToPhotos(String videoPath);

  /// Marks [path] (a file or folder) as excluded from device backups.
  Future<void> excludeFromBackup(String path);

  /// Asks the OS for extra time to finish work after the app is backgrounded.
  /// Null when unsupported.
  Future<int?> beginBackgroundTask();

  /// Ends a task from [beginBackgroundTask].
  Future<void> endBackgroundTask(int id);

  /// Hands the audio session back after in-place playback ends, so other
  /// apps (Music) can resume.
  Future<void> releaseAudio();
}

/// Talks to `ios/Runner/VideoPlugin.swift`.
class MethodChannelVideoPlatform implements VideoPlatform {
  MethodChannelVideoPlatform();

  static const _channel = MethodChannel('hmm/video');

  @override
  Future<VideoProbe> probe(
    String videoPath, {
    required String posterPath,
  }) async {
    final map = await _channel.invokeMapMethod<String, dynamic>('probe', {
      'path': videoPath,
      'posterPath': posterPath,
    });
    if (map == null) return const VideoProbe();
    return VideoProbe(
      durationMs: map['durationMs'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      posterWritten: map['posterWritten'] as bool? ?? false,
    );
  }

  @override
  Future<void> play(String videoPath, {int? positionMs}) async {
    await _channel.invokeMethod<void>('play', {
      'path': videoPath,
      'positionMs': ?positionMs,
    });
  }

  @override
  Future<bool> saveToPhotos(String videoPath) async {
    return await _channel.invokeMethod<bool>('saveToPhotos', {
          'path': videoPath,
        }) ??
        false;
  }

  @override
  Future<void> excludeFromBackup(String path) async {
    await _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
  }

  @override
  Future<int?> beginBackgroundTask() async {
    return _channel.invokeMethod<int>('beginBackgroundTask');
  }

  @override
  Future<void> endBackgroundTask(int id) async {
    await _channel.invokeMethod<void>('endBackgroundTask', {'id': id});
  }

  @override
  Future<void> releaseAudio() async {
    await _channel.invokeMethod<void>('releaseAudio');
  }
}

/// Everywhere but iOS: no poster, no metadata, the OS opens the file.
class FallbackVideoPlatform implements VideoPlatform {
  FallbackVideoPlatform();

  @override
  Future<VideoProbe> probe(
    String videoPath, {
    required String posterPath,
  }) async => const VideoProbe();

  @override
  Future<void> play(String videoPath, {int? positionMs}) async {
    // The OS viewer cannot start part way in.
    await OpenFilex.open(videoPath);
  }

  @override
  Future<bool> saveToPhotos(String videoPath) async => false;

  @override
  Future<void> excludeFromBackup(String path) async {}

  @override
  Future<int?> beginBackgroundTask() async => null;

  @override
  Future<void> endBackgroundTask(int id) async {}

  @override
  Future<void> releaseAudio() async {}
}

final videoPlatformProvider = Provider<VideoPlatform>((ref) {
  return Platform.isIOS
      ? MethodChannelVideoPlatform()
      : FallbackVideoPlatform();
});
