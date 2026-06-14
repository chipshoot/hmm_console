import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/repository_providers.dart';
import '../../data/general_catalog.dart';
import '../../data/models/hmm_note.dart';
import '../../states/attached_notes_state.dart';
import '../../states/mutate_note_state.dart';

/// Reusable "Notes" section for any parent note (an entity or a subsystem
/// anchor). Lists attached General notes and offers Add / Attach existing /
/// Detach. Drop it on any host screen with the parent's note id.
class AttachedNotesSection extends ConsumerWidget {
  const AttachedNotesSection({
    super.key,
    required this.parentId,
    this.title = 'Notes',
  });

  final int parentId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attachedNotesProvider(parentId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Attach existing note',
                icon: const Icon(Icons.attach_file),
                onPressed: () => _attachExisting(context, ref),
              ),
              IconButton(
                tooltip: 'Add note',
                icon: const Icon(Icons.add),
                onPressed: () => context.push('/notes/new?parent=$parentId'),
              ),
            ],
          ),
        ),
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(16), child: Text('Failed: $e')),
          data: (notes) => notes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16), child: Text('No notes yet'))
              : Column(
                  children: [
                    for (final n in notes)
                      ListTile(
                        title: Text(n.subject,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => context.push('/notes/${n.id}'),
                        trailing: IconButton(
                          tooltip: 'Detach',
                          icon: const Icon(Icons.link_off),
                          onPressed: () async {
                            await ref
                                .read(mutateNoteProvider)
                                .detachNote(n.id);
                            ref.invalidate(attachedNotesProvider(parentId));
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _attachExisting(BuildContext context, WidgetRef ref) async {
    final general = await ref.read(generalCatalogProvider.future);
    final candidates = await ref
        .read(hmmNoteRepositoryProvider)
        .getUnattachedNotes(general.id);
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<HmmNote>(
      context: context,
      builder: (_) => SafeArea(
        child: candidates.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No unattached notes'))
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final n in candidates)
                    ListTile(
                      title: Text(n.subject),
                      onTap: () => Navigator.of(context).pop(n),
                    ),
                ],
              ),
      ),
    );
    if (picked == null) return;
    await ref.read(mutateNoteProvider).attachExisting(picked.id, parentId);
    ref.invalidate(attachedNotesProvider(parentId));
  }
}
