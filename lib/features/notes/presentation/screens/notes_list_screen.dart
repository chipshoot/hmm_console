import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart' show setEquals;

import '../../states/filter_usage.dart';
import '../../states/notes_list_state.dart';
import '../../states/note_selection.dart'
    show kNotesWideBreakpoint, selectedNoteIdProvider;
import '../widgets/catalog_filter_sheet.dart';
import '../widgets/domain_groups.dart';
import '../widgets/note_list_tile.dart';
import '../widgets/sort_sheet.dart';
import '../../../../core/notes/catalog_palette.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_row_separator.dart';
import '../../../../core/widgets/app_scaffold.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notesListStateProvider);
    final notifier = ref.read(notesListStateProvider.notifier);
    final usage = ref.watch(filterUsageProvider).value ?? const {};

    return AppScaffold(
      title: 'Notes',
      drawer: async.maybeWhen(
        data: (data) => _FilterDrawer(data: data),
        orElse: () => null,
      ),
      actions: [
        IconButton(
          tooltip: 'Sort',
          icon: const Icon(Icons.swap_vert),
          onPressed: async.hasValue
              ? () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => SortSheet(
                      current: async.value!.sort,
                      onSelected: notifier.setSort,
                    ),
                  )
              : null,
        ),
        IconButton(
          tooltip: 'Filter',
          icon: const Icon(Icons.filter_list),
          onPressed: async.hasValue
              ? () {
                  final data = async.value!;
                  final usage =
                      ref.read(filterUsageProvider).value ?? const {};
                  final groups = groupByDomain(
                      data.catalogsById.values, data.countsByCatalog, usage);
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => CatalogFilterSheet(
                      groups: groups,
                      counts: data.countsByCatalog,
                      selected: data.catalogFilter,
                      onApply: notifier.setFilter,
                      onRecordDomain: (key) => ref
                          .read(filterUsageProvider.notifier)
                          .record(key),
                    ),
                  );
                }
              : null,
        ),
        IconButton(
          tooltip: 'Subsystems',
          icon: const Icon(Icons.widgets_outlined),
          onPressed: () => context.push('/notes/subsystems'),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/notes/new'),
        child: const Icon(Icons.add),
      ),
      slivers: async.when<List<Widget>>(
        loading: () => const [
          SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
        ],
        error: (e, _) => [
          SliverFillRemaining(
            child: Center(child: Text('Failed to load notes: $e')),
          ),
        ],
        data: (data) {
          // Resolve the active domain (main filter) and, if it has more than
          // one catalog, the sub-filter selection within it.
          final f = data.catalogFilter;
          final groups = groupByDomain(
              data.catalogsById.values, data.countsByCatalog, usage);
          DomainGroup? activeDomain;
          if (f != null && f.isNotEmpty) {
            for (final g in groups) {
              if (f.every(g.catalogIds.contains)) {
                activeDomain = g;
                break;
              }
            }
          }
          final mainLabel = activeDomain?.style.displayName ??
              ((f == null || f.isEmpty) ? 'All' : 'Filtered');
          final subDomain =
              (activeDomain != null && activeDomain.catalogs.length > 1)
                  ? activeDomain
                  : null;
          int? subSelected;
          if (subDomain != null && f != null) {
            subSelected = setEquals(f, subDomain.catalogIds)
                ? null // "All <domain>"
                : (f.length == 1 ? f.first : null);
          }

          return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search subjects',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: notifier.setQuery,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterBar(
              mainLabel: mainLabel,
              subDomain: subDomain,
              subSelectedCatalogId: subSelected,
              onSubSelected: (catId) => notifier.setFilter(
                  catId == null ? subDomain!.catalogIds : {catId}),
            ),
          ),
          if (data.visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.note_outlined,
                message: 'No notes yet',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) return const AppRowSeparator();
                  final i = index ~/ 2;
                  final note = data.visible[i];
                  return NoteListTile(
                    note: note,
                    catalog: note.catalogId == null
                        ? null
                        : data.catalogsById[note.catalogId],
                    onTap: () {
                      final isWide = MediaQuery.of(context).size.width >=
                          kNotesWideBreakpoint;
                      if (isWide) {
                        ref.read(selectedNoteIdProvider.notifier).select(note.id);
                      } else {
                        context.push('/notes/${note.id}');
                      }
                    },
                  );
                },
                childCount: data.visible.length * 2 - 1,
              ),
            ),
          ];
        },
      ),
    );
  }
}

