// A rich preview of a link (video card) stored beside a note's attachments.

import 'attachment_ref.dart';
import 'attachment_ref_codec.dart';

/// Where a linked page lives. An unknown wire value decodes as [web].
enum LinkProvider {
  youtube('youtube'),
  bilibili('bilibili'),
  web('web');

  const LinkProvider(this.wireName);

  final String wireName;

  static LinkProvider fromWire(String s) => switch (s) {
    'youtube' => LinkProvider.youtube,
    'bilibili' => LinkProvider.bilibili,
    _ => LinkProvider.web,
  };
}

final class LinkPreview {
  const LinkPreview({
    required this.url,
    required this.provider,
    required this.title,
    this.durationSeconds,
    this.thumbnail,
  });

  final String url;
  final LinkProvider provider;
  final String title;
  final int? durationSeconds;
  final VaultRef? thumbnail;

  Map<String, dynamic> toJson() => {
    'url': url,
    'provider': provider.wireName,
    'title': title,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (thumbnail != null) 'thumbnail': AttachmentRefCodec.toJson(thumbnail!),
  };

  static LinkPreview fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final title = json['title'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('LinkPreview: missing "url"');
    }
    if (title is! String) {
      throw const FormatException('LinkPreview: missing "title"');
    }
    final provider = json['provider'];
    final duration = json['durationSeconds'];
    final thumb = json['thumbnail'];
    VaultRef? thumbnail;
    if (thumb != null) {
      if (thumb is! Map<String, dynamic>) {
        throw const FormatException('LinkPreview: bad "thumbnail"');
      }
      final ref = AttachmentRefCodec.fromJson(thumb);
      if (ref is! VaultRef) {
        throw const FormatException('LinkPreview: thumbnail must be a vault');
      }
      thumbnail = ref;
    }
    return LinkPreview(
      url: url,
      provider: LinkProvider.fromWire(provider is String ? provider : ''),
      title: title,
      durationSeconds: duration is int ? duration : null,
      thumbnail: thumbnail,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkPreview &&
          other.url == url &&
          other.provider == provider &&
          other.title == title &&
          other.durationSeconds == durationSeconds &&
          other.thumbnail == thumbnail;

  @override
  int get hashCode =>
      Object.hash(url, provider, title, durationSeconds, thumbnail);

  @override
  String toString() => 'LinkPreview($url, ${provider.wireName}, "$title")';
}
