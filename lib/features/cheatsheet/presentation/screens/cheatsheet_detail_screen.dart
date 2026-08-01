import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/repository_providers.dart';
import '../../../../core/navigation/route_names.dart';
import '../../data/cheatsheet_launcher.dart';
import '../../data/cheatsheet_resolver.dart';
import '../../domain/entities/cheatsheet_card.dart';
import '../../domain/entities/cheatsheet_row.dart';
import '../../domain/entities/cheatsheet_source.dart';
import '../../states/cheatsheets_state.dart';

final cheatsheetResolverProvider = Provider<CheatsheetResolver>(
  (ref) => CheatsheetResolver(ref.watch(hmmNoteRepositoryProvider)),
);

/// Opens the note a row points at.
///
/// Rows reference notes by **uuid** (stable across devices) but the note route
/// takes the **local int id**, so this is a lookup, not a string swap. A
/// source that hasn't synced to this device yet has no local row to open — the
/// row already renders as "source removed", so this does nothing rather than
/// navigating somewhere wrong.
final cheatsheetOpenSourceProvider =
    Provider<void Function(BuildContext, String)>(
  (ref) => (context, noteUuid) async {
    final note =
        await ref.read(hmmNoteRepositoryProvider).getNoteByUuid(noteUuid);
    if (note == null || !context.mounted) return;
    context.pushNamed(
      RouterNames.noteDetail.name,
      pathParameters: {'id': '${note.id}'},
    );
  },
);

final cheatsheetEditCardProvider = Provider<void Function(BuildContext, String)>(
  (ref) => (context, cardId) => context.pushNamed(
        RouterNames.cheatsheetEdit.name,
        pathParameters: {'id': cardId},
      ),
);

/// Resolves every row of a card, in order.
final cheatsheetResolvedRowsProvider = FutureProvider.autoDispose
    .family<List<ResolvedValue>, String>((ref, cardId) async {
  final cards = await ref.watch(cheatsheetsStateProvider.future);
  final card = _findCard(cards, cardId);
  if (card == null) return const [];

  final resolver = ref.watch(cheatsheetResolverProvider);
  final out = <ResolvedValue>[];
  for (final row in card.rows) {
    out.add(await resolver.resolve(row));
  }
  return out;
});

CheatsheetCard? _findCard(List<CheatsheetCard> cards, String id) {
  for (final c in cards) {
    if (c.id == id) return c;
  }
  return null;
}

/// Read-only view of a card with its values resolved live.
class CheatsheetDetailScreen extends ConsumerWidget {
  const CheatsheetDetailScreen({super.key, required this.cardId});

  final String cardId;

  /// Confirms, then deletes. Destructive and one tap from the card, so it asks
  /// first — and says plainly that the referenced notes survive, since a card
  /// is a view onto them, not a container for them.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // Captured before the await: `ref.read` throws once this widget is
    // unmounted, and the dialog is an await gap during which that can happen.
    final cheatsheets = ref.read(cheatsheetsStateProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this cheatsheet?'),
        content: const Text(
          'The notes it references are not deleted — only this card.',
        ),
        actions: [
          TextButton(
            key: const Key('delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await cheatsheets.remove(cardId);
    } catch (e) {
      // A delete that silently didn't happen is worse than one that failed
      // loudly — the user walks away believing the card is gone.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete this cheatsheet: $e')),
      );
      return;
    }
    // The card this screen shows no longer exists; staying would strand the
    // user on a not-found state.
    if (context.mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cheatsheetsStateProvider);
    final card = _findCard(cards.value ?? const [], cardId);

    if (cards.isLoading && card == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (card == null) {
      return const Scaffold(
        body: Center(
          key: Key('detail-not-found'),
          child: Text('That cheatsheet no longer exists.'),
        ),
      );
    }

    final resolved = ref.watch(cheatsheetResolvedRowsProvider(cardId));

    return Scaffold(
      appBar: AppBar(
        title: Text(card.title),
        actions: [
          IconButton(
            key: const Key('detail-edit'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit cheatsheet',
            onPressed: () =>
                ref.read(cheatsheetEditCardProvider)(context, cardId),
          ),
          IconButton(
            key: const Key('detail-delete'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete cheatsheet',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: resolved.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (values) => ListView(
          children: [
            for (var i = 0; i < card.rows.length; i++)
              _RowTile(
                index: i,
                row: card.rows[i],
                value: i < values.length ? values[i] : const ResolvedValue(),
              ),
          ],
        ),
      ),
    );
  }
}

class _RowTile extends ConsumerWidget {
  const _RowTile({
    required this.index,
    required this.row,
    required this.value,
  });

  final int index;
  final CheatsheetRow row;
  final ResolvedValue value;

  Future<void> _launch(BuildContext context, WidgetRef ref, String text) async {
    try {
      await ref.read(launchActionProvider)(row.valueAction, text);
    } on Exception catch (_) {
      // Exceptions only. A missing handler app is an expected, recoverable
      // outcome worth reporting; an Error is a defect, and showing it as
      // "could not open that" would disguise a bug as a normal failure.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CheatsheetSource? source = row.source;
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).disabledColor,
          fontStyle: FontStyle.italic,
        );

    final Widget valueWidget;
    if (value.unbound) {
      valueWidget = Text('—', key: Key('row-$index-unbound'), style: muted);
    } else if (value.missing) {
      valueWidget = Text(
        'source removed',
        key: Key('row-$index-missing'),
        style: muted,
      );
    } else {
      final text = value.text ?? '';
      final action = row.valueAction;
      valueWidget = InkWell(
        key: Key('row-$index-value'),
        onTap: action == ValueAction.none
            ? null
            : () => _launch(context, ref, text),
        child: Text(
          text,
          style: action == ValueAction.none
              ? null
              : TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    return ListTile(
      title: Text(row.label),
      subtitle: valueWidget,
      trailing: row.openSource && source != null
          ? IconButton(
              key: Key('row-$index-open-source'),
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open the source note',
              onPressed: () => ref.read(cheatsheetOpenSourceProvider)(
                context,
                source.noteUuid,
              ),
            )
          : null,
    );
  }
}
