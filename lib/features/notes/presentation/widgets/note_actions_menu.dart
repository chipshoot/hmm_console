import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/undoable_action.dart';
import '../../../../core/notes/note_flag.dart';
import '../../../../core/notes/note_state.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/models/hmm_note.dart';
import '../../rendering/note_display.dart';
import '../../states/mutate_note_state.dart';
import '../../states/note_delete_policy.dart';
import '../../states/note_sharer.dart';
import '../../states/notes_list_state.dart';
import '../catalog_labels.dart';
import 'note_flag_sheet.dart';
import 'note_link_picker.dart';
import 'note_tag_picker.dart';
import 'note_swipe_actions.dart' show deleteNoteWithUndo;

enum NoteMenuAction { pin, flag, tags, attach, share, select, delete, manage }

class NoteMenuItem {
  const NoteMenuItem(this.action, {this.enabled = true});

  final NoteMenuAction action;
  final bool enabled;
}

/// The menu items for a note, in the iOS / context-menu order (labels are
/// resolved by the widget). An entity note (Contacts, Cheatsheets,
/// Automobile ...) is shared and deleted from its own screen, so Attach is
/// hidden, Share is disabled and Manage replaces Delete.
List<NoteMenuItem> noteMenuItems({required bool ordinary}) => ordinary
    ? const [
        NoteMenuItem(NoteMenuAction.pin),
        NoteMenuItem(NoteMenuAction.flag),
        NoteMenuItem(NoteMenuAction.tags),
        NoteMenuItem(NoteMenuAction.attach),
        NoteMenuItem(NoteMenuAction.share),
        NoteMenuItem(NoteMenuAction.select),
        NoteMenuItem(NoteMenuAction.delete),
      ]
    : const [
        NoteMenuItem(NoteMenuAction.pin),
        NoteMenuItem(NoteMenuAction.flag),
        NoteMenuItem(NoteMenuAction.tags),
        NoteMenuItem(NoteMenuAction.share, enabled: false),
        NoteMenuItem(NoteMenuAction.select),
        NoteMenuItem(NoteMenuAction.manage, enabled: false),
      ];

String _placeLabel(String? catalogName, AppLocalizations l) => managePlaceLabel(
  managePlaceFor(catalogName) ?? NoteManagePlace.ownScreen,
  l,
);

String _labelOf(
  NoteMenuItem item,
  NoteState state,
  String? catalogName,
  AppLocalizations l,
) => switch (item.action) {
  NoteMenuAction.pin => state.isPinned ? l.notesUnpin : l.notesPin,
  NoteMenuAction.flag => l.notesFlagAction,
  NoteMenuAction.tags => l.notesTagsAction,
  NoteMenuAction.attach => l.notesAttachToAction,
  NoteMenuAction.share =>
    item.enabled
        ? l.notesShareAction
        : l.notesShareFrom(_placeLabel(catalogName, l)),
  NoteMenuAction.select => l.notesSelectAction,
  NoteMenuAction.delete => l.commonDelete,
  NoteMenuAction.manage => l.notesManageIn(_placeLabel(catalogName, l)),
};

IconData _iconOf(NoteMenuItem item, NoteState state) => switch (item.action) {
  NoteMenuAction.pin =>
    state.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
  NoteMenuAction.flag => Icons.flag_outlined,
  NoteMenuAction.tags => Icons.label_outline,
  NoteMenuAction.attach => Icons.subdirectory_arrow_right,
  NoteMenuAction.share => Icons.ios_share,
  NoteMenuAction.select => Icons.check_circle_outline,
  NoteMenuAction.delete => Icons.delete_outline,
  NoteMenuAction.manage => Icons.open_in_new,
};

/// The share popover's anchor: [anchor]'s box in global coordinates, or a
/// small rect at the centre of [screen] when there is none. Never empty (an
/// empty origin makes share_plus fail on iPad). Call it before a menu or
/// sheet pops, while [anchor] is still mounted.
Rect shareOriginFor(BuildContext? anchor, BuildContext screen) {
  if (anchor != null && anchor.mounted) {
    final box = anchor.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (!rect.isEmpty) return rect;
    }
  }
  final size = MediaQuery.sizeOf(screen);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}

