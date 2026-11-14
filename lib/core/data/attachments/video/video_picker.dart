// Picks a video from the photo library by file path (never into memory),
// checks its size and type, and probes it for a poster and metadata.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../util/uuid.dart';
import '../video_attachment.dart';
import 'video_platform.dart';

const int kVideoWarnBytes = 500 * 1024 * 1024;
const int kVideoMaxBytes = 2 * 1024 * 1024 * 1024;

enum VideoSizeVerdict { ok, warn, refuse }

VideoSizeVerdict classifyVideoSize(int bytes) {
  if (bytes > kVideoMaxBytes) return VideoSizeVerdict.refuse;
  if (bytes > kVideoWarnBytes) return VideoSizeVerdict.warn;
  return VideoSizeVerdict.ok;
}

/// The content type for a video file name, or null when it is not one this
/// build can attach.
String? videoContentTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = fileName.substring(dot + 1).toLowerCase();
  for (final e in kVideoExtByContentType.entries) {
    if (e.value == ext) return e.key;
  }
  return null;
}

class PickedVideo {
  const PickedVideo({
    required this.tempPath,
    required this.originalName,
    required this.contentType,
    required this.byteSize,
    this.posterBytes,
    this.durationMs,
    this.width,
    this.height,
  });

  final String tempPath;
  final String originalName;
  final String contentType;
  final int byteSize;
  final Uint8List? posterBytes;
  final int? durationMs;
  final int? width;
  final int? height;

  VideoSizeVerdict get verdict => classifyVideoSize(byteSize);
}

enum VideoPickError { tooLarge, unsupported }

class VideoPickException implements Exception {
  const VideoPickException(this.error);
  final VideoPickError error;

  @override
  String toString() => 'VideoPickException($error)';
}

class VideoPicker {
  VideoPicker({
    required Future<XFile?> Function() pickFile,
    required VideoPlatform platform,
    required Future<Directory> Function() tempDir,
  }) : _pickFile = pickFile,
       _platform = platform,
       _tempDir = tempDir;

  final Future<XFile?> Function() _pickFile;
  final VideoPlatform _platform;
  final Future<Directory> Function() _tempDir;

  /// Null when the user cancelled. Throws [VideoPickException] for a video
  /// that is too large or of an unsupported type (its temp file is deleted).
  Future<PickedVideo?> pick() async {
    final picked = await _pickFile();
    if (picked == null) return null;
    final file = File(picked.path);
    final name = picked.name.isNotEmpty
        ? picked.name
        : picked.path.split('/').last;

    Never reject(VideoPickError e) {
      throw VideoPickException(e);
    }

    Future<void> discard() async {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    final contentType = videoContentTypeFor(name);
    if (contentType == null) {
      await discard();
      reject(VideoPickError.unsupported);
    }
    final size = await file.length();
    if (classifyVideoSize(size) == VideoSizeVerdict.refuse) {
      await discard();
      reject(VideoPickError.tooLarge);
    }

    final dir = await _tempDir();
    final posterFile = File('${dir.path}/poster-${generateUuid()}.jpg');
    Uint8List? posterBytes;
    VideoProbe probe;
    try {
      probe = await _platform.probe(file.path, posterPath: posterFile.path);
      if (probe.posterWritten && await posterFile.exists()) {
        posterBytes = await posterFile.readAsBytes();
      }
    } finally {
      try {
        if (await posterFile.exists()) await posterFile.delete();
      } catch (_) {}
    }
    return PickedVideo(
      tempPath: file.path,
      originalName: name,
      contentType: contentType,
      byteSize: size,
      posterBytes: posterBytes,
      durationMs: probe.durationMs,
      width: probe.width,
      height: probe.height,
    );
  }
}

final videoPickerProvider = Provider<VideoPicker>((ref) {
  return VideoPicker(
    pickFile: () => ImagePicker().pickVideo(source: ImageSource.gallery),
    platform: ref.watch(videoPlatformProvider),
    tempDir: getTemporaryDirectory,
  );
});
