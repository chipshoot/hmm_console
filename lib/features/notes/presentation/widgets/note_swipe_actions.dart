import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/help/undoable_action.dart';
import '../../../../core/notes/note_state.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/models/hmm_note.dart';
import '../../rendering/note_display.dart';
import '../../states/mutate_note_state.dart';
import '../../states/note_delete_policy.dart';
import '../../states/note_selection.dart';
import '../catalog_labels.dart';
import 'ios_edge_swipe_guard.dart';

/// Rows of one list share this tag, so opening one swipe pane closes the
/// previous one.
const _kListGroup = 'notesList';

/// Delete = move to Recently Deleted, with Undo (restore). Shared by swipe,
/// long-press and the note detail screen. When the deleted note is the one
/// open in the wide-screen detail pane, the selection is cleared. Returns
/// true when the note was moved.
///
/// The snackbar (and a swipe-dismissed row) outlive the caller's element, so
/// everything is captured before the first await.
Future<bool> deleteNoteWithUndo(
  BuildContext context,
  WidgetRef ref,
  int noteId,
) async {
  final l = AppLocalizations.of(context);
  final mutate = ref.read(mutateNoteProvider);
  final container = ProviderScope.containerOf(context);
  final isWide = MediaQuery.of(context).size.width >= kNotesWideBreakpoint;
  var moved = false;
  await showUndoableAction(
    context,
    busyKey: ('deleteNote', noteId),
    run: () async {
      await mutate.delete(noteId);
      moved = true;
    },
    undo: () async {
      await mutate.restore(noteId);
    },
    done: l.notesMovedToRecentlyDeleted,
    failed: l.notesDeleteFailed,
    undone: l.notesRestored,
    undoFailed: l.notesRestoreFailed,
  );
  if (moved && isWide && container.read(selectedNoteIdProvider) == noteId) {
    container.read(selectedNoteIdProvider.notifier).select(null);
  }
  return moved;
}

/// Swipe right: Pin / Unpin. Swipe left: Flag / Unflag, plus Delete for an
/// ordinary note or Manage for an entity note (G7).
class NoteSwipeActions extends ConsumerStatefulWidget {
  const NoteSwipeActions({
    super.key,
    required this.note,
    required this.state,
    required this.catalogName,
    required this.enabled,
    required this.child,
  });

  final HmmNote note;
  final NoteState state;
  final String? catalogName;

  /// False during multi-select.
  final bool enabled;
  final Widget child;

  @override
  ConsumerState<NoteSwipeActions> createState() => _NoteSwipeActionsState();
}

class _NoteSwipeActionsState extends ConsumerState<NoteSwipeActions> {
  Future<void> _togglePin(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mutate = ref.read(mutateNoteProvider);
    try {
      await mutate.setPinned(widget.note.id, !widget.state.isPinned);
    } catch (e) {
      debugPrint('NoteSwipeActions: pin failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.notesPinFailed)));
    }
  }

  Future<void> _toggleFlag(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mutate = ref.read(mutateNoteProvider);
    final color = widget.state.flagColor == null
        ? ref.read(notesLastFlagColorProvider)
        : null;
    try {
      await mutate.setFlagColor(widget.note.id, color);
    } catch (e) {
      debugPrint('NoteSwipeActions: flag failed (${e.runtimeType})');
      messenger.showSnackBar(SnackBar(content: Text(l.notesFlagFailed)));
    }
  }

  void _manage(BuildContext context) {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = ref
        .read(noteDisplayRegistryProvider)
        .open(context, widget.note, widget.catalogName);
    if (opened) return;
    final place =
        managePlaceFor(widget.catalogName) ?? NoteManagePlace.ownScreen;
    messenger.showSnackBar(
      SnackBar(content: Text(l.notesManageIn(managePlaceLabel(place, l)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pinned = widget.state.isPinned;
    final flagged = widget.state.flagColor != null;
    final deletable = canDeleteFromNotes(widget.note, widget.catalogName);

    Widget slidable(bool enabled) => Slidable(
      key: ValueKey(widget.note.id),
      groupTag: _kListGroup,
      enabled: enabled,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: _togglePin,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            icon: pinned ? Icons.push_pin_outlined : Icons.push_pin,
            label: pinned ? l.notesUnpin : l.notesPin,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        dismissible: deletable
            // The delete runs BEFORE the row is dismissed: if it fails the row
            // springs back instead of staying collapsed.
            ? DismissiblePane(
                confirmDismiss: () =>
                    deleteNoteWithUndo(context, ref, widget.note.id),
                onDismissed: () {},
                closeOnCancel: true,
              )
            : null,
        children: [
          SlidableAction(
            onPressed: _toggleFlag,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: flagged ? Icons.outlined_flag : Icons.flag,
            label: flagged ? l.notesUnflag : l.notesFlag,
          ),
          if (deletable)
            SlidableAction(
              onPressed: (c) => deleteNoteWithUndo(c, ref, widget.note.id),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: l.commonDelete,
            )
          else
            SlidableAction(
              onPressed: _manage,
              backgroundColor: scheme.secondary,
              foregroundColor: scheme.onSecondary,
              icon: Icons.open_in_new,
              label: l.notesManageShort,
            ),
        ],
      ),
      child: widget.child,
    );

    return IosEdgeSwipeGuard(builder: slidable);
  }
}
