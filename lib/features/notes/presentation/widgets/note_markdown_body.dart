import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/attachments/widgets/fullscreen_image.dart';
import '../../../../core/data/repository_providers.dart';
import '../../../../core/data/vault/sensitive_path.dart';
import '../../../../core/data/attachments/widgets/sensitive_attachment_image.dart';
import '../../../../core/data/attachments/video/video_picker.dart';
import '../../../../core/data/attachments/video_attachment.dart';
import '../../links/video_link.dart';
import 'video_tile.dart';
import 'video_link_card.dart';

/// Max on-screen height of an inline image; the whole image scales to the
/// column width and is capped here so a tall image doesn't dominate.
const double kInlineImageMaxHeight = 360.0;

/// Routes a tapped Markdown link URL by scheme: a `hmm-note://<uuid>` link to
/// [onNote]; an `http(s)` link to [onExternal]; anything else is ignored.
void dispatchMarkdownLink(
  String? href, {
  required void Function(String uuid) onNote,
  required void Function(Uri url) onExternal,
}) {
  if (href == null) return;
  final uuid = parseNoteUri(href);
  if (uuid != null) {
    onNote(uuid);
    return;
  }
  final uri = Uri.tryParse(href);
  if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
    onExternal(uri);
  }
}

/// Renders a Markdown [data] string, resolving `hmm-attachment://` image URIs
/// to inline images (whole image, fit-to-width, tap → fullscreen). Unsaved
/// picks resolve from [pendingBytes] (uuid → bytes).
class NoteMarkdownBody extends StatelessWidget {
  const NoteMarkdownBody({
    super.key,
    required this.data,
    this.resolver,
    this.pendingBytes,
    this.selectable = true,
    this.onNoteLinkTap,
    this.onExternalLinkTap,
    this.linkCards = const {},
    this.videos = const {},
    this.pendingVideos = const {},
    this.onVideoLongPress,
  });

  final String data;
  final IAttachmentResolver? resolver;
  final Map<String, Uint8List>? pendingBytes;
  final bool selectable;

  /// Tapped a `hmm-note://<uuid>` link. Null = note links are inert here.
  final void Function(String noteUuid)? onNoteLinkTap;

  /// Tapped an external `http(s)` link. Defaults to opening via url_launcher.
  final void Function(Uri url)? onExternalLinkTap;

  /// Link previews by URL. A body line holding only one of these URLs renders
  /// as a [VideoLinkCard]. Empty = the body renders as plain Markdown.
  final Map<String, LinkCardData> linkCards;

  /// Saved videos by [VideoAttachment.inlinePath]: an image line whose path
  /// is a key renders as a [VideoTile].
  final Map<String, VideoAttachment> videos;

  /// Unsaved video picks by pending uuid.
  final Map<String, PickedVideo> pendingVideos;

  final void Function(VideoAttachment)? onVideoLongPress;

  // The Markdown is re-parsed only when this key changes, so it covers
  // everything the image builder reads besides the text.
  Key _keyFor(int? segment) => ValueKey((
    resolver,
    segment,
    videos.keys.join('|'),
    pendingVideos.keys.join('|'),
  ));

