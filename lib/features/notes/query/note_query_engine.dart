import 'dart:ui' show TextRange;

import '../../../core/notes/note_flag.dart';
import '../../../core/notes/note_state.dart';
import '../../../core/util/search_normalize.dart';
import '../../contacts/domain/contact_name.dart';
import '../../contacts/domain/pinyin_transcriber.dart';
import '../data/models/hmm_note.dart';
import '../states/notes_list_state.dart';
import 'note_grouping.dart';
import 'note_query.dart';
import 'note_results.dart';
import 'note_text_index.dart';

/// Turns a query plus the loaded notes into what the list shows. Pure: no
/// Riverpod, no I/O.
abstract interface class NoteQueryEngine {
  NoteResults evaluate(
    NoteQuery query,
    NotesListData corpus, {
    required DateTime now,
    required int firstDayOfWeek,
  });
}

class InMemoryNoteQueryEngine implements NoteQueryEngine {
  InMemoryNoteQueryEngine({
    required NoteTextIndexCache cache,
    required NoteTextKey Function(HmmNote) keyOf,
    required String Function(HmmNote) titleOf,
    required PinyinTranscriber pinyin,
  }) : _cache = cache,
       _keyOf = keyOf,
       _titleOf = titleOf,
       _pinyin = pinyin;

  final NoteTextIndexCache _cache;
  final NoteTextKey Function(HmmNote) _keyOf;
  final String Function(HmmNote) _titleOf;
  final PinyinTranscriber _pinyin;

  @override
  NoteResults evaluate(
    NoteQuery query,
    NotesListData corpus, {
    required DateTime now,
    required int firstDayOfWeek,
  }) {
    final words = normalizeForSearch(
      query.text,
    ).split(' ').where((w) => w.isNotEmpty).toList();
    final searching = words.isNotEmpty;
    final useSource = !(searching && query.scope == NoteScope.all);

    // Only a parent token needs it; built on first use.
    late final uuidById = {for (final n in corpus.all) n.id: n.uuid};
    final today = _day(now.toLocal());
    final titles = <int, String>{}; // each title computed once per evaluate
    String titleOf(HmmNote n) => titles[n.id] ??= _titleOf(n);

    final hits = <NoteHit>[];
    for (final n in corpus.all) {
      final state = corpus.stateOf(n);
      if (useSource && !_inSource(query.source, n, state, corpus, today)) {
        continue;
      }
      if (!query.tokens.every(
        (t) => _passesToken(t, n, state, corpus, uuidById, today),
      )) {
        continue;
      }
      final idx = searching ? _cache.lookup(_keyOf(n)) : null;
      if (searching && !_matchesText(words, idx, n, corpus, titleOf(n))) {
        continue;
      }
      final title = titleOf(n);
      hits.add(
        searching
            ? NoteHit(
                note: n,
                title: title,
                state: state,
                titleMatches: _ranges(
                  words,
                  idx?.titleFolded ?? foldForMatch(title),
                ),
                previewMatches: _ranges(
                  words,
                  idx?.bodyFolded ?? '',
                  limit: _previewChars,
                ),
              )
            : NoteHit(note: n, title: title, state: state),
      );
    }

    final sorted = _sort(hits, query.sort);
    return NoteResults(
      groups: _group(sorted, query, now, firstDayOfWeek),
      counts: _counts(corpus),
      total: sorted.length,
    );
  }

  NotesListData? _countedCorpus;
  NoteCounts? _lastCounts;

  /// [_countLibrary], reused while the corpus parts it reads are the same
  /// objects (query edits only change `query`).
  NoteCounts _counts(NotesListData c) {
    final last = _countedCorpus;
    final counts = _lastCounts;
    if (counts != null &&
        last != null &&
        identical(last.all, c.all) &&
        identical(last.statesByUuid, c.statesByUuid) &&
        identical(last.tagsByNoteId, c.tagsByNoteId) &&
        identical(last.catalogDomainById, c.catalogDomainById) &&
        identical(last.anchorDomainById, c.anchorDomainById) &&
        identical(last.targetsById, c.targetsById)) {
      return counts;
    }
    _countedCorpus = c;
    return _lastCounts = _countLibrary(c);
  }

  /// Counts describe the library, not the view: every live note, ignoring
  /// source, tokens and text.
  NoteCounts _countLibrary(NotesListData c) {
    var pinned = 0;
    final byDomain = <String, int>{};
    final byTag = <int, int>{};
    final byFlag = <int, int>{};
    for (final n in c.all) {
      final state = c.stateOf(n);
      if (state.isPinned) pinned++;
      final domain = c.effectiveDomain(n);
      if (domain != null) byDomain[domain] = (byDomain[domain] ?? 0) + 1;
      for (final t in c.tagsByNoteId[n.id] ?? const []) {
        byTag[t.id] = (byTag[t.id] ?? 0) + 1;
      }
      final flag = state.flag;
      if (flag != null) byFlag[flag.index] = (byFlag[flag.index] ?? 0) + 1;
    }
    return NoteCounts(
      all: c.all.length,
      pinned: pinned,
      byDomain: byDomain,
      byTag: byTag,
      byFlag: byFlag,
    );
  }

