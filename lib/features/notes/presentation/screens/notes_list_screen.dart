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
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_row_separator.dart';
import '../../../../core/widgets/app_scaffold.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  /// Label for the filter button: the active domain's name, or "All".
  String _activeFilterLabel(NotesListData data, Map<String, int> usage) {
    final f = data.catalogFilter;
    if (f == null || f.isEmpty) return 'All';
    final groups =
        groupByDomain(data.catalogsById.values, data.countsByCatalog, usage);
    for (final g in groups) {
      if (setEquals(f, g.catalogIds)) return g.style.displayName;
    }
    return 'Filtered';
  }

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
        data: (data) => [
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
            child: _FilterBar(label: _activeFilterLabel(data, usage)),
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
        ],
      ),
    );
  }
}

/// The single filter control that replaces the horizontal chip row. Shows the
/// active filter and opens the category drawer on tap (no scrolling pills).
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
        child: ActionChip(
          avatar: Icon(Icons.tune, size: 18, color: c.accent),
          label: Text(label),
          // Opens the AppScaffold drawer; the Builder context is under the
          // Scaffold so Scaffold.of resolves it.
          onPressed: () => Scaffold.of(context).openDrawer(),
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