  Widget _box(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: kInlineImageMaxHeight),
    child: child,
  );

  Widget _placeholder() => _box(
    const ColoredBox(
      color: Color(0xFFF2F2F7),
      child: Center(child: Icon(Icons.broken_image_outlined)),
    ),
  );

  Widget _buildImage(BuildContext context, MarkdownImageConfig config) {
    final url = config.uri.toString();

    final pendingUuid = pendingUuidOf(url);
    if (pendingUuid != null && pendingVideos.containsKey(pendingUuid)) {
      return VideoTile(
        pending: pendingVideos[pendingUuid],
        resolver: resolver,
      );
    }
    if (pendingUuid != null) {
      final bytes = pendingBytes?[pendingUuid];
      if (bytes == null) return _placeholder();
      return _box(
        Image.memory(
          bytes,
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
        ),
      );
    }

    final path = parseImageUri(url);
    final video = path == null ? null : videos[path];
    if (video != null) {
      return VideoTile(
        saved: video,
        resolver: resolver,
        onLongPress: onVideoLongPress,
      );
    }
    if (path != null && resolver != null) {
      // Render-only ref: VaultResolver resolves by path; the other fields are
      // unused for display.
      final sensitive = isSensitiveVaultPath(path);
      final ref = VaultRef(
        path: path,
        contentType: 'application/octet-stream',
        byteSize: 0,
        sensitive: sensitive,
      );
      return _box(
        GestureDetector(
          onTap: () => showFullscreenImage(context, ref),
          child: sensitive
              ? SensitiveAttachmentImage(
                  ref: ref,
                  resolver: resolver!,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  semanticLabel: config.alt,
                )
              : AttachmentImage(
                  ref: ref,
                  resolver: resolver!,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  semanticLabel: config.alt,
                ),
        ),
      );
    }

    // A normal external image (e.g. http/https) — render it like the default
    // Markdown image handler would, since sizedImageBuilder intercepts all.
    if (config.uri.hasScheme &&
        (config.uri.isScheme('http') || config.uri.isScheme('https'))) {
      return _box(
        Image.network(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }

    return _placeholder();
  }

  void _launchExternal(Uri url) {
    // Best-effort external open. Genuinely swallow failures (no handler app, or
    // a platform exception) via catchError so a bad link never surfaces as an
    // unhandled async error or crashes the note view.
    unawaited(
      launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false),
    );
  }

  Widget _markdown(BuildContext context, String text, {Key? key}) {
    return MarkdownBody(
      // flutter_markdown re-parses (and so re-runs the image builder) only
      // when the text changes. The resolver usually arrives a frame after
      // the first build; keying on it rebuilds the images then, instead of
      // leaving the "no resolver yet" placeholder for good.
      key: key,
      data: text,
      selectable: selectable,
      sizedImageBuilder: (config) => _buildImage(context, config),
      onTapLink: (text, href, title) => dispatchMarkdownLink(
        href,
        onNote: (uuid) => onNoteLinkTap?.call(uuid),
        onExternal: (url) => (onExternalLinkTap ?? _launchExternal)(url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (linkCards.isEmpty) {
      return _markdown(
        context,
        data,
        key: _keyFor(null),
      );
    }
    final segments = splitCardSegments(data, linkCards.keys.toSet());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, seg) in segments.indexed)
          switch (seg) {
            MarkdownSegment(:final text) => _markdown(
              context,
              text,
              key: _keyFor(i),
            ),
            CardSegment(:final url) => VideoLinkCard(
              key: ValueKey('card-$i-$url'),
              data: linkCards[url]!,
              resolver: resolver,
            ),
          },
      ],
    );
  }
}

/// Backwards-compatible read-only Markdown view. Existing call sites use
/// `MarkdownView(markdown)`; it now resolves inline images too.
class MarkdownView extends ConsumerWidget {
  const MarkdownView(
    this.data, {
    super.key,
    this.linkCards = const {},
    this.videos = const {},
    this.pendingVideos = const {},
    this.onVideoLongPress,
  });

  final String data;
  final Map<String, LinkCardData> linkCards;
  final Map<String, VideoAttachment> videos;
  final Map<String, PickedVideo> pendingVideos;
  final void Function(VideoAttachment)? onVideoLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(attachmentResolverProvider).value;
    return NoteMarkdownBody(
      data: data,
      resolver: resolver,
      linkCards: linkCards,
      videos: videos,
      pendingVideos: pendingVideos,
      onVideoLongPress: onVideoLongPress,
      onNoteLinkTap: (uuid) => unawaited(_openNote(context, ref, uuid)),
    );
  }

  Future<void> _openNote(
    BuildContext context,
    WidgetRef ref,
    String uuid,
  ) async {
    try {
      final note = await ref
          .read(hmmNoteRepositoryProvider)
          .getNoteByUuid(uuid);
      if (!context.mounted) return;
      if (note != null) {
        context.push('/notes/${note.id}');
        return;
      }
    } catch (_) {
      // Resolution failed (e.g. no signed-in author, or a DB error) — fall
      // through to the same non-crashing "unavailable" affordance.
    }
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.notesLinkedUnavailable)));
  }
}
