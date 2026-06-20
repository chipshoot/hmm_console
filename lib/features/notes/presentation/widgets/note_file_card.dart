import 'package:flutter/material.dart';

/// Journal-style file (PDF) card: doc icon + name + human size. Tap opens;
/// optional ✕ removes (editor only).
class NoteFileCard extends StatelessWidget {
  const NoteFileCard({
    super.key,
    required this.name,
    required this.byteSize,
    this.onOpen,
    this.onRemove,
    this.readOnly = false,
  });

  final String name;
  final int byteSize;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;
  final bool readOnly;

  static String humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onOpen,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                  Text(humanSize(byteSize), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (!readOnly && onRemove != null)
              GestureDetector(
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
