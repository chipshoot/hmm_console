import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/attachments/inline_ref_uri.dart';
import '../data/models/hmm_note.dart';
import '../presentation/widgets/video_tile.dart';

/// What "Share…" hands to the system share sheet: the subject, then the
/// body after a blank line. A note without a body shares its subject alone.
/// A video's poster image in the body becomes `▶ Video, 0:48` (the file is
/// shared only through the video's own Share… item); other images stay.
String shareTextFor(HmmNote note, {String videoLabel = 'Video'}) {
  var body = note.content;
  if (body == null || body.isEmpty) return note.subject;
  final videos = {
    for (final v in note.effectiveAttachments.videos) v.inlinePath: v,
  };
  if (videos.isNotEmpty) {
    body = body.replaceAllMapped(_imageMd, (m) {
      final path = parseImageUri(m.group(1)!);
      final v = path == null ? null : videos[path];
      if (v == null) return m.group(0)!;
      final ms = v.durationMs;
      return ms == null
          ? '▶ $videoLabel'
          : '▶ $videoLabel, ${VideoTile.formatLength(ms)}';
    });
  }
  return '${note.subject}\n\n$body';
}

// A whole markdown image, capturing its url like inline_ref_uri.dart does.
final RegExp _imageMd = RegExp(r'!\[[^\]]*\]\(([^)\s]+)[^)]*\)');

/// Seam over the system share sheet, so tests need no platform channel.
abstract interface class NoteSharer {
  /// [origin] anchors the iPad share popover; it must be non-empty there.
  Future<void> shareText(String text, {Rect? origin});
}

/// The only place `share_plus` is used.
class SharePlusNoteSharer implements NoteSharer {
  const SharePlusNoteSharer();

  @override
  Future<void> shareText(String text, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }
}

final noteSharerProvider = Provider<NoteSharer>(
  (ref) => const SharePlusNoteSharer(),
);