/// Runs one menu action. Everything that is read from [ref] is read before
/// the first await; [context] is only used for the sheets and snackbars that
/// the (modal, hence still mounted) row owns.
Future<void> _runAction(
  BuildContext context,
  WidgetRef ref,
  NoteMenuAction action, {
  required HmmNote note,
  required NoteState state,
  required String? catalogName,
  required VoidCallback onSelect,
  required Rect origin,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final mutate = ref.read(mutateNoteProvider);
  switch (action) {
    case NoteMenuAction.pin:
      try {
        await mutate.setPinned(note.id, !state.isPinned);
      } catch (e) {
        debugPrint('NoteActionsMenu: pin failed (${e.runtimeType})');
        messenger.showSnackBar(SnackBar(content: Text(l.notesPinFailed)));
      }
    case NoteMenuAction.flag:
      final settings = ref.read(settingsProvider.notifier);
      final choice = await showNoteFlagSheet(
        context,
        current: NoteFlagColor.fromStored(state.flagColor),
      );
      if (choice == null) return; // dismissed: change nothing
      try {
        await mutate.setFlagColor(note.id, choice.color?.stored);
      } catch (e) {
        debugPrint('NoteActionsMenu: flag failed (${e.runtimeType})');
        messenger.showSnackBar(SnackBar(content: Text(l.notesFlagFailed)));
        return;
      }
      // Clearing a flag leaves the remembered colour alone. The flag itself
      // is applied by now, so a failure here is logged, not shown.
      if (choice.color != null) {
        try {
          await settings.setNotesLastFlagColor(choice.color!.stored);
        } catch (e) {
          debugPrint('NoteActionsMenu: last colour failed (${e.runtimeType})');
        }
      }
    case NoteMenuAction.tags:
      final current =
          ref.read(notesListStateProvider).value?.tagsByNoteId[note.id] ??
          const <NoteTagLabel>[];
      final before = {for (final t in current) t.id};
      final picked = await showNoteTagPicker(
        context,
        initial: {for (final id in before) id: TagMark.all},
      );
      if (picked == null) return; // dismissed: change nothing
      final after = {...before, ...picked.add}..removeAll(picked.remove);
      if (after.length == before.length && after.containsAll(before)) return;
      try {
        await mutate.setTags(note.id, after);
      } catch (e) {
        debugPrint('NoteActionsMenu: tags failed (${e.runtimeType})');
        messenger.showSnackBar(SnackBar(content: Text(l.notesTagFailed)));
      }
    case NoteMenuAction.attach:
      final registry = ref.read(noteDisplayRegistryProvider);
      final previousParent = note.parentNoteId;
      final picked = await showNoteLinkPicker(
        context,
        ref,
        excludeNoteId: note.id,
      );
      if (picked == null || !context.mounted) return;
      final title = registry.title(picked, null, l);
      await showUndoableAction(
        context,
        busyKey: ('attach', note.id),
        run: () async {
          await mutate.setParent(note.id, picked.id);
        },
        undo: () async {
          await mutate.setParent(note.id, previousParent);
        },
        done: l.notesAttached(title),
        failed: l.notesAttachFailed,
        undone: l.notesAttachUndone,
        undoFailed: l.notesAttachUndoFailed,
      );
    case NoteMenuAction.share:
      try {
        await ref
            .read(noteSharerProvider)
            .shareText(shareTextFor(note), origin: origin);
      } catch (e) {
        debugPrint('NoteActionsMenu: share failed (${e.runtimeType})');
        messenger.showSnackBar(SnackBar(content: Text(l.notesShareFailed)));
      }
    case NoteMenuAction.select:
      onSelect();
    case NoteMenuAction.delete:
      await deleteNoteWithUndo(context, ref, note.id);
    case NoteMenuAction.manage:
      final opened = ref
          .read(noteDisplayRegistryProvider)
          .open(context, note, catalogName);
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.notesManageIn(_placeLabel(catalogName, l)))),
        );
      }
  }
}

