import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../query/built_in_smart_filters.dart';
import '../../query/note_query.dart';
import '../../query/note_token_labels.dart';
import '../../query/smart_query.dart';
import '../../states/filter_usage.dart';
import '../../states/note_chip_bar.dart';
import '../../states/notes_list_state.dart';
import '../../states/notes_results_provider.dart';
import '../../states/saved_searches_provider.dart';
import '../catalog_labels.dart';

/// The quick-filter row under the search box: All, Pinned, Flagged, the
/// active filter when it has no chip of its own, the most-used domains and
/// tags, and a ＋ that opens the side panel. Tapping the selected chip goes
/// back to All.
class NoteChipBar extends ConsumerWidget {
  const NoteChipBar({
    super.key,
    required this.data,
    required this.sidebarDocked,
  });

  final NotesListData data;
  final bool sidebarDocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final source = data.query.source;
    final smart = ref.watch(notesSmartFiltersProvider);
    final entries = chipBarEntries(
      active: source,
      data: data,
      counts: ref.watch(notesResultsProvider).value?.counts,
      usage: ref.watch(filterUsageProvider).value ?? const {},
      sidebarDocked: sidebarDocked,
      domainLabelOf: (key) => domainLabel(key, l),
      tagLabelOf: (id) {
        final name = tagNameOf(data, id);
        return name == null ? '$id' : l.notesTokenTag(name);
      },
    );

    String labelOf(NoteSource s) => switch (s) {
      AllSource() => l.notesAll,
      PinnedSource() => l.notesTokenPinned,
      FlaggedSource(:final color) =>
        color == null ? l.notesSidebarFlagged : flagName(color, l),
      TodaySource() => l.notesGroupToday,
      DomainSource(:final key, :final catalogId) => switch (catalogId == null
          ? null
          : data.catalogsById[catalogId]) {
        final cat? => catalogLabel(cat.name, l),
        null => domainLabel(key, l),
      },
      TagSource(:final tagId) => switch (tagNameOf(data, tagId)) {
        final name? => l.notesTokenTag(name),
        null => l.notesFiltered,
      },
      SmartSource() => switch (savedSearchFor(s, smart)) {
        final found? => smartFilterDisplayName(found, l),
        null => l.notesFiltered,
      },
      _ => l.notesFiltered,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
      child: Row(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: switch (e) {
                ChipBarSource() => ChoiceChip(
                  label: Text(labelOf(e.source)),
                  selected: e.selected,
                  onSelected: (_) {
                    final notifier = ref.read(notesListStateProvider.notifier);
                    if (e.selected) {
                      notifier.setSource(const AllSource());
                      return;
                    }
                    final key = e.usageKey;
                    if (key != null) {
                      ref.read(filterUsageProvider.notifier).record(key);
                    }
                    notifier.setSource(e.source);
                  },
                ),
                ChipBarMore() => ActionChip(
                  label: const Icon(Icons.add, size: 18),
                  tooltip: l.notesChipMoreTooltip,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              },
            ),
        ],
      ),
    );
  }
}
