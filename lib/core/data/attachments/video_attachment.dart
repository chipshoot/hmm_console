// A video attached to a note: the video file, an optional poster frame and
// a little metadata, all in the vault. Stored in the `videos` list of the
// `Notes.attachments` column.

import 'package:collection/collection.dart';

import 'attachment_ref.dart';
import 'attachment_ref_codec.dart';

/// Video content types this build can attach, mapped to a file extension.
const Map<String, String> kVideoExtByContentType = {
  'video/quicktime': 'mov',
  'video/mp4': 'mp4',
  'video/x-m4v': 'm4v',
};

const Set<String> _videoExts = {'mov', 'mp4', 'm4v'};

/// True when the last extension of [path] is a video one (case-insensitive).
bool isVideoVaultPath(String path) {
  final name = path.substring(path.lastIndexOf('/') + 1);
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return _videoExts.contains(name.substring(dot + 1).toLowerCase());
}

int? _optionalNonNegativeInt(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is! num || v < 0) {
    throw FormatException('"$key" must be a non-negative number when present');
  }
  return v.toInt();
}

final class VideoAttachment {
  const VideoAttachment({
    required this.video,
    this.poster,
    this.durationMs,
    this.width,
    this.height,
    this.extra = const {},
  });

  final VaultRef video;
  final VaultRef? poster;
  final int? durationMs;
  final int? width;
  final int? height;

  /// Unknown keys of the entry, written back by [toJson].
  final Map<String, dynamic> extra;

  /// Path the note body refers to: the poster when there is one.
  String get inlinePath => poster?.path ?? video.path;

  static const _knownKeys = {
    'video',
    'poster',
    'durationMs',
    'width',
    'height',
  };

  /// Throws [FormatException] on bad input.
  static VideoAttachment fromJson(Map<String, dynamic> json) {
    final rawVideo = json['video'];
    if (rawVideo is! Map<String, dynamic>) {
      throw const FormatException('video: expected an object');
    }
    final video = AttachmentRefCodec.videoRefFromJson(rawVideo);

    VaultRef? poster;
    final rawPoster = json['poster'];
    if (rawPoster != null) {
      if (rawPoster is! Map<String, dynamic>) {
        throw const FormatException('poster: expected an object');
      }
      final ref = AttachmentRefCodec.fromJson(rawPoster);
      if (ref is! VaultRef) {
        throw const FormatException('poster: must be a vault ref');
      }
      poster = ref;
    }

    return VideoAttachment(
      video: video,
      poster: poster,
      durationMs: _optionalNonNegativeInt(json, 'durationMs'),
      width: _optionalNonNegativeInt(json, 'width'),
      height: _optionalNonNegativeInt(json, 'height'),
      extra: {
        for (final e in json.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    ...extra,
    'video': AttachmentRefCodec.toJson(video),
    if (poster != null) 'poster': AttachmentRefCodec.toJson(poster!),
    if (durationMs != null) 'durationMs': durationMs,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };

  static const _deep = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoAttachment &&
          other.video == video &&
          other.poster == poster &&
          other.durationMs == durationMs &&
          other.width == width &&
          other.height == height &&
          _deep.equals(other.extra, extra);

  @override
  int get hashCode =>
      Object.hash(video, poster, durationMs, width, height, _deep.hash(extra));

  @override
  String toString() =>
      'VideoAttachment(video: $video, poster: $poster, '
      'durationMs: $durationMs, width: $width, height: $height)';
}
