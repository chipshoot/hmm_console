import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/undoable_action.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/models/hmm_note.dart';
import '../../query/note_results.dart';
import '../../states/note_bulk_actions.dart';
import '../../states/note_delete_policy.dart';
import '../../states/note_selection.dart';
import '../../states/notes_list_state.dart';
import '../../states/notes_multi_select.dart';
import '../../states/notes_results_provider.dart';
import 'note_flag_sheet.dart';
import 'note_tag_picker.dart';

/// The bar under the Notes list while several notes are being selected: Pin,
/// Flag and Delete for the ticked notes, and Select All for the visible list.
/// Every action leaves failed notes ticked so they can be retried.
class NotesBulkBar extends ConsumerWidget {
  const NotesBulkBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selection = ref.watch(notesMultiSelectProvider);
    final data = ref.watch(notesListStateProvider).value;
    final empty = selection.ids.isEmpty || data == null;
    final platform = Theme.of(context).platform;
    final isApple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final tickedNotes = empty
        ? const <HmmNote>[]
        : data.all.where((n) => selection.ids.contains(n.id)).toList();
    final allPinned =
        tickedNotes.isNotEmpty &&
        tickedNotes.every((n) => data!.stateOf(n).isPinned);
    final theme = Theme.of(context);

    final selectAll = isApple
        ? CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: () => _selectAll(ref),
            child: Text(l.notesSelectAll),
          )
        : TextButton(
            onPressed: () => _selectAll(ref),
            child: Text(l.notesSelectAll),
          );

    final bar = SafeArea(
      top: false,
      child: Row(
        children: [
          HmmIconButton(
            tooltip: allPinned ? l.notesUnpin : l.notesPin,
            icon: allPinned ? Icons.push_pin : Icons.push_pin_outlined,
            onPressed: empty ? null : () => _pin(context, ref),
          ),
          HmmIconButton(
            tooltip: l.notesFlagAction,
            icon: Icons.flag_outlined,
            onPressed: empty ? null : () => _flag(context, ref),
          ),
          HmmIconButton(
            tooltip: l.notesBulkTagsTooltip,
            icon: Icons.label_outline,
            onPressed: empty ? null : () => _tags(context, ref),
          ),
          HmmIconButton(
            tooltip: l.commonDelete,
            icon: Icons.delete_outline,
            onPressed: empty ? null : () => _delete(context, ref),
          ),
          const Spacer(),
          selectAll,
        ],
      ),
    );
    if (!isApple) {
      return Material(
        color: theme.colorScheme.surface,
        elevation: 3,
        child: bar,
      );
    }
    // Cupertino look: system background, hairline on top, no shadow.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Material(type: MaterialType.transparency, child: bar),
    );
  }

  void _selectAll(WidgetRef ref) {
    final results = ref.read(notesResultsProvider).value;
    if (results == null) return;
    ref.read(notesMultiSelectProvider.notifier).selectAll([
      for (final g in results.groups)
        for (final NoteHit h in g.hits) h.note.id,
    ]);
  }

  /// The ticked ids that are in the visible results, in list order. A tick
  /// a search has hidden is never acted on.
  List<int> _ids(WidgetRef ref) {
    final results = ref.read(notesResultsProvider).value;
    final ticked = ref.read(notesMultiSelectProvider).ids;
    if (results == null) return const [];
    return [
      for (final g in results.groups)
        for (final NoteHit h in g.hits)
          if (ticked.contains(h.note.id)) h.note.id,
    ];
  }

  Future<void> _pin(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = ref.read(notesListStateProvider).value;
    final actions = ref.read(noteBulkActionsProvider);
    final multi = ref.read(notesMultiSelectProvider.notifier);
    final ids = _ids(ref);
    if (data == null || ids.isEmpty) return;
    final idSet = ids.toSet();
    final pinnedById = {
      for (final n in data.all)
        if (idSet.contains(n.id)) n.id: data.stateOf(n).isPinned,
    };
    final (pinned, outcome) = await actions.togglePinned(ids, pinnedById);
    if (outcome.failed.isEmpty) {
      multi.exit();
      return;
    }
    multi.keepOnly(outcome.failed);
    final text = pinned
        ? l.notesBulkPinPartial(outcome.succeeded.length, outcome.total)
        : l.notesBulkUnpinPartial(outcome.succeeded.length, outcome.total);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _flag(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(noteBulkActionsProvider);
    final multi = ref.read(notesMultiSelectProvider.notifier);
    final settings = ref.read(settingsProvider.notifier);
    final ids = _ids(ref);
    if (ids.isEmpty) return;
    final choice = await showNoteFlagSheet(context, current: null);
    if (choice == null) return; // dismissed: change nothing
    final outcome = await actions.setFlag(ids, choice.color?.stored);
    if (choice.color != null && outcome.succeeded.isNotEmpty) {
      // Clearing leaves the remembered colour alone. The flags are applied by
      // now, so a failure here is logged, not shown.
      try {
        await settings.setNotesLastFlagColor(choice.color!.stored);
      } catch (e) {
        debugPrint('NotesBulkBar: last colour failed (${e.runtimeType})');
      }
    }
    if (outcome.failed.isEmpty) {
      multi.exit();
      return;
    }
    multi.keepOnly(outcome.failed);
    final text = choice.color == null
        ? l.notesBulkUnflagPartial(outcome.succeeded.length, outcome.total)
        : l.notesBulkFlagPartial(outcome.succeeded.length, outcome.total);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _tags(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = ref.read(notesListStateProvider).value;
    final actions = ref.read(noteBulkActionsProvider);
    final multi = ref.read(notesMultiSelectProvider.notifier);
    final ids = _ids(ref);
    if (data == null || ids.isEmpty) return;
    final current = {
      for (final id in ids)
        id: {
          for (final t in data.tagsByNoteId[id] ?? const <NoteTagLabel>[]) t.id,
        },
    };
    final counts = <int, int>{};
    for (final tags in current.values) {
      for (final t in tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final picked = await showNoteTagPicker(
      context,
      initial: {
        for (final e in counts.entries)
          e.key: e.value == ids.length ? TagMark.all : TagMark.some,
      },
    );
    if (picked == null) return; // dismissed: change nothing
    final outcome = await actions.applyTags(
      ids,
      current,
      add: picked.add,
      remove: picked.remove,
    );
    if (outcome.failed.isEmpty) {
      multi.exit();
      return;
    }
    multi.keepOnly(outcome.failed);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l.notesBulkTagPartial(outcome.succeeded.length, outcome.total),
          ),
        ),
      );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = ref.read(notesListStateProvider).value;
    final actions = ref.read(noteBulkActionsProvider);
    // The container outlives this widget; the snackbar's Undo may run after
    // the bar is gone, so nothing below touches the WidgetRef.
    final container = ProviderScope.containerOf(context);
    final multi = ref.read(notesMultiSelectProvider.notifier);
    final ids = _ids(ref);
    if (data == null || ids.isEmpty) return;

    final byId = {for (final n in data.all) n.id: n};
    bool isOrdinary(int id) {
      final note = byId[id];
      return note != null &&
          canDeleteFromNotes(note, data.catalogsById[note.catalogId]?.name);
    }

    final eligible = ids.where(isOrdinary).toList();
    final skipped = ids.where((id) => !isOrdinary(id)).toList();
    final done = bulkDeleteMessage(
      BulkDeleteOutcome(deleted: eligible, skipped: skipped, failed: const []),
      l,
    );
    if (done == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l.notesBulkNothingDeleted(skipped.length))),
        );
      return;
    }

    var deleted = const <int>[];
    var settled = false;
    await showUndoableAction(
      context,
      busyKey: ('bulkDelete',),
      run: () async {
        final outcome = await actions.delete(ids, isOrdinary);
        deleted = outcome.deleted;
        multi.keepOnly([...outcome.skipped, ...outcome.failed]);
        // The open note (wide layout) is gone: close its detail pane.
        final open = container.read(selectedNoteIdProvider);
        if (open != null && outcome.deleted.contains(open)) {
          container.read(selectedNoteIdProvider.notifier).select(null);
        }
        if (outcome.failed.isNotEmpty) {
          throw StateError('${outcome.failed.length} notes not deleted');
        }
      },
      undo: () async {
        final restored = await actions.restore(deleted);
        if (restored.failed.isNotEmpty) {
          throw StateError('${restored.failed.length} notes not restored');
        }
      },
      onChanged: () {
        // Only after the delete itself; an Undo later must not end a new
        // selection the user has started since.
        if (settled) return;
        settled = true;
        if (container.read(notesMultiSelectProvider).ids.isEmpty) {
          multi.exit();
        }
      },
      done: done,
      failed: l.notesBulkDeleteSomeFailed,
      undone: l.notesBulkRestored(eligible.length),
      undoFailed: l.notesBulkRestoreFailed,
    );
  }
}
