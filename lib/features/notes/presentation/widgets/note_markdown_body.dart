import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/inline_ref_uri.dart';
import '../../../../core/data/attachments/resolver/attachment_resolver.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/attachments/widgets/fullscreen_image.dart';

/// Max on-screen height of an inline image; the whole image scales to the
/// column width and is capped here so a tall image doesn't dominate.
const double kInlineImageMaxHeight = 360.0;

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
  });

  final String data;
  final IAttachmentResolver? resolver;
  final Map<String, Uint8List>? pendingBytes;
  final bool selectable;

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
    if (pendingUuid != null) {
      final bytes = pendingBytes?[pendingUuid];
      if (bytes == null) return _placeholder();
      return _box(Image.memory(bytes,
          fit: BoxFit.contain, alignment: Alignment.topCenter));
    }

    final path = parseImageUri(url);
    if (path != null && resolver != null) {
      // Render-only ref: VaultResolver resolves by path; the other fields are
      // unused for display.
      final ref = VaultRef(
          path: path, contentType: 'application/octet-stream', byteSize: 0);
      return _box(GestureDetector(
        onTap: () => showFullscreenImage(context, ref),
        child: AttachmentImage(
          ref: ref,
          resolver: resolver!,
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          semanticLabel: config.alt,
        ),
      ));
    }

    return _placeholder();
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      sizedImageBuilder: (config) => _buildImage(context, config),
    );
  }
}

/// Backwards-compatible read-only Markdown view. Existing call sites use
/// `MarkdownView(markdown)`; it now resolves inline images too.
class MarkdownView extends ConsumerWidget {
  const MarkdownView(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(attachmentResolverProvider).value;
    return NoteMarkdownBody(data: data, resolver: resolver);
  }
}
