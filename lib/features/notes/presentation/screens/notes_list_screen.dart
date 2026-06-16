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
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notesListStateProvider);
    final notifier = ref.read(notesListStateProvider.notifier);

    return AppScaffold(
      title: 'Notes',
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
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load notes: $e')),
            data: (data) {
              return Column(
                children: [
                  Padding(
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
                  _Chips(data: data),
                  Expanded(
                    child: data.visible.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.note_outlined,
                            message: 'No notes yet',
                          )
                        : ListView.builder(
                            itemCount: data.visible.length,
                            itemBuilder: (context, i) {
                              final note = data.visible[i];
                              return NoteListTile(
                                note: note,
                                catalog: note.catalogId == null
                                    ? null
                                    : data.catalogsById[note.catalogId],
                                onTap: () {
                                  final isWide =
                                      MediaQuery.of(context).size.width >=
                                          kNotesWideBreakpoint;
                                  if (isWide) {
                                    ref
                                        .read(selectedNoteIdProvider.notifier)
                                        .select(note.id);
                                  } else {
                                    context.push('/notes/${note.id}');
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Inline quick filters: "All" + the most-used DOMAIN chips (ordered by tracked
/// usage, then note count). Tapping a domain filters to all its catalogs and
/// records the tap so the order adapts. The full per-catalog list lives in the
/// grouped filter sheet (funnel).
class _Chips extends ConsumerWidget {
  const _Chips({required this.data});
  final NotesListData data;

  static const int _maxInline = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(notesListStateProvider.notifier);
    final usage = ref.watch(filterUsageProvider).value ?? const {};
    final groups =
        groupByDomain(data.catalogsById.values, data.countsByCatalog, usage)
            .take(_maxInline)
            .toList();

    bool isSelected(DomainGroup g) {
      final f = data.catalogFilter;
      return f != null && f.isNotEmpty && setEquals(f, g.catalogIds);
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('All'),
              selected: data.catalogFilter == null,
              onSelected: (_) => notifier.setFilter(null),
            ),
          ),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: CircleAvatar(radius: 5, backgroundColor: g.style.color),
                label: Text(g.style.displayName),
                selected: isSelected(g),
                onSelected: (_) {
                  ref.read(filterUsageProvider.notifier).record(g.key);
                  notifier.setFilter(g.catalogIds);
                },
              ),
            ),
        ],
      ),
    );
  }
}
