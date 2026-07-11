// Display widget for an AttachmentRef.
//
// Loads bytes via the configured resolver. Shows a progress
// indicator while loading, the image on success, and a placeholder
// (with an optional Replace tap target supplied by the caller) on
// failure — mirroring the "render-time fallback" section of
// docs/attachments-design.md.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../attachment_ref.dart';
import '../resolver/attachment_resolver.dart';

class AttachmentImage extends StatefulWidget {
  const AttachmentImage({
    required this.ref,
    required this.resolver,
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.loadingPlaceholder,
    this.errorPlaceholder,
    this.semanticLabel,
  });

  /// What to render. Pass null for "no photo set" — the widget
  /// shows [errorPlaceholder] (or a default icon).
  final AttachmentRef? ref;

  final IAttachmentResolver resolver;
  final BoxFit fit;

  /// How the image is aligned within its box when [fit] crops it (e.g.
  /// [BoxFit.cover]). Thumbnails pass [Alignment.topCenter] so a tall
  /// receipt/photo shows its top (logo, date, subject) rather than the
  /// cropped middle.
  final Alignment alignment;
  final Widget? loadingPlaceholder;
  final Widget? errorPlaceholder;
  final String? semanticLabel;

  @override
  State<AttachmentImage> createState() => _AttachmentImageState();
}

class _AttachmentImageState extends State<AttachmentImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref != widget.ref || oldWidget.resolver != widget.resolver) {
      _future = _load();
    }
  }

  Future<Uint8List?> _load() async {
    final ref = widget.ref;
    if (ref == null) return null;
    return widget.resolver.resolve(ref);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ref == null) {
      return widget.errorPlaceholder ?? const _DefaultMissing();
    }
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return widget.loadingPlaceholder ??
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              );
        }
        final bytes = snap.data;
        if (bytes == null) {
          return widget.errorPlaceholder ?? const _DefaultMissing();
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          alignment: widget.alignment,
          semanticLabel: widget.semanticLabel,
          // gaplessPlayback avoids the brief blank flash when the
          // ref changes (e.g. user picks a new photo).
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _DefaultMissing extends StatelessWidget {
  const _DefaultMissing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 36,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
