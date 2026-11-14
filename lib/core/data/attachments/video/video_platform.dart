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

  /// Plays the video full screen with the system player.
  Future<void> play(String videoPath);

  /// Saves the video to the photo library. False means permission was denied.
  Future<bool> saveToPhotos(String videoPath);
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
  Future<void> play(String videoPath) async {
    await _channel.invokeMethod<void>('play', {'path': videoPath});
  }

  @override
  Future<bool> saveToPhotos(String videoPath) async {
    return await _channel.invokeMethod<bool>('saveToPhotos', {
          'path': videoPath,
        }) ??
        false;
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
  Future<void> play(String videoPath) async {
    await OpenFilex.open(videoPath);
  }

  @override
  Future<bool> saveToPhotos(String videoPath) async => false;
}

final videoPlatformProvider = Provider<VideoPlatform>((ref) {
  return Platform.isIOS
      ? MethodChannelVideoPlatform()
      : FallbackVideoPlatform();
});
