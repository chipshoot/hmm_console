// Pure-Dart recognition of video links and card lines in a note body.

sealed class VideoLinkTarget {
  const VideoLinkTarget();
}

final class YouTubeTarget extends VideoLinkTarget {
  const YouTubeTarget(this.videoId);
  final String videoId;
}

final class BilibiliTarget extends VideoLinkTarget {
  const BilibiliTarget({this.bvid, this.aid});
  final String? bvid;
  final int? aid;
}

/// b23.tv short link; needs a redirect to resolve.
final class ShortLinkTarget extends VideoLinkTarget {
  const ShortLinkTarget(this.uri);
  final Uri uri;
}

final _ytId = RegExp(r'^[A-Za-z0-9_-]{11}$');
final _bv = RegExp(r'^BV[0-9A-Za-z]{10}$');
final _av = RegExp(r'^av(\d+)$');

VideoLinkTarget? parseVideoLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  if (host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com') {
    if (segs.length == 1 && segs[0] == 'watch') {
      final v = uri.queryParameters['v'];
      if (v != null && _ytId.hasMatch(v)) return YouTubeTarget(v);
    } else if (segs.length == 2 && segs[0] == 'shorts') {
      if (_ytId.hasMatch(segs[1])) return YouTubeTarget(segs[1]);
    }
    return null;
  }
  if (host == 'youtu.be') {
    if (segs.isNotEmpty && _ytId.hasMatch(segs[0])) {
      return YouTubeTarget(segs[0]);
    }
    return null;
  }
  if (host == 'bilibili.com' ||
      host == 'www.bilibili.com' ||
      host == 'm.bilibili.com') {
    if (segs.length >= 2 && segs[0] == 'video') {
      final id = segs[1];
      if (_bv.hasMatch(id)) return BilibiliTarget(bvid: id);
      final m = _av.firstMatch(id);
      if (m != null) return BilibiliTarget(aid: int.parse(m.group(1)!));
    }
    return null;
  }
  if (host == 'b23.tv') {
    if (segs.isNotEmpty) return ShortLinkTarget(uri);
    return null;
  }
  return null;
}

/// The trimmed line when it is exactly one http(s) URL, else null.
String? standaloneUrl(String line) {
  final t = line.trim();
  if (!RegExp(r'^https?://\S+$').hasMatch(t)) return null;
  return t;
}

sealed class BodySegment {
  const BodySegment();
}

final class MarkdownSegment extends BodySegment {
  const MarkdownSegment(this.text);
  final String text;
}

final class CardSegment extends BodySegment {
  const CardSegment(this.url);
  final String url;
}

/// Like [standaloneUrl], but the URL must start in column 0 (a trailing space
/// is fine). An indented line may belong to a list item, quote or code block,
/// so it stays Markdown. The note view and the editor both use this.
String? _cardLineUrl(String line) {
  if (line.isNotEmpty && line.trimLeft().length != line.length) return null;
  return standaloneUrl(line);
}

bool _isFence(String line) {
  final t = line.trimLeft();
  return t.startsWith('```') || t.startsWith('~~~');
}

List<BodySegment> splitCardSegments(String markdown, Set<String> cardUrls) {
  final out = <BodySegment>[];
  final buf = <String>[];
  void flush() {
    if (buf.isEmpty) return;
    final text = buf.join('\n');
    buf.clear();
    if (text.isNotEmpty) out.add(MarkdownSegment(text));
  }

  var inFence = false;
  for (final line in markdown.split('\n')) {
    if (_isFence(line)) {
      inFence = !inFence;
      buf.add(line);
      continue;
    }
    final url = inFence ? null : _cardLineUrl(line);
    if (url != null && cardUrls.contains(url)) {
      flush();
      out.add(CardSegment(url));
    } else {
      buf.add(line);
    }
  }
  flush();
  return out;
}

Set<String> standaloneUrlsIn(String markdown) {
  final out = <String>{};
  var inFence = false;
  for (final line in markdown.split('\n')) {
    if (_isFence(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    final u = _cardLineUrl(line);
    if (u != null) out.add(u);
  }
  return out;
}
