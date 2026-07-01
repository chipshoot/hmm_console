import 'package:flutter/material.dart';

import '../attachment_ref.dart';
import '../picker/file_byte_source.dart';
import '../picker/image_byte_source.dart';
import '../resolver/attachment_resolver.dart';
import 'attachment_image.dart';

/// One row in an [AttachmentsSection]: a pending (in-memory) pick or a
/// saved [VaultRef]. Pending items aren't tappable-to-open (they have no
/// vault path yet); saved items are.
sealed class AttachmentItem {
  const AttachmentItem();
  bool get isImage;
  String get displayName;
}

class PendingImageItem extends AttachmentItem {
  const PendingImageItem(this.pick);
  final PickedImageBytes pick;
  @override
  bool get isImage => true;
  @override
  String get displayName => pick.originalName;
}

class PendingFileItem extends AttachmentItem {
  const PendingFileItem(this.pick);
  final PickedFileBytes pick;
  @override
  bool get isImage => false;
  @override
  String get displayName => pick.originalName;
}

class SavedAttachmentItem extends AttachmentItem {
  const SavedAttachmentItem(this.ref);
  final VaultRef ref;
  @override
  bool get isImage => ref.contentType.startsWith('image/');
  @override
  String get displayName => ref.originalName ?? 'attachment';
}

/// Flat, typed attachment list. Images render as 80×80 thumbnails; PDFs as
/// document cards. [editable] toggles the add controls and per-item remove.
class AttachmentsSection extends StatelessWidget {
  const AttachmentsSection({
    super.key,
    required this.items,
    required this.resolver,
    required this.editable,
    this.onAddImage,
    this.onAddPdf,
    this.onTap,
    this.onRemove,
  });

  final List<AttachmentItem> items;
  final IAttachmentResolver resolver;
  final bool editable;
  final VoidCallback? onAddImage;
  final VoidCallback? onAddPdf;
  final void Function(AttachmentItem item)? onTap;
  final void Function(AttachmentItem item)? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Keep each item's original index so the per-item widget keys are stable
    // (`att-{index}` / `att-remove-{index}`) regardless of image/file split.
    final images = <MapEntry<int, AttachmentItem>>[];
    final files = <MapEntry<int, AttachmentItem>>[];
    for (var i = 0; i < items.length; i++) {
      (items[i].isImage ? images : files).add(MapEntry(i, items[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Attachments', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (editable) ...[
              IconButton(
                key: const Key('att-add-image'),
                icon: const Icon(Icons.add_a_photo_outlined),
                tooltip: 'Add photo',
                onPressed: onAddImage,
              ),
              IconButton(
                key: const Key('att-add-pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Add PDF',
                onPressed: onAddPdf,
              ),
            ],
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Text('No attachments yet', style: theme.textTheme.bodySmall),
          ),
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in images)
                _Thumb(
                  key: Key('att-${e.key}'),
                  item: e.value,
                  resolver: resolver,
                  editable: editable,
                  removeKey: Key('att-remove-${e.key}'),
                  onTap: onTap == null ? null : () => onTap!(e.value),
                  onRemove:
                      onRemove == null ? null : () => onRemove!(e.value),
                ),
            ],
          ),
        for (final e in files)
          _FileCard(
            key: Key('att-${e.key}'),
            item: e.value,
            editable: editable,
            removeKey: Key('att-remove-${e.key}'),
            onTap: onTap == null ? null : () => onTap!(e.value),
            onRemove: onRemove == null ? null : () => onRemove!(e.value),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.item,
    required this.resolver,
    required this.editable,
    required this.removeKey,
    this.onTap,
    this.onRemove,
  });

  final AttachmentItem item;
  final IAttachmentResolver resolver;
  final bool editable;
  final Key removeKey;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final Widget image = switch (item) {
      PendingImageItem(:final pick) =>
        Image.memory(pick.bytes, width: 80, height: 80, fit: BoxFit.cover),
      SavedAttachmentItem(:final ref) => SizedBox(
          width: 80,
          height: 80,
          child: AttachmentImage(ref: ref, resolver: resolver),
        ),
      _ => const SizedBox(width: 80, height: 80),
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          ),
        ),
        if (editable && onRemove != null)
          Positioned(
            top: -10,
            right: -10,
            child: IconButton(
              key: removeKey,
              icon: const Icon(Icons.cancel, size: 20),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
          ),
      ],
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    super.key,
    required this.item,
    required this.editable,
    required this.removeKey,
    this.onTap,
    this.onRemove,
  });

  final AttachmentItem item;
  final bool editable;
  final Key removeKey;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (editable && onRemove != null)
              GestureDetector(
                key: removeKey,
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
