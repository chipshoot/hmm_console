import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/picker/file_byte_source.dart';
import '../util/open_attachment.dart';
import 'note_file_card.dart';

/// Renders saved file refs + pending picks as [NoteFileCard]s. Saved cards
/// open via the OS on tap; pending cards can be removed.
class NoteFileCardList extends ConsumerWidget {
  const NoteFileCardList({
    super.key,
    required this.saved,
    this.pending = const [],
    this.onRemovePending,
    this.readOnly = false,
  });

  final List<AttachmentRef> saved;
  final List<PickedFileBytes> pending;
  final void Function(int index)? onRemovePending;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (saved.isEmpty && pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in saved)
          NoteFileCard(
            name:
                s is VaultRef ? (s.originalName ?? p.basename(s.path)) : 'file',
            byteSize: s is VaultRef ? s.byteSize : 0,
            readOnly: true,
            onOpen: () async {
              final err = await openAttachment(ref, s);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              }
            },
          ),
        for (var i = 0; i < pending.length; i++)
          NoteFileCard(
            name: pending[i].originalName,
            byteSize: pending[i].bytes.length,
            readOnly: readOnly,
            onRemove:
                onRemovePending == null ? null : () => onRemovePending!(i),
          ),
      ],
    );
  }
}
