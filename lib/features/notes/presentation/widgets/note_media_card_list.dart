import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/attachment_providers.dart';
import '../../../../core/data/attachments/picker/image_byte_source.dart';
import '../../../../core/data/attachments/widgets/attachment_image.dart';
import '../../../../core/data/attachments/widgets/fullscreen_image.dart';

/// Apple-Journal-style media: large rounded image cards. Shows saved
/// attachments (resolved from the vault) and pending picks (from local bytes).
class NoteMediaCardList extends StatelessWidget {
  const NoteMediaCardList({
    super.key,
    required this.saved,
    this.pending = const [],
    this.onRemovePending,
    this.readOnly = false,
  });

  final List<AttachmentRef> saved;
  final List<PickedImageBytes> pending;
  final void Function(int index)? onRemovePending;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      for (final ref in saved)
        NoteMediaCard(
          onTap: () => showFullscreenImage(context, ref),
          child: _SavedImage(ref: ref),
        ),
      for (var i = 0; i < pending.length; i++)
        NoteMediaCard(
          onRemove: readOnly ? null : () => onRemovePending?.call(i),
          child: Image.memory(pending[i].bytes,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              width: double.infinity),
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in cards)
          Padding(padding: const EdgeInsets.only(top: 12), child: c),
      ],
    );
  }
}

/// One rounded media card with an optional remove (✕) and tap handler.
class NoteMediaCard extends StatelessWidget {
  const NoteMediaCard(
      {super.key, required this.child, this.onTap, this.onRemove});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(height: 180, width: double.infinity, child: child),
          ),
        ),
        if (onRemove != null)
          PositionedDirectional(
            top: 8,
            end: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 13,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _SavedImage extends ConsumerWidget {
  const _SavedImage({required this.ref});
  final AttachmentRef ref;
  @override
  Widget build(BuildContext context, WidgetRef wref) {
    final resolverAsync = wref.watch(attachmentResolverProvider);
    return resolverAsync.when(
      data: (resolver) => AttachmentImage(
          ref: ref,
          resolver: resolver,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter),
      loading: () => const ColoredBox(
          color: Color(0xFFF2F2F7),
          child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const ColoredBox(
          color: Color(0xFFF2F2F7), child: Icon(Icons.broken_image_outlined)),
    );
  }
}
