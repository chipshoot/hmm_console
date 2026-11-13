import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/link_preview.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// What a [VideoLinkCard] shows. [thumbnailBytes] (the editor's unsaved
/// preview) wins over [thumbnail] (a saved vault ref).
class LinkCardData {
  const LinkCardData({
    required this.url,
    required this.provider,
    required this.title,
    this.durationSeconds,
    this.thumbnail,
    this.thumbnailBytes,
  });

  factory LinkCardData.fromPreview(LinkPreview p) => LinkCardData(
    url: p.url,
    provider: p.provider,
    title: p.title,
    durationSeconds: p.durationSeconds,
    thumbnail: p.thumbnail,
  );

  final String url;
  final LinkProvider provider;
  final String title;
  final int? durationSeconds;
  final VaultRef? thumbnail;
  final Uint8List? thumbnailBytes;
}

/// A tappable card for a video link; tapping opens it in its own app.
class VideoLinkCard extends StatefulWidget {
  const VideoLinkCard({
    super.key,
    required this.data,
    this.resolver,
    this.launch,
  });

  final LinkCardData data;
  final IAttachmentResolver? resolver;
  final Future<bool> Function(Uri)? launch;

  @override
  State<VideoLinkCard> createState() => _VideoLinkCardState();
}

class _VideoLinkCardState extends State<VideoLinkCard> {
  bool _unavailable = false;
  Future<Uint8List?>? _thumb;

  @override
  void initState() {
    super.initState();
    _thumb = _loadThumb();
  }

  @override
  void didUpdateWidget(covariant VideoLinkCard old) {
    super.didUpdateWidget(old);
    if (old.data.thumbnail != widget.data.thumbnail ||
        old.data.thumbnailBytes != widget.data.thumbnailBytes ||
        old.resolver != widget.resolver) {
      _thumb = _loadThumb();
    }
  }

  Future<Uint8List?>? _loadThumb() {
    final d = widget.data;
    if (d.thumbnailBytes != null) return null;
    final ref = d.thumbnail;
    final resolver = widget.resolver;
    if (ref == null || resolver == null) return null;
    return resolver
        .resolve(ref)
        .then<Uint8List?>((b) => b)
        .catchError((Object _) => null);
  }

  Future<void> _open() async {
    final launch =
        widget.launch ??
        (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
    var ok = false;
    try {
      ok = await launch(Uri.parse(widget.data.url));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _unavailable = !ok);
  }

  String _siteLabel() => switch (widget.data.provider) {
    LinkProvider.youtube => 'YouTube',
    LinkProvider.bilibili => 'Bilibili',
    LinkProvider.web => Uri.tryParse(widget.data.url)?.host ?? '',
  };

  static String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  Widget _thumbnail(Uint8List bytes) {
    final secs = widget.data.durationSeconds;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xB3FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF222222),
                  size: 30,
                ),
              ),
            ),
            if (secs != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    formatDuration(secs),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget text(bool withGlyph) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (withGlyph)
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 1),
            child: Icon(Icons.play_arrow_rounded, size: 22),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _siteLabel(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_unavailable)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    l.notesVideoLinkUnavailable,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    Widget body(Uint8List? bytes) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bytes != null) ...[_thumbnail(bytes), const SizedBox(height: 8)],
        text(bytes == null),
      ],
    );

    final Widget content;
    if (d.thumbnailBytes != null) {
      content = body(d.thumbnailBytes);
    } else if (_thumb != null) {
      content = FutureBuilder<Uint8List?>(
        future: _thumb,
        builder: (context, snap) => body(snap.data),
      );
    } else {
      content = body(null);
    }

    return Semantics(
      button: true,
      label: [
        d.title,
        _siteLabel(),
        if (_unavailable) l.notesVideoLinkUnavailable,
      ].where((e) => e.isNotEmpty).join(', '),
      excludeSemantics: true,
      onTap: _open,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: content,
        ),
      ),
    );
  }
}
