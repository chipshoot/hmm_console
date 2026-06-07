import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notes/catalog_palette.dart';
import '../../states/notes_list_state.dart';
import '../widgets/catalog_filter_sheet.dart';
import '../widgets/note_list_tile.dart';
import '../widgets/sort_sheet.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notesListStateProvider);
    final notifier = ref.read(notesListStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
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
                ? () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => CatalogFilterSheet(
                        catalogs: async.value!.catalogsById.values.toList(),
                        counts: async.value!.countsByCatalog,
                        selected: async.value!.catalogFilter,
                        onApply: notifier.setFilter,
                      ),
                    )
                : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/notes/new'),
        child: const Icon(Icons.add),
      ),
      body: async.when(
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
              _Chips(data: data, onSelect: notifier.setFilter),
              Expanded(
                child: data.visible.isEmpty
                    ? const Center(child: Text('No notes'))
                    : ListView.builder(
                        itemCount: data.visible.length,
                        itemBuilder: (context, i) {
                          final note = data.visible[i];
                          return NoteListTile(
                            note: note,
                            catalog: note.catalogId == null
                                ? null
                                : data.catalogsById[note.catalogId],
                            onTap: () => context.push('/notes/${note.id}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.data, required this.onSelect});
  final NotesListData data;
  final ValueChanged<Set<int>?> onSelect;

  @override
  Widget build(BuildContext context) {
    final catalogs = data.catalogsById.values.toList();
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
              onSelected: (_) => onSelect(null),
            ),
          ),
          for (final c in catalogs)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: CircleAvatar(
                    radius: 5,
                    backgroundColor: CatalogPalette.styleFor(c.name).color),
                label: Text(CatalogPalette.styleFor(c.name).displayName),
                selected: data.catalogFilter?.contains(c.id) ?? false,
                onSelected: (_) => onSelect({c.id}),
              ),
            ),
        ],
      ),
    );
  }
}
