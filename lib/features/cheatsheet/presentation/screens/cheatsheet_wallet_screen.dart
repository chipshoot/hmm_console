import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../data/cheatsheet_templates.dart';

import '../../../../core/navigation/route_names.dart';
import '../../domain/entities/cheatsheet_card.dart';
import '../../states/cheatsheets_state.dart';

/// Navigation seams. Widget tests override these instead of standing up a
/// router; T15 wires the real routes behind them.
final cheatsheetOpenCardProvider = Provider<void Function(BuildContext, String)>(
  (ref) => (context, id) => context.pushNamed(
        RouterNames.cheatsheetDetail.name,
        pathParameters: {'id': id},
      ),
);

final cheatsheetCreateCardProvider = Provider<void Function(BuildContext)>(
  (ref) => (context) => context.pushNamed(RouterNames.cheatsheetCreate.name),
);

/// Normalized tag form: trimmed and lower-cased.
///
/// Tags are free text typed by hand, so `Legal`, `legal ` and `legal` are the
/// same tag. Normalizing at both the chip list and the match keeps the filter
/// from silently missing cards over a stray capital or space.
String normalizeTag(String tag) => tag.trim().toLowerCase();

/// The card wallet: grouped, searchable, filterable.
class CheatsheetWalletScreen extends ConsumerStatefulWidget {
  const CheatsheetWalletScreen({super.key});

  @override
  ConsumerState<CheatsheetWalletScreen> createState() =>
      _CheatsheetWalletScreenState();
}

class _CheatsheetWalletScreenState
    extends ConsumerState<CheatsheetWalletScreen> {
  String _query = '';
  final _selectedTags = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cards = ref.watch(cheatsheetsStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.cheatsheetWalletTitle),
        actions: [
          IconButton(
            key: const Key('wallet-add'),
            icon: const Icon(Icons.add),
            tooltip: l.cheatsheetNew,
            onPressed: () => ref.read(cheatsheetCreateCardProvider)(context),
          ),
        ],
      ),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          key: const Key('wallet-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.cheatsheetLoadFailed('$e')),
          ),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(List<CheatsheetCard> all) {
    final l = AppLocalizations.of(context);
    if (all.isEmpty) {
      return Center(
        key: const Key('wallet-empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.cheatsheetEmpty),
        ),
      );
    }

    final tags = _allTags(all);
    final matches = _filter(all);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const Key('wallet-search'),
            decoration: InputDecoration(
              hintText: l.cheatsheetSearchHint,
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final tag in tags)
                  FilterChip(
                    key: Key('wallet-tag-$tag'),
                    label: Text(tag),
                    selected: _selectedTags.contains(tag),
                    onSelected: (on) => setState(
                      () => on
                          ? _selectedTags.add(tag)
                          : _selectedTags.remove(tag),
                    ),
                  ),
              ],
            ),
          ),
        if (matches.isEmpty)
          Expanded(
            child: Center(
              key: const Key('wallet-no-matches'),
              child: Text(l.cheatsheetNoMatches),
            ),
          )
        else
          Expanded(child: _groupedList(matches)),
      ],
    );
  }

  /// Every tag in use, normalized and de-duplicated, in a stable order.
  List<String> _allTags(List<CheatsheetCard> cards) {
    final seen = <String>{};
    for (final c in cards) {
      for (final t in c.tags) {
        final n = normalizeTag(t);
        if (n.isNotEmpty) seen.add(n);
      }
    }
    return seen.toList()..sort();
  }

  List<CheatsheetCard> _filter(List<CheatsheetCard> cards) {
    final q = _query.trim().toLowerCase();
    return cards.where((c) {
      if (q.isNotEmpty && !c.title.toLowerCase().contains(q)) return false;
      if (_selectedTags.isEmpty) return true;
      final cardTags = c.tags.map(normalizeTag).toSet();
      return _selectedTags.every(cardTags.contains);
    }).toList();
  }

  Widget _groupedList(List<CheatsheetCard> cards) {
    final l = AppLocalizations.of(context);
    final groups = <String, List<CheatsheetCard>>{};
    for (final c in cards) {
      groups.putIfAbsent(c.walletGroup, () => []).add(c);
    }

    // Deterministic throughout: groups by name, cards by title, then id as the
    // tie-breaker. Without the id, two same-titled cards could swap places
    // between builds — v1 has no user ordering, but it must not be arbitrary.
    final names = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final list in groups.values) {
      list.sort((a, b) {
        final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      });
    }

    return ListView(
      children: [
        for (final name in names) ...[
          Padding(
            key: Key('wallet-group-$name'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            // The KEY stays `name` (the stored English group) so the widget
            // key and the sort order are language-independent; only the text
            // shown is translated. See cheatsheet_templates.dart.
            child: Text(
              cheatsheetGroupLabel(name, l).toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          for (final c in groups[name]!)
            ListTile(
              key: Key('wallet-card-${c.id}'),
              title: Text(c.title),
              subtitle: c.rows.isEmpty
                  ? null
                  : Text(
                      '${c.rows.length} row${c.rows.length == 1 ? '' : 's'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ref.read(cheatsheetOpenCardProvider)(context, c.id),
            ),
        ],
      ],
    );
  }
}
