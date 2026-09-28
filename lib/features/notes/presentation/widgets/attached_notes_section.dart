import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/repository_providers.dart';
import '../../../../core/help/undoable_action.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
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
    this.showAdd = true,
  });

  final int parentId;
  final String title;

  /// The owning screen may offer its own add action, in which case the
  /// section must not duplicate it.
  final bool showAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
              HmmIconButton(
                tooltip: l.notesAttachExistingTooltip,
                icon: Icons.attach_file,
                onPressed: () => _attachExisting(context, ref),
              ),
              if (showAdd)
                HmmIconButton(
                  tooltip: l.notesAddTooltip,
                  icon: Icons.add,
                  onPressed: () async {
                    await context.push('/notes/new?parent=$parentId');
                    ref.invalidate(attachedNotesProvider(parentId));
                  },
                ),
            ],
          ),
        ),
        async.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(16), child: Text(l.notesGenericFailure('$e'))),
          data: (notes) => notes.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(16), child: Text(l.notesEmpty))
              : Column(
                  children: [
                    for (final n in notes)
                      ListTile(
                        title: Text(n.subject,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => context.push('/notes/${n.id}'),
                        trailing: HmmIconButton(
                          tooltip: l.notesDetachTooltip,
                          icon: Icons.link_off,
                          onPressed: () {
                            // The Undo snackbar outlives this screen, so it
                            // holds the container, not this widget's ref.
                            final mutate = ref.read(mutateNoteProvider);
                            final container = ProviderScope.containerOf(
                                context,
                                listen: false);
                            showUndoableAction(
                              context,
                              busyKey: ('detach', n.id),
                              run: () => mutate.detachNote(n.id),
                              undo: () => mutate.setParent(n.id, parentId),
                              done: l.undoNoteDetached,
                              failed: l.undoNoteDetachFailed,
                              undone: l.undoNoteRestored,
                              undoFailed: l.undoNoteRestoreFailed,
                              onChanged: () => container
                                  .invalidate(attachedNotesProvider(parentId)),
                            );
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
    final l = AppLocalizations.of(context);
    final general = await ref.read(generalCatalogProvider.future);
    final candidates = await ref
        .read(hmmNoteRepositoryProvider)
        .getUnattachedNotes(general.id);
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<HmmNote>(
      context: context,
      builder: (_) => SafeArea(
        child: candidates.isEmpty
            ? Padding(
                padding: EdgeInsets.all(24),
                child: Text(l.notesNoUnattached))
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
