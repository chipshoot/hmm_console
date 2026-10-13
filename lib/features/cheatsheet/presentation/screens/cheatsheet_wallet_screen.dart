import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../core/navigation/route_names.dart';
import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/cheatsheet_templates.dart';
import '../../domain/entities/cheatsheet_card.dart';
import '../../states/cheatsheets_state.dart';
import '../look/card_tile.dart';

/// Navigation seams. Widget tests override these instead of standing up a
/// router; T15 wires the real routes behind them.
final cheatsheetOpenCardProvider =
    Provider<void Function(BuildContext, String)>(
      (ref) =>
          (context, id) => context.pushNamed(
            RouterNames.cheatsheetDetail.name,
            pathParameters: {'id': id},
          ),
    );

final cheatsheetCreateCardProvider = Provider<void Function(BuildContext)>(
  (ref) =>
      (context) => context.pushNamed(RouterNames.cheatsheetCreate.name),
);

/// Normalized tag form: trimmed and lower-cased.
///
/// Tags are free text typed by hand, so `Legal`, `legal ` and `legal` are the
/// same tag. Normalizing at both the chip list and the match keeps the filter
/// from silently missing cards over a stray capital or space.
String normalizeTag(String tag) => tag.trim().toLowerCase();

/// Tile columns for a wallet [width] in logical pixels: 2 on phones, 3 from
/// 600 dp, 4 from 900 dp.
int walletColumnsFor(double width) => width >= 900 ? 4 : (width >= 600 ? 3 : 2);

/// The card wallet: a searchable grid of tiles, filtered by wallet group
/// (single-select chips) and by tags.
class CheatsheetWalletScreen extends ConsumerStatefulWidget {
  const CheatsheetWalletScreen({super.key});

  @override
  ConsumerState<CheatsheetWalletScreen> createState() =>
      _CheatsheetWalletScreenState();
}

class _CheatsheetWalletScreenState
    extends ConsumerState<CheatsheetWalletScreen> {
  String _query = '';

  /// The stored (English-key) wallet group, or null for All.
  String? _group;
  final _selectedTags = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cards = ref.watch(cheatsheetsStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.cheatsheetWalletTitle),
        actions: [
          const HelpButton(helpId: HelpId.cheatsheetWallet),
          HmmIconButton(
            key: const Key('wallet-add'),
            icon: Icons.add,
            tooltip: l.cheatsheetNew,
            onPressed: () => ref.read(cheatsheetCreateCardProvider)(context),
          ),
        ],
      ),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Never the exception text on screen: it can quote stored values.
        error: (_, _) => Center(
          key: const Key('wallet-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.cheatsheetLoadFailed),
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

    final groups = _groupsInUse(all);
    // A chosen group whose last card was deleted falls back to All.
    final group = groups.contains(_group) ? _group : null;
    final tags = _allTags(all);
    final matches = _filter(all, group);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const Key('wallet-search'),
            decoration: InputDecoration(
              hintText: l.cheatsheetSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: const Key('wallet-group-all'),
                  label: Text(l.cheatsheetChipAll),
                  selected: group == null,
                  onSelected: (_) => setState(() => _group = null),
                ),
              ),
              for (final name in groups)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // The KEY stays `name` (the stored English group) so it is
                  // language-independent; only the label is translated.
                  child: ChoiceChip(
                    key: Key('wallet-group-$name'),
                    label: Text(cheatsheetGroupLabel(name, l)),
                    selected: group == name,
                    onSelected: (_) => setState(() => _group = name),
                  ),
                ),
            ],
          ),
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
          Expanded(child: _grid(matches)),
      ],
    );
  }

  /// Every wallet group in use, sorted case-insensitively.
  List<String> _groupsInUse(List<CheatsheetCard> cards) {
    final seen = {for (final c in cards) c.walletGroup};
    return seen.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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

  List<CheatsheetCard> _filter(List<CheatsheetCard> cards, String? group) {
    final q = _query.trim().toLowerCase();
    return cards.where((c) {
      if (group != null && c.walletGroup != group) return false;
      if (q.isNotEmpty && !c.title.toLowerCase().contains(q)) return false;
      if (_selectedTags.isEmpty) return true;
      final cardTags = c.tags.map(normalizeTag).toSet();
      return _selectedTags.every(cardTags.contains);
    }).toList();
  }

  Widget _grid(List<CheatsheetCard> cards) {
    // Deterministic: title case-insensitively, then id as the tie-breaker.
    // Without the id, two same-titled cards could swap places between builds.
    final sorted = [...cards]
      ..sort((a, b) {
        final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      });

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        key: const Key('wallet-grid'),
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: walletColumnsFor(constraints.maxWidth),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: sorted.length,
        itemBuilder: (context, i) {
          final c = sorted[i];
          return CardTile(
            key: Key('wallet-card-${c.id}'),
            card: c,
            onTap: () => ref.read(cheatsheetOpenCardProvider)(context, c.id),
          );
        },
      ),
    );
  }
}
