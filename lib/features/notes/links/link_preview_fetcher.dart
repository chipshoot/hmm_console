// Fetches a link's preview (title, length, thumbnail) straight from the device.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/attachments/link_preview.dart';
import 'video_link.dart';

class FetchedLinkPreview {
  const FetchedLinkPreview({
    required this.url,
    required this.provider,
    required this.title,
    this.durationSeconds,
    this.thumbnailBytes,
    this.thumbnailContentType,
  });

  final String url;
  final LinkProvider provider;
  final String title;
  final int? durationSeconds;
  final Uint8List? thumbnailBytes;
  final String? thumbnailContentType;
}

const _maxPageChars = 512 * 1024;
const _maxThumbBytes = 2 * 1024 * 1024;
const _thumbTypes = {'image/jpeg', 'image/png', 'image/webp'};

class LinkPreviewFetcher {
  LinkPreviewFetcher(this._dio);

  final Dio _dio;

  /// Never throws; null on any failure.
  Future<FetchedLinkPreview?> fetch(String url) async {
    try {
      final target = parseVideoLink(url);
      switch (target) {
        case YouTubeTarget():
          return await _youtube(url);
        case BilibiliTarget():
          return await _bilibili(url, target);
        case ShortLinkTarget(:final uri):
          final res = await _dio.getUri<Object>(
            uri,
            options: Options(
              followRedirects: true,
              responseType: ResponseType.plain,
            ),
          );
          final resolved = parseVideoLink(res.realUri.toString());
          if (resolved is! BilibiliTarget) return null;
          return await _bilibili(url, resolved);
        case null:
          final uri = Uri.tryParse(url.trim());
          if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
            return null;
          }
          return await _web(url, uri);
      }
    } catch (_) {
      return null;
    }
  }

  Future<FetchedLinkPreview?> _youtube(String url) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://www.youtube.com/oembed'
      '?url=${Uri.encodeComponent(url)}&format=json',
    );
    final data = res.data;
    final title = data?['title'];
    if (title is! String || title.isEmpty) return null;
    final thumb = await _thumbnail(data?['thumbnail_url']);
    return FetchedLinkPreview(
      url: url,
      provider: LinkProvider.youtube,
      title: title,
      thumbnailBytes: thumb?.$1,
      thumbnailContentType: thumb?.$2,
    );
  }

  Future<FetchedLinkPreview?> _bilibili(String url, BilibiliTarget t) async {
    final query = t.bvid != null ? 'bvid=${t.bvid}' : 'aid=${t.aid}';
    final res = await _dio.get<Map<String, dynamic>>(
      'https://api.bilibili.com/x/web-interface/view?$query',
    );
    final body = res.data;
    if (body == null || body['code'] != 0) return null;
    final data = body['data'];
    if (data is! Map) return null;
    final title = data['title'];
    if (title is! String || title.isEmpty) return null;
    final duration = data['duration'];
    final pic = data['pic'];
    final thumb = await _thumbnail(
      pic is String && pic.startsWith('http://')
          ? 'https://${pic.substring(7)}'
          : pic,
    );
    return FetchedLinkPreview(
      url: url,
      provider: LinkProvider.bilibili,
      title: title,
      durationSeconds: duration is num ? duration.toInt() : null,
      thumbnailBytes: thumb?.$1,
      thumbnailContentType: thumb?.$2,
    );
  }

  Future<FetchedLinkPreview?> _web(String url, Uri uri) async {
    final res = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );
    var html = res.data ?? '';
    if (html.length > _maxPageChars) html = html.substring(0, _maxPageChars);
    final title = _og(html, 'title');
    if (title == null || title.isEmpty) return null;
    var image = _og(html, 'image');
    if (image != null) {
      image = uri.resolve(image).toString();
    }
    final thumb = await _thumbnail(image);
    return FetchedLinkPreview(
      url: url,
      provider: LinkProvider.web,
      title: title,
      thumbnailBytes: thumb?.$1,
      thumbnailContentType: thumb?.$2,
    );
  }

  /// A thumbnail is best effort: any problem just means no thumbnail.
  Future<(Uint8List, String)?> _thumbnail(Object? url) async {
    if (url is! String || url.isEmpty) return null;
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      final type = res.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (data == null || type == null || !_thumbTypes.contains(type)) {
        return null;
      }
      if (data.length > _maxThumbBytes) return null;
      return (Uint8List.fromList(data), type);
    } catch (_) {
      return null;
    }
  }
}

String? _og(String html, String prop) {
  final p = RegExp.escape(prop);
  final metas = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
  final propRe = RegExp(
    'property\\s*=\\s*["\']og:$p["\']',
    caseSensitive: false,
  );
  final contentRe = RegExp(
    r'content\s*=\s*(?:"([^"]*)"|'
    "'([^']*)')",
    caseSensitive: false,
  );
  for (final m in metas.allMatches(html)) {
    final tag = m.group(0)!;
    if (!propRe.hasMatch(tag)) continue;
    final c = contentRe.firstMatch(tag);
    if (c == null) continue;
    return _unescape((c.group(1) ?? c.group(2) ?? '').trim());
  }
  return null;
}

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

final linkPreviewFetcherProvider = Provider<LinkPreviewFetcher>(
  (ref) => LinkPreviewFetcher(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
        },
      ),
    ),
  ),
);