/// The Android / non-iOS long-press menu: a bottom sheet with Select first,
/// then the items of [noteMenuItems].
Future<void> showNoteActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required HmmNote note,
  required NoteState state,
  required String? catalogName,
  required VoidCallback onSelect,
  BuildContext? anchor,
}) {
  final l = AppLocalizations.of(context);
  // Taken now: the row is on screen, and the sheet is about to cover it.
  final origin = shareOriginFor(anchor, context);
  final items = noteMenuItems(ordinary: canDeleteFromNotes(note, catalogName));
  final select = items.firstWhere((i) => i.action == NoteMenuAction.select);
  final ordered = [select, ...items.where((i) => i != select)];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in ordered)
              ListTile(
                leading: Icon(_iconOf(item, state)),
                title: Text(_labelOf(item, state, catalogName, l)),
                enabled: item.enabled,
                onTap: item.enabled
                    ? () {
                        Navigator.of(sheet).pop();
                        unawaited(
                          _runAction(
                            context,
                            ref,
                            item.action,
                            note: note,
                            state: state,
                            catalogName: catalogName,
                            onSelect: onSelect,
                            origin: origin,
                          ),
                        );
                      }
                    : null,
              ),
          ],
        ),
      ),
    ),
  );
}

/// The iOS long-press menu: a [CupertinoContextMenu] around [child] (the
/// swipe-wrapped row, so swipes keep working). While the menu is open the
/// preview is [preview], the bare row at its own width.
class NoteContextMenu extends ConsumerWidget {
  const NoteContextMenu({
    super.key,
    required this.note,
    required this.state,
    required this.catalogName,
    required this.onSelect,
    required this.hostContext,
    required this.hostRef,
    required this.preview,
    required this.child,
  });

  final HmmNote note;
  final NoteState state;
  final String? catalogName;
  final VoidCallback onSelect;

  /// The list screen's context: it outlives the row, so an action that
  /// awaits (the Attach picker) still has a mounted context afterwards.
  final BuildContext hostContext;

  /// The list screen's ref, for the same reason as [hostContext].
  final WidgetRef hostRef;
  final Widget preview;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items = noteMenuItems(
      ordinary: canDeleteFromNotes(note, catalogName),
    );
    return LayoutBuilder(
      builder: (_, constraints) => CupertinoContextMenu.builder(
        actions: [
          for (final item in items)
            CupertinoContextMenuAction(
              isDestructiveAction: item.action == NoteMenuAction.delete,
              trailingIcon: _cupertinoIcon(item.action, state),
              onPressed: item.enabled
                  ? () {
                      final origin = shareOriginFor(context, hostContext);
                      Navigator.of(context, rootNavigator: true).pop();
                      unawaited(
                        _runAction(
                          hostContext,
                          hostRef,
                          item.action,
                          note: note,
                          state: state,
                          catalogName: catalogName,
                          onSelect: onSelect,
                          origin: origin,
                        ),
                      );
                    }
                  : null,
              child: Text(_labelOf(item, state, catalogName, l)),
            ),
        ],
        builder: (builderContext, _) {
          // Assumption: the list sits under the Scaffold's Material and the
          // context-menu overlay does not, so a Material ancestor means "in
          // the list": show the swipe-wrapped row. In the overlay (decoy and
          // preview) show the bare row at the list's width, with a Material
          // of its own for the InkWell.
          if (Material.maybeOf(builderContext) != null) return child;
          return Material(
            type: MaterialType.transparency,
            // The overlay squeezes the preview into an animated box; an
            // OverflowBox keeps the row at its own width and height so it is
            // scaled, never re-laid-out into an overflow. deferToChild: the
            // box takes the row's height, not all it is offered — in portrait
            // the menu sheet gets only what the preview leaves.
            child: ClipRect(
              child: OverflowBox(
                fit: OverflowBoxFit.deferToChild,
                alignment: Alignment.topLeft,
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
                minHeight: 0,
                maxHeight: double.infinity,
                child: ColoredBox(
                  color: Theme.of(builderContext).colorScheme.surface,
                  child: preview,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

IconData _cupertinoIcon(NoteMenuAction a, NoteState state) => switch (a) {
  NoteMenuAction.pin =>
    state.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
  NoteMenuAction.flag => CupertinoIcons.flag,
  NoteMenuAction.tags => CupertinoIcons.tag,
  NoteMenuAction.attach => CupertinoIcons.link,
  NoteMenuAction.share => CupertinoIcons.share,
  NoteMenuAction.select => CupertinoIcons.checkmark_circle,
  NoteMenuAction.delete => CupertinoIcons.delete,
  NoteMenuAction.manage => CupertinoIcons.arrow_up_right_square,
};
