import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/link_preview.dart';
import 'package:hmm_console/features/notes/links/link_preview_fetcher.dart';

typedef _Handler = ResponseBody Function(RequestOptions o);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);
  final Map<String, _Handler> routes;
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);
    final h = routes[url];
    if (h == null) return ResponseBody.fromString('nope', 404);
    return h(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

ResponseBody _html(String body) => ResponseBody.fromString(
  body,
  200,
  headers: {
    Headers.contentTypeHeader: ['text/html'],
  },
);

ResponseBody _img(int length, [String type = 'image/jpeg']) =>
    ResponseBody.fromBytes(
      Uint8List(length),
      200,
      headers: {
        Headers.contentTypeHeader: [type],
      },
    );

LinkPreviewFetcher _fetcher(_FakeAdapter a) =>
    LinkPreviewFetcher(Dio()..httpClientAdapter = a);

void main() {
  const yt = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  final ytOembed =
      'https://www.youtube.com/oembed?url=${Uri.encodeComponent(yt)}&format=json';

  test('youtube oembed', () async {
    final a = _FakeAdapter({
      ytOembed: (_) => _json({
        'title': 'Rick',
        'thumbnail_url': 'https://i.ytimg.com/vi/x/hq.jpg',
      }),
      'https://i.ytimg.com/vi/x/hq.jpg': (_) => _img(10),
    });
    final p = await _fetcher(a).fetch(yt);
    expect(p, isNotNull);
    expect(p!.url, yt);
    expect(p.provider, LinkProvider.youtube);
    expect(p.title, 'Rick');
    expect(p.durationSeconds, isNull);
    expect(p.thumbnailBytes, hasLength(10));
    expect(p.thumbnailContentType, 'image/jpeg');
  });

  test('bilibili view api', () async {
    final a = _FakeAdapter({
      'https://api.bilibili.com/x/web-interface/view?bvid=BV1xx411c7mD': (_) =>
          _json({
            'code': 0,
            'data': {
              'title': 'Bili',
              'pic': 'http://i0.hdslb.com/a.jpg',
              'duration': 125,
            },
          }),
      'https://i0.hdslb.com/a.jpg': (_) => _img(5),
    });
    final p = await _fetcher(
      a,
    ).fetch('https://www.bilibili.com/video/BV1xx411c7mD');
    expect(p!.provider, LinkProvider.bilibili);
    expect(p.title, 'Bili');
    expect(p.durationSeconds, 125);
    expect(p.thumbnailBytes, hasLength(5));
    expect(a.requested, contains('https://i0.hdslb.com/a.jpg'));
  });

  test('bilibili aid uses aid query', () async {
    final a = _FakeAdapter({
      'https://api.bilibili.com/x/web-interface/view?aid=170001': (_) => _json({
        'code': 0,
        'data': {'title': 'T', 'pic': '', 'duration': 3},
      }),
    });
    final p = await _fetcher(
      a,
    ).fetch('https://www.bilibili.com/video/av170001');
    expect(p!.durationSeconds, 3);
    expect(p.thumbnailBytes, isNull);
  });

  test('b23 short link follows redirect', () async {
    final a = _FakeAdapter({
      'https://b23.tv/abc123': (o) => ResponseBody(
        Stream.value(Uint8List(0)),
        200,
        isRedirect: true,
        redirects: [
          RedirectRecord(
            302,
            'GET',
            Uri.parse('https://www.bilibili.com/video/BV1xx411c7mD'),
          ),
        ],
      ),
      'https://api.bilibili.com/x/web-interface/view?bvid=BV1xx411c7mD': (_) =>
          _json({
            'code': 0,
            'data': {'title': 'Short', 'pic': '', 'duration': 7},
          }),
    });
    final p = await _fetcher(a).fetch('https://b23.tv/abc123');
    expect(p!.provider, LinkProvider.bilibili);
    expect(p.title, 'Short');
    expect(p.url, 'https://b23.tv/abc123');
  });

  test('web og tags', () async {
    final a = _FakeAdapter({
      'https://example.com/post': (_) => _html(
        '<html><head>'
        '<meta property="og:title" content="A &amp; B &quot;q&quot; &#39;s&#39; &lt;x&gt;">'
        '<meta content="https://example.com/i.png" property="og:image">'
        '</head></html>',
      ),
      'https://example.com/i.png': (_) => _img(4, 'image/png'),
    });
    final p = await _fetcher(a).fetch('https://example.com/post');
    expect(p!.provider, LinkProvider.web);
    expect(p.title, 'A & B "q" \'s\' <x>');
    expect(p.durationSeconds, isNull);
    expect(p.thumbnailContentType, 'image/png');
    expect(p.thumbnailBytes, hasLength(4));
  });

  group('returns null on failure', () {
    test('404', () async {
      expect(await _fetcher(_FakeAdapter({})).fetch(yt), isNull);
    });
    test('bilibili code -404', () async {
      final a = _FakeAdapter({
        'https://api.bilibili.com/x/web-interface/view?bvid=BV1xx411c7mD':
            (_) => _json({'code': -404, 'message': 'x'}),
      });
      expect(
        await _fetcher(a).fetch('https://www.bilibili.com/video/BV1xx411c7mD'),
        isNull,
      );
    });
    test('timeout', () async {
      final a = _FakeAdapter({
        ytOembed: (o) => throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 8),
          requestOptions: o,
        ),
      });
      expect(await _fetcher(a).fetch(yt), isNull);
    });
    test('no og:title', () async {
      final a = _FakeAdapter({
        'https://example.com/p': (_) => _html('<html>nothing</html>'),
      });
      expect(await _fetcher(a).fetch('https://example.com/p'), isNull);
    });
    test('non-http url', () async {
      expect(await _fetcher(_FakeAdapter({})).fetch('ftp://x/y'), isNull);
    });
  });

  test('oversized or non-image thumbnail dropped', () async {
    for (final img in [_img(2 * 1024 * 1024 + 1), _img(10, 'text/html')]) {
      final a = _FakeAdapter({
        ytOembed: (_) => _json({'title': 'T', 'thumbnail_url': 'https://t/i'}),
        'https://t/i': (_) => img,
      });
      final p = await _fetcher(a).fetch(yt);
      expect(p!.title, 'T');
      expect(p.thumbnailBytes, isNull);
      expect(p.thumbnailContentType, isNull);
    }
  });

  const bvUrl = 'https://www.bilibili.com/video/BV1xx411c7mD';
  const bvApi =
      'https://api.bilibili.com/x/web-interface/view?bvid=BV1xx411c7mD';
  ResponseBody bvPage() => _html(
    '<meta property="og:title" content="Page title">'
    '<meta property="og:image" content="https://i0.hdslb.com/p.jpg">',
  );

  group('bilibili fallback', () {
    test('bilibili api html page falls back to og tags', () async {
      final a = _FakeAdapter({
        bvApi: (_) => ResponseBody.fromString(
          '<html>verify</html>',
          412,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
        bvUrl: (_) => bvPage(),
        'https://i0.hdslb.com/p.jpg': (_) => _img(3),
      });
      final p = await _fetcher(a).fetch(bvUrl);
      expect(p!.provider, LinkProvider.bilibili);
      expect(p.title, 'Page title');
      expect(p.durationSeconds, isNull);
      expect(p.thumbnailBytes, hasLength(3));
    });

    test('bilibili api data null falls back', () async {
      final a = _FakeAdapter({
        bvApi: (_) => _json({'code': 0, 'data': null}),
        bvUrl: (_) => bvPage(),
      });
      final p = await _fetcher(a).fetch(bvUrl);
      expect(p!.provider, LinkProvider.bilibili);
      expect(p.title, 'Page title');
    });

    test('aid falls back to the av page', () async {
      final a = _FakeAdapter({
        'https://www.bilibili.com/video/av170001': (_) => bvPage(),
      });
      final p = await _fetcher(
        a,
      ).fetch('https://www.bilibili.com/video/av170001');
      expect(p!.title, 'Page title');
    });

    test('both failing returns null', () async {
      expect(await _fetcher(_FakeAdapter({})).fetch(bvUrl), isNull);
    });
  });

  test('malformed og:image keeps preview without thumbnail', () async {
    final a = _FakeAdapter({
      'https://example.com/p': (_) => _html(
        '<meta property="og:title" content="T">'
        '<meta property="og:image" content="http://[bad">',
      ),
    });
    final p = await _fetcher(a).fetch('https://example.com/p');
    expect(p!.title, 'T');
    expect(p.thumbnailBytes, isNull);
  });

  test('protocol-relative bilibili pic is fetched over https', () async {
    final a = _FakeAdapter({
      bvApi: (_) => _json({
        'code': 0,
        'data': {'title': 'B', 'pic': '//i0.hdslb.com/a.jpg', 'duration': 1},
      }),
      'https://i0.hdslb.com/a.jpg': (_) => _img(2),
    });
    final p = await _fetcher(a).fetch(bvUrl);
    expect(p!.thumbnailBytes, hasLength(2));
  });

  test('missing bilibili pic keeps preview without thumbnail', () async {
    final a = _FakeAdapter({
      bvApi: (_) => _json({
        'code': 0,
        'data': {'title': 'B', 'duration': 9},
      }),
    });
    final p = await _fetcher(a).fetch(bvUrl);
    expect(p!.durationSeconds, 9);
    expect(p.thumbnailBytes, isNull);
  });

  test('b23 redirect to non-bilibili url returns null', () async {
    final a = _FakeAdapter({
      'https://b23.tv/zzz': (o) => ResponseBody(
        Stream.value(Uint8List(0)),
        200,
        isRedirect: true,
        redirects: [RedirectRecord(302, 'GET', Uri.parse('https://x.com/a'))],
      ),
    });
    expect(await _fetcher(a).fetch('https://b23.tv/zzz'), isNull);
  });

  test('og tags with name attribute', () async {
    final a = _FakeAdapter({
      'https://example.com/n': (_) => _html(
        '<meta name="og:title" content="Named">'
        '<meta content="https://example.com/n.png" name="og:image">',
      ),
      'https://example.com/n.png': (_) => _img(1, 'image/png'),
    });
    final p = await _fetcher(a).fetch('https://example.com/n');
    expect(p!.title, 'Named');
    expect(p.thumbnailBytes, hasLength(1));
  });
}
