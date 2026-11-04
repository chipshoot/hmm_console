import '../query/note_query.dart';
import '../query/note_results.dart';
import 'filter_usage.dart';
import 'notes_list_state.dart';

/// One slot in the notes chip bar.
sealed class ChipBarEntry {
  const ChipBarEntry();
}

/// A chip that sets [source] when tapped (or returns to All when [selected]).
class ChipBarSource extends ChipBarEntry {
  const ChipBarSource(this.source, {required this.selected, this.usageKey});

  final NoteSource source;
  final bool selected;

  /// Key to record in `filterUsageProvider` when picked; null when the chip
  /// is not counted (fixed chips, Today, smart filters, catalog domains).
  final String? usageKey;
}

/// The trailing ＋ chip that opens the drawer.
class ChipBarMore extends ChipBarEntry {
  const ChipBarMore();
}

class _Candidate {
  const _Candidate(this.source, this.key, this.count, this.label);
  final NoteSource source;
  final String key;
  final int count;
  final String label;
}

/// All · Pinned · Flagged · [current-source chip] · top 3 domains/tags · ＋.
///
/// The current-source chip appears only when [active] is not itself one of
/// the visible chips, so the active filter is always visible.
List<ChipBarEntry> chipBarEntries({
  required NoteSource active,
  required NotesListData data,
  required NoteCounts? counts,
  required Map<String, int> usage,
  required bool sidebarDocked,
  String Function(String domainKey)? domainLabelOf,
  String Function(int tagId)? tagLabelOf,
}) {
  final candidates = <_Candidate>[];

  final domainCounts = counts?.byDomain ?? data.countsByDomain;
  domainCounts.forEach((key, n) {
    if (n <= 0) return;
    candidates.add(
      _Candidate(
        DomainSource(key: key),
        key,
        n,
        domainLabelOf?.call(key) ?? key,
      ),
    );
  });

  final tagCounts = counts?.byTag ?? _tagCountsFrom(data);
  final live = data.liveTagNames;
  tagCounts.forEach((id, n) {
    if (n <= 0) return;
    if (live != null && !live.containsKey(id)) return;
    final key = usageKeyForTag(id);
    candidates.add(
      _Candidate(TagSource(tagId: id), key, n, tagLabelOf?.call(id) ?? key),
    );
  });

  candidates.sort((a, b) {
    final byUsage = (usage[b.key] ?? 0).compareTo(usage[a.key] ?? 0);
    if (byUsage != 0) return byUsage;
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.label.compareTo(b.label);
  });
  final top = candidates.take(3).toList();

  final fixed = <NoteSource>[
    const AllSource(),
    const PinnedSource(),
    const FlaggedSource(),
  ];
  final isVisible =
      fixed.contains(active) || top.any((c) => c.source == active);

  final entries = <ChipBarEntry>[
    for (final s in fixed) ChipBarSource(s, selected: s == active),
    if (!isVisible)
      ChipBarSource(active, selected: true, usageKey: _usageKeyOf(active)),
    for (final c in top)
      ChipBarSource(c.source, selected: c.source == active, usageKey: c.key),
    if (!sidebarDocked) const ChipBarMore(),
  ];
  return entries;
}

String? _usageKeyOf(NoteSource s) => switch (s) {
  DomainSource(:final key, catalogId: null) => key,
  TagSource(:final tagId) => usageKeyForTag(tagId),
  _ => null,
};

Map<int, int> _tagCountsFrom(NotesListData data) {
  final m = <int, int>{};
  for (final tags in data.tagsByNoteId.values) {
    for (final t in tags) {
      m[t.id] = (m[t.id] ?? 0) + 1;
    }
  }
  return m;
}