  /// Pinned section first (unless the source is Pinned), then the sort's own
  /// groups. Hits keep the sorted order; empty groups are omitted.
  List<NoteGroup> _group(
    List<NoteHit> sorted,
    NoteQuery query,
    DateTime now,
    int firstDayOfWeek,
  ) {
    final pinned = query.source is PinnedSource
        ? const <NoteHit>[]
        : [
            for (final h in sorted)
              if (h.state.isPinned) h,
          ];
    final rest = query.source is PinnedSource
        ? sorted
        : [
            for (final h in sorted)
              if (!h.state.isPinned) h,
          ];

    final dates = DateGrouper(now: now, firstDayOfWeek: firstDayOfWeek);
    NoteGroupKey keyOf(NoteHit h) => switch (query.sort) {
      NoteSort.dateNewest || NoteSort.dateOldest || NoteSort.lastModified =>
        dates.groupOf(groupingDateOf(h.note, query.sort)),
      NoteSort.subjectAZ => letterGroupFor(h.title, _pinyin),
      NoteSort.flagColor => flagGroupFor(h.state.flagColor),
    };

    final byKey = <NoteGroupKey, List<NoteHit>>{};
    for (final h in rest) {
      (byKey[keyOf(h)] ??= []).add(h);
    }
    var groups = [
      for (final e in byKey.entries) NoteGroup(key: e.key, hits: e.value),
    ];
    switch (query.sort) {
      case NoteSort.subjectAZ:
        // '#' last; letters alphabetical.
        int rank(NoteGroup g) {
          final l = (g.key as LetterGroup).letter;
          return l == '#' ? 1 << 20 : l.codeUnitAt(0);
        }

        groups = [...groups]..sort((a, b) => rank(a).compareTo(rank(b)));
      case NoteSort.flagColor:
        // Red ... grey in enum order, Unflagged last.
        int rank(NoteGroup g) =>
            (g.key as FlagGroup).color?.index ?? NoteFlagColor.values.length;
        groups = [...groups]..sort((a, b) => rank(a).compareTo(rank(b)));
      case NoteSort.dateNewest || NoteSort.dateOldest || NoteSort.lastModified:
        break; // already in first-appearance (= sort) order
    }
    return [
      if (pinned.isNotEmpty) NoteGroup(key: const PinnedGroup(), hits: pinned),
      ...groups,
    ];
  }

  /// How much of the body text [NoteHit.previewMatches] covers.
  static const _previewChars = 400;

  /// Every direct occurrence of every word in [folded] (same length as the
  /// displayed text) that ends within [limit] characters, overlapping ranges
  /// merged, in order.
  static List<TextRange> _ranges(
    List<String> words,
    String folded, {
    int? limit,
  }) {
    if (folded.isEmpty) return const [];
    final end = limit == null || limit > folded.length ? folded.length : limit;
    final raw = <TextRange>[];
    for (final w in words) {
      var from = 0;
      while (true) {
        final i = folded.indexOf(w, from);
        if (i < 0 || i + w.length > end) break;
        raw.add(TextRange(start: i, end: i + w.length));
        from = i + w.length;
      }
    }
    raw.sort((a, b) => a.start.compareTo(b.start));
    final out = <TextRange>[];
    for (final r in raw) {
      if (out.isNotEmpty && r.start <= out.last.end) {
        if (r.end > out.last.end) {
          out[out.length - 1] = TextRange(start: out.last.start, end: r.end);
        }
      } else {
        out.add(r);
      }
    }
    return out;
  }

  static DateTime _day(DateTime local) =>
      DateTime(local.year, local.month, local.day);

  bool _inSource(
    NoteSource s,
    HmmNote n,
    NoteState state,
    NotesListData c,
    DateTime today,
  ) {
    switch (s) {
      case AllSource():
        return true;
      case PinnedSource():
        return state.isPinned;
      case FlaggedSource(:final color):
        return color == null
            ? state.flagColor != null
            : state.flag != null &&
                  state.flag == NoteFlagColor.fromStored(color);
      case TodaySource():
        return _day(n.effectiveNoteDate.toLocal()) == today;
      case DomainSource(:final key, :final catalogId):
        if (catalogId == null) return c.effectiveDomain(n) == key;
        final parent = c.parentDomainOf(n);
        if (parent != null && parent != c.ownDomainOf(n)) return parent == key;
        return n.catalogId == catalogId;
      case TagSource(:final tagId):
        return _hasTag(c, n, tagId);
      case SmartSource() || RecentlyDeletedSource() || UnknownSource():
        return false;
    }
  }

