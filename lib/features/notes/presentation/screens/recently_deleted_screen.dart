import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/local/note_purge_service.dart';
import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../rendering/note_display.dart';
import '../../states/mutate_note_state.dart';
import '../../states/note_selection.dart';
import '../../states/recently_deleted_provider.dart';

/// Rows share this tag so opening one swipe pane closes the previous one.
const _kGroup = 'recentlyDeleted';

/// On iOS a drag that starts this close to the left edge belongs to the
/// route's back swipe, not to the start (Restore) pane.
const _kIosBackSwipeEdge = 20.0;

bool _isApple(TargetPlatform p) =>
    p == TargetPlatform.iOS || p == TargetPlatform.macOS;

/// Notes deleted in the last 30 days: restore one, delete one now, or empty
/// the list. Deleting for good asks first and has no Undo.
class RecentlyDeletedScreen extends ConsumerWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(recentlyDeletedProvider);
    final items = async.value ?? const <DeletedNoteItem>[];
    final apple = _isApple(Theme.of(context).platform);
    final emptyAction = apple
        ? CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: items.isEmpty
                ? null
                : () => _emptyAll(context, ref, items),
            child: Text(l.notesEmptyAction),
          )
        : TextButton(
            onPressed: items.isEmpty
                ? null
                : () => _emptyAll(context, ref, items),
            child: Text(l.notesEmptyAction),
          );

    return AppScaffold(
      title: l.notesRecentlyDeletedTitle,
      actions: [
        const HelpButton(helpId: HelpId.notesRecentlyDeleted),
        emptyAction,
      ],
      slivers: [
        if (async.isLoading && !async.hasValue)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.delete_outline,
              message: l.notesRecentlyDeletedEmpty,
            ),
          )
        else
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => _DeletedRow(
              key: ValueKey(items[i].note.id),
              item: items[i],
              onRestore: (c) => _restore(c, ref, items[i]),
              onDeleteNow: (c) => _deleteNow(c, ref, items[i]),
            ),
          ),
      ],
    );
  }
}

class _DeletedRow extends ConsumerStatefulWidget {
  const _DeletedRow({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onDeleteNow,
  });

  final DeletedNoteItem item;
  final void Function(BuildContext) onRestore;
  final void Function(BuildContext) onDeleteNow;

  @override
  ConsumerState<_DeletedRow> createState() => _DeletedRowState();
}

class _DeletedRowState extends ConsumerState<_DeletedRow> {
  bool _edgeDown = false;

  void _setEdge(bool v) {
    if (v != _edgeDown) setState(() => _edgeDown = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final note = widget.item.note;
    final title = ref.read(noteDisplayRegistryProvider).title(note, null, l);

    Widget row = Slidable(
      key: ValueKey(note.id),
      groupTag: _kGroup,
      enabled: !_edgeDown,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: widget.onRestore,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            icon: Icons.restore,
            label: l.notesRestoreAction,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: widget.onDeleteNow,
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_forever,
            label: l.notesDeleteNow,
          ),
        ],
      ),
      child: ListTile(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(l.notesDeletesInDays(widget.item.daysLeft)),
        onTap: () => context.push('/notes/${note.id}'),
      ),
    );

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      row = Listener(
        onPointerDown: (e) => _setEdge(e.position.dx < _kIosBackSwipeEdge),
        onPointerUp: (_) => _setEdge(false),
        onPointerCancel: (_) => _setEdge(false),
        child: row,
      );
    }
    return row;
  }
}

Future<void> _restore(
  BuildContext context,
  WidgetRef ref,
  DeletedNoteItem item,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final mutate = ref.read(mutateNoteProvider);
  try {
    await mutate.restore(item.note.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.notesRestored)));
  } catch (e) {
    debugPrint('RecentlyDeleted: restore failed (${e.runtimeType})');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.notesRestoreFailed)));
  }
}

Future<void> _deleteNow(
  BuildContext context,
  WidgetRef ref,
  DeletedNoteItem item,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final purge = ref.read(notePurgeServiceProvider);
  final container = ProviderScope.containerOf(context);
  final ok = await _confirm(context, title: l.notesDeleteNowTitle);
  if (!ok) return;
  final outcome = await _purge(purge, container, item.note.id);
  final message = switch (outcome) {
    PurgeOutcome.purged => l.notesDeletedForGood,
    PurgeOutcome.keptLiveOnServer => l.notesKeptLiveElsewhere,
    PurgeOutcome.failed => l.notesDeleteFailed,
    PurgeOutcome.notEligible => null,
  };
  if (message == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _emptyAll(
  BuildContext context,
  WidgetRef ref,
  List<DeletedNoteItem> items,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final purge = ref.read(notePurgeServiceProvider);
  final container = ProviderScope.containerOf(context);
  final ids = [for (final i in items) i.note.id];
  final ok = await _confirm(context, title: l.notesEmptyTitle(ids.length));
  if (!ok) return;
  var purged = 0;
  for (final id in ids) {
    if (await _purge(purge, container, id) == PurgeOutcome.purged) purged++;
  }
  final message = purged == ids.length
      ? l.notesEmptied(purged)
      : l.notesEmptyPartial(purged, ids.length);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Purges one note; a purged note that is open in the wide detail pane
/// clears the selection.
Future<PurgeOutcome> _purge(
  NotePurgeService purge,
  ProviderContainer container,
  int id,
) async {
  PurgeOutcome outcome;
  try {
    outcome = await purge.purgeNow(id);
  } catch (e) {
    debugPrint('RecentlyDeleted: purge failed (${e.runtimeType})');
    outcome = PurgeOutcome.failed;
  }
  if (outcome == PurgeOutcome.purged &&
      container.read(selectedNoteIdProvider) == id) {
    container.read(selectedNoteIdProvider.notifier).select(null);
  }
  return outcome;
}

/// A destructive confirmation: Cancel and Delete Now. Cupertino on iOS and
/// macOS, Material elsewhere.
Future<bool> _confirm(BuildContext context, {required String title}) async {
  final l = AppLocalizations.of(context);
  final apple = _isApple(Theme.of(context).platform);
  final Future<bool?> pending = apple
      ? showCupertinoDialog<bool>(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(l.notesDeleteForGoodBody),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(c).pop(false),
                child: Text(l.commonCancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(c).pop(true),
                child: Text(l.notesDeleteNow),
              ),
            ],
          ),
        )
      : showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: Text(l.notesDeleteForGoodBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: Text(l.commonCancel),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(c).colorScheme.error,
                ),
                onPressed: () => Navigator.of(c).pop(true),
                child: Text(l.notesDeleteNow),
              ),
            ],
          ),
        );
  return await pending ?? false;
}
