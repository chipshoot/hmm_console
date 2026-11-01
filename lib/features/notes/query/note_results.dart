import 'dart:ui' show TextRange;

import '../../../core/notes/note_flag.dart';
import '../../../core/notes/note_state.dart';
import '../data/models/hmm_note.dart';

/// One note that passed the query, with what a row needs to show it.
class NoteHit {
  const NoteHit({
    required this.note,
    required this.title,
    required this.state,
    this.titleMatches = const [],
    this.previewMatches = const [],
  });

  final HmmNote note;
  final String title;
  final NoteState state;
  final List<TextRange> titleMatches;
  final List<TextRange> previewMatches;
}

sealed class NoteGroupKey {
  const NoteGroupKey();
}

class PinnedGroup extends NoteGroupKey {
  const PinnedGroup();
  @override
  bool operator ==(Object other) => other is PinnedGroup;
  @override
  int get hashCode => 'pinned'.hashCode;
}

class TodayGroup extends NoteGroupKey {
  const TodayGroup();
  @override
  bool operator ==(Object other) => other is TodayGroup;
  @override
  int get hashCode => 'today'.hashCode;
}

class YesterdayGroup extends NoteGroupKey {
  const YesterdayGroup();
  @override
  bool operator ==(Object other) => other is YesterdayGroup;
  @override
  int get hashCode => 'yesterday'.hashCode;
}

class ThisWeekGroup extends NoteGroupKey {
  const ThisWeekGroup();
  @override
  bool operator ==(Object other) => other is ThisWeekGroup;
  @override
  int get hashCode => 'thisWeek'.hashCode;
}

class ThisMonthGroup extends NoteGroupKey {
  const ThisMonthGroup();
  @override
  bool operator ==(Object other) => other is ThisMonthGroup;
  @override
  int get hashCode => 'thisMonth'.hashCode;
}

class MonthGroup extends NoteGroupKey {
  const MonthGroup(this.year, this.month);
  final int year;
  final int month;
  @override
  bool operator ==(Object other) =>
      other is MonthGroup && other.year == year && other.month == month;
  @override
  int get hashCode => Object.hash('month', year, month);
}

class LetterGroup extends NoteGroupKey {
  const LetterGroup(this.letter);
  final String letter;
  @override
  bool operator ==(Object other) =>
      other is LetterGroup && other.letter == letter;
  @override
  int get hashCode => Object.hash('letter', letter);
}

class FlagGroup extends NoteGroupKey {
  const FlagGroup(this.color);
  final NoteFlagColor? color;
  @override
  bool operator ==(Object other) => other is FlagGroup && other.color == color;
  @override
  int get hashCode => Object.hash('flag', color);
}

class FlatGroup extends NoteGroupKey {
  const FlatGroup();
  @override
  bool operator ==(Object other) => other is FlatGroup;
  @override
  int get hashCode => 'flat'.hashCode;
}

class NoteGroup {
  const NoteGroup({required this.key, required this.hits});
  final NoteGroupKey key;
  final List<NoteHit> hits;
}

class NoteCounts {
  const NoteCounts({
    required this.all,
    required this.pinned,
    required this.byDomain,
    required this.byTag,
    required this.byFlag,
  });

  const NoteCounts.zero()
    : all = 0,
      pinned = 0,
      byDomain = const {},
      byTag = const {},
      byFlag = const {};

  final int all;
  final int pinned;
  final Map<String, int> byDomain;
  final Map<int, int> byTag;

  /// Keyed by display colour index; an unknown stored value counts as grey.
  final Map<int, int> byFlag;
}

class NoteResults {
  const NoteResults({
    required this.groups,
    required this.counts,
    required this.total,
  });

  final List<NoteGroup> groups;
  final NoteCounts counts;
  final int total;

  bool get isEmpty => total == 0;
}