  static bool _hasTag(NotesListData c, HmmNote n, int tagId) =>
      c.tagsByNoteId[n.id]?.any((t) => t.id == tagId) ?? false;

  bool _passesToken(
    NoteToken t,
    HmmNote n,
    NoteState state,
    NotesListData c,
    Map<int, String> uuidById,
    DateTime today,
  ) {
    switch (t) {
      case TagToken(:final tagId):
        return _hasTag(c, n, tagId);
      case FlagToken(:final color):
        return state.flag != null &&
            state.flag == NoteFlagColor.fromStored(color);
      case DomainToken(:final key):
        return c.effectiveDomain(n) == key;
      case CatalogToken(:final catalogId):
        return n.catalogId == catalogId;
      case ParentToken(:final noteUuid):
        final p = n.parentNoteId;
        return p != null && uuidById[p] == noteUuid;
      case HasPhotoToken():
        final a = n.effectiveAttachments;
        return a.primaryImage != null || a.images.isNotEmpty;
      case HasPlaceToken():
        return n.location != null;
      case HasAttachmentToken():
        final a = n.effectiveAttachments;
        return a.primaryImage != null ||
            a.images.isNotEmpty ||
            a.files.isNotEmpty;
      case DateRangeToken(:final from, :final to):
        final d = _day(n.effectiveNoteDate.toLocal());
        if (from != null && d.isBefore(_day(from.toLocal()))) return false;
        if (to != null && d.isAfter(_day(to.toLocal()))) return false;
        return true;
      case RelativeDateToken(:final range):
        final back = switch (range) {
          RelativeRange.last7d => 6,
          RelativeRange.last30d => 29,
          RelativeRange.last90d => 89,
        };
        final start = DateTime(today.year, today.month, today.day - back);
        return !n.effectiveNoteDate.toLocal().isBefore(start);
      case PinnedToken():
        return state.isPinned;
      case UnknownToken():
        return true;
    }
  }

  bool _matchesText(
    List<String> words,
    NoteTextIndex? idx,
    HmmNote n,
    NotesListData c,
    String title,
  ) {
    if (idx == null) {
      // No index yet: title and parent title only.
      final t = normalizeForSearch(title);
      final p = normalizeForSearch(c.contextSubjectOf(n) ?? '');
      return words.every((w) => t.contains(w) || p.contains(w));
    }
    return words.every(
      (w) =>
          idx.titleFolded.contains(w) ||
          idx.bodyFolded.contains(w) ||
          idx.parentTitleFolded.contains(w) ||
          idx.tagNamesFolded.any((t) => t.contains(w)) ||
          idx.pinyinFull.contains(w) ||
          idx.pinyinInitials.contains(w),
    );
  }

  List<NoteHit> _sort(List<NoteHit> hits, NoteSort sort) {
    int byId(NoteHit a, NoteHit b) => b.note.id.compareTo(a.note.id);
    DateTime date(NoteHit h) => h.note.effectiveNoteDate;
    int newest(NoteHit a, NoteHit b) => date(b).compareTo(date(a));

    final int Function(NoteHit, NoteHit) primary;
    switch (sort) {
      case NoteSort.dateNewest:
        primary = newest;
      case NoteSort.dateOldest:
        primary = (a, b) => date(a).compareTo(date(b));
      case NoteSort.lastModified:
        DateTime mod(NoteHit h) => h.note.lastModifiedDate ?? date(h);
        primary = (a, b) => mod(b).compareTo(mod(a));
      case NoteSort.subjectAZ:
        final keys = {for (final h in hits) h.note.id: _subjectKey(h.title)};
        primary = (a, b) => keys[a.note.id]!.compareTo(keys[b.note.id]!);
      case NoteSort.flagColor:
        // Unflagged sorts after every colour.
        int rank(NoteHit h) =>
            h.state.flag?.index ?? NoteFlagColor.values.length;
        primary = (a, b) {
          final r = rank(a).compareTo(rank(b));
          return r != 0 ? r : newest(a, b);
        };
    }
    return [...hits]..sort((a, b) {
      final r = primary(a, b);
      return r != 0 ? r : byId(a, b);
    });
  }

  /// Folded title; a Han first character sorts by its pinyin.
  String _subjectKey(String title) {
    if (title.isEmpty) return '';
    final first = String.fromCharCode(title.runes.first);
    if (ContactName.hasChinese(first)) {
      final syl = _pinyin.given(first);
      if (syl.isNotEmpty) {
        return syl.join() + foldForMatch(title.substring(first.length));
      }
    }
    return foldForMatch(title);
  }
}
