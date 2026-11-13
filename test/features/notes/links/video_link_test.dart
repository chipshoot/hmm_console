import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/links/video_link.dart';

const yt = 'https://youtu.be/dQw4w9WgXcQ';

void yid(String url) {
  final t = parseVideoLink(url);
  expect(t, isA<YouTubeTarget>(), reason: url);
  expect((t! as YouTubeTarget).videoId, 'dQw4w9WgXcQ', reason: url);
}

void main() {
  group('parseVideoLink', () {
    test('youtube patterns', () {
      yid('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      yid('https://youtube.com/watch?v=dQw4w9WgXcQ&t=10s');
      yid('http://m.youtube.com/watch?v=dQw4w9WgXcQ');
      yid('https://youtu.be/dQw4w9WgXcQ');
      yid('https://youtu.be/dQw4w9WgXcQ?si=abc');
      yid('https://www.youtube.com/shorts/dQw4w9WgXcQ');
    });
    test('bilibili patterns', () {
      final a = parseVideoLink('https://www.bilibili.com/video/BV1xx411c7mD');
      expect(a, isA<BilibiliTarget>());
      expect((a! as BilibiliTarget).bvid, 'BV1xx411c7mD');
      final b = parseVideoLink('https://bilibili.com/video/av170001');
      expect((b! as BilibiliTarget).aid, 170001);
      final c = parseVideoLink('https://m.bilibili.com/video/BV1xx411c7mD?p=2');
      expect((c! as BilibiliTarget).bvid, 'BV1xx411c7mD');
    });
    test('short link', () {
      final t = parseVideoLink('https://b23.tv/abc123');
      expect(t, isA<ShortLinkTarget>());
      expect((t! as ShortLinkTarget).uri.host, 'b23.tv');
    });
    test('rejects others', () {
      expect(parseVideoLink('https://example.com/watch?v=dQw4w9WgXcQ'), isNull);
      expect(parseVideoLink('https://youtube.com/watch?v=short'), isNull);
      expect(parseVideoLink('ftp://youtu.be/dQw4w9WgXcQ'), isNull);
    });
  });

  group('standaloneUrl', () {
    test('trimmed single url', () {
      expect(standaloneUrl('  $yt '), yt);
    });
    test('rejects text around', () {
      expect(standaloneUrl('see https://youtu.be/x'), isNull);
      expect(standaloneUrl('hello'), isNull);
    });
  });

  group('splitCardSegments', () {
    test('splits around a card line', () {
      final s = splitCardSegments('a\n$yt\nb', {yt});
      expect(s, hasLength(3));
      expect((s[0] as MarkdownSegment).text, 'a');
      expect((s[1] as CardSegment).url, yt);
      expect((s[2] as MarkdownSegment).text, 'b');
    });
    test('ignores fenced code', () {
      final md = '```\n$yt\n```';
      final s = splitCardSegments(md, {yt});
      expect(s, hasLength(1));
      expect((s.single as MarkdownSegment).text, md);
    });
    test('url not in cardUrls stays markdown', () {
      final s = splitCardSegments('a\n$yt', <String>{});
      expect(s.single, isA<MarkdownSegment>());
    });
    test('standaloneUrlsIn skips fences', () {
      expect(standaloneUrlsIn('$yt\n~~~\nhttps://b23.tv/x\n~~~'), {yt});
    });
  });
}