/// The filter controls that replace the horizontal chip row: a main button
/// (shows the active domain, opens the category drawer) and — only when the
/// active domain has more than one catalog — a compact sub-filter dropdown.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.mainLabel,
    this.subDomain,
    this.subSelectedCatalogId,
    this.onSubSelected,
  });

  final String mainLabel;
  final DomainGroup? subDomain;
  final int? subSelectedCatalogId;
  final void Function(int? catalogId)? onSubSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
      child: Row(
        children: [
          ActionChip(
            avatar: Icon(Icons.tune, size: 18, color: c.accent),
            label: Text(mainLabel),
            // Opens the AppScaffold drawer; this context is under the Scaffold
            // so Scaffold.of resolves it.
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          if (subDomain != null && onSubSelected != null) ...[
            const SizedBox(width: 8),
            _SubFilterButton(
              domain: subDomain!,
              selectedCatalogId: subSelectedCatalogId,
              onSelected: onSubSelected!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact dropdown for filtering within a domain. The first option is
/// `All [domain]` (the default); the rest are the domain's catalogs.
class _SubFilterButton extends StatelessWidget {
  const _SubFilterButton({
    required this.domain,
    required this.selectedCatalogId,
    required this.onSelected,
  });

  // Sentinel for the "All <domain>" option. PopupMenuButton treats a tapped
  // null-value item as a *cancel* (never firing onSelected), so the "All"
  // option must carry a non-null value. Real catalog ids are positive.
  static const int _allValue = -1;

  final DomainGroup domain;
  final int? selectedCatalogId;
  final void Function(int? catalogId) onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final allLabel = 'All ${domain.style.displayName}';
    String label = allLabel;
    if (selectedCatalogId != null) {
      for (final cat in domain.catalogs) {
        if (cat.id == selectedCatalogId) {
          label = CatalogPalette.styleFor(cat.name).displayName;
          break;
        }
      }
    }
    return PopupMenuButton<int>(
      initialValue: selectedCatalogId ?? _allValue,
      onSelected: (v) => onSelected(v == _allValue ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<int>(value: _allValue, child: Text(allLabel)),
        for (final cat in domain.catalogs)
          PopupMenuItem<int>(
            value: cat.id,
            child: Text(CatalogPalette.styleFor(cat.name).displayName),
          ),
      ],
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 8, 7),
        decoration: BoxDecoration(
          color: c.secondaryGroupedBackground,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          border: Border.all(color: c.separator),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: DesignTokens.rowSecondary
                    .copyWith(color: c.label, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: c.secondaryLabel),
          ],
        ),
      ),
    );
  }
}

/// Category panel (a left drawer) listing "All" + the note DOMAINS. Picking one
/// applies the filter and closes the panel. Replaces the old inline chips; the
/// per-catalog funnel sheet stays available from the nav bar.
class _FilterDrawer extends ConsumerWidget {
  const _FilterDrawer({required this.data});
  final NotesListData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final notifier = ref.read(notesListStateProvider.notifier);
    final usage = ref.watch(filterUsageProvider).value ?? const {};
    final groups =
        groupByDomain(data.catalogsById.values, data.countsByCatalog, usage);
    final f = data.catalogFilter;

    Widget dot(Color color) => Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));

    Widget tile({
      required Widget leading,
      required String title,
      required bool selected,
      required VoidCallback onTap,
    }) =>
        ListTile(
          leading: leading,
          title: Text(title),
          selected: selected,
          trailing: selected ? Icon(Icons.check, color: c.accent) : null,
          onTap: onTap,
        );

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
              child: Text('FILTER',
                  style: DesignTokens.caption
                      .copyWith(color: c.secondaryLabel, letterSpacing: 0.5)),
            ),
            tile(
              leading: dot(c.tertiaryLabel),
              title: 'All',
              selected: f == null || f.isEmpty,
              onTap: () {
                notifier.setFilter(null);
                Navigator.of(context).pop();
              },
            ),
            for (final g in groups)
              tile(
                leading: dot(g.style.color),
                title: g.style.displayName,
                selected: f != null && setEquals(f, g.catalogIds),
                onTap: () {
                  ref.read(filterUsageProvider.notifier).record(g.key);
                  notifier.setFilter(g.catalogIds);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
