import '../../../core/notes/note_flag.dart';
import '../../../core/notes/note_state.dart';
import '../../../core/util/search_normalize.dart';
import '../../contacts/domain/contact_name.dart';
import '../../contacts/domain/pinyin_transcriber.dart';
import '../data/models/hmm_note.dart';
import '../states/notes_list_state.dart';
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

    final uuidById = {for (final n in corpus.all) n.id: n.uuid};
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
      if (searching && !_matchesText(words, n, corpus, titleOf(n))) continue;
      hits.add(NoteHit(note: n, title: titleOf(n), state: state));
    }

    final sorted = _sort(hits, query.sort);
    return NoteResults(
      groups: [NoteGroup(key: const FlatGroup(), hits: sorted)],
      counts: const NoteCounts.zero(),
      total: sorted.length,
    );
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
    HmmNote n,
    NotesListData c,
    String title,
  ) {
    final idx = _cache.lookup(_keyOf(n));
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
