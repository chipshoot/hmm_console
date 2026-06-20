import 'package:flutter/material.dart';

import '../../../../core/data/note_location.dart';

/// Journal-style location chip: a pin + label (or "lat, lng" when no label),
/// with an optional remove (✕). Used in the editor (editable) and the note
/// detail view (read-only).
class NoteLocationCard extends StatelessWidget {
  const NoteLocationCard({
    super.key,
    required this.location,
    this.onRemove,
    this.readOnly = false,
  });

  final NoteLocation location;
  final VoidCallback? onRemove;
  final bool readOnly;

  String get _text =>
      location.label ??
      '${location.latitude?.toStringAsFixed(4)}, '
          '${location.longitude?.toStringAsFixed(4)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (!readOnly && onRemove != null)
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}
