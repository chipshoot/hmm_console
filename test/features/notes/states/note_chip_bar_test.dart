import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_results.dart';
import 'package:hmm_console/features/notes/states/filter_usage.dart';
import 'package:hmm_console/features/notes/states/note_chip_bar.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

NoteCounts _counts({
  Map<String, int> byDomain = const {},
  Map<int, int> byTag = const {},
}) => NoteCounts(
  all: 10,
  pinned: 1,
  byDomain: byDomain,
  byTag: byTag,
  byFlag: const {},
);

NotesListData _data({Map<int, String>? tags}) =>
    NotesListData(all: const [], catalogsById: const {}, liveTagNames: tags);

List<ChipBarEntry> _entries({
  NoteSource active = const AllSource(),
  NotesListData? data,
  NoteCounts? counts,
  Map<String, int> usage = const {},
  bool docked = false,
}) => chipBarEntries(
  active: active,
  data: data ?? _data(),
  counts: counts,
  usage: usage,
  sidebarDocked: docked,
);

List<ChipBarSource> _sources(List<ChipBarEntry> e) =>
    e.whereType<ChipBarSource>().toList();

void main() {
  test('usageKeyForTag', () => expect(usageKeyForTag(7), 'tag:7'));

  test('fixed chips come first', () {
    final s = _sources(_entries());
    expect(s.map((e) => e.source).toList(), [
      const AllSource(),
      const PinnedSource(),
      const FlaggedSource(),
    ]);
  });

  test('top 3 by usage, then count, then label', () {
    final e = _entries(
      data: _data(tags: {2: 'Two', 3: 'Three'}),
      counts: _counts(
        byDomain: {'A': 1, 'B': 9, 'C': 4, 'D': 4},
        byTag: {2: 1, 3: 1},
      ),
      usage: {'A': 5, 'tag:2': 5, 'B': 1},
    );
    final tail = _sources(e).skip(3).map((c) => c.source).toList();
    // A (usage 5, count 1) vs tag:2 (usage 5, count 1): label tie -> 'A' < 'tag:2'.
    expect(tail.length, 3);
    expect(tail[0], const DomainSource(key: 'A'));
    expect(tail[1], const TagSource(tagId: 2));
    expect(tail[2], const DomainSource(key: 'B'));
  });

  test('usage ties fall back to count then label', () {
    final e = _entries(
      counts: _counts(byDomain: {'A': 1, 'B': 9, 'C': 4, 'D': 4, 'E': 4}),
    );
    final tail = _sources(e).skip(3).map((c) => c.source).toList();
    expect(tail, [
      const DomainSource(key: 'B'),
      const DomainSource(key: 'C'),
      const DomainSource(key: 'D'),
    ]);
  });

  test('a deleted tag in usage never appears', () {
    final e = _entries(
      data: _data(tags: {1: 'Live'}),
      counts: _counts(byTag: {1: 2, 99: 3}),
      usage: {'tag:99': 50},
    );
    expect(
      _sources(e).map((c) => c.source),
      isNot(contains(const TagSource(tagId: 99))),
    );
    expect(
      _sources(e).map((c) => c.source),
      contains(const TagSource(tagId: 1)),
    );
  });

  test('domains with no notes are not candidates', () {
    final e = _entries(
      counts: _counts(byDomain: {'A': 0, 'B': 2}),
      usage: {'A': 9},
    );
    final tail = _sources(e).skip(3).map((c) => c.source).toList();
    expect(tail, [const DomainSource(key: 'B')]);
  });

  for (final active in <NoteSource>[
    const TagSource(tagId: 5),
    const TodaySource(),
    const FlaggedSource(color: 2),
    const SmartSource(savedId: 'builtin.withPhotos'),
    const DomainSource(key: 'A', catalogId: 3),
  ]) {
    test('a non-top active source gets a selected chip: $active', () {
      final e = _entries(
        active: active,
        data: _data(tags: {5: 'Five'}),
        counts: _counts(byDomain: {'A': 1}, byTag: {5: 1}),
        usage: {'A': 9},
      );
      // Tag 5 is a top-3 candidate here, so make room for the others only.
      final selected = _sources(e).where((c) => c.selected).toList();
      expect(selected, hasLength(1));
      expect(selected.single.source, active);
      if (active is! TagSource) {
        expect(_sources(e)[3].source, active);
        expect(_sources(e)[3].usageKey, isNull);
      }
    });
  }

  test('a non-top tag is inserted right after Flagged', () {
    final e = _entries(
      active: const TagSource(tagId: 9),
      data: _data(tags: {for (var i = 1; i <= 9; i++) i: 'T$i'}),
      counts: _counts(byTag: {for (var i = 1; i <= 9; i++) i: 10 - i}),
    );
    final s = _sources(e);
    expect(s[3].source, const TagSource(tagId: 9));
    expect(s[3].selected, isTrue);
    expect(s[3].usageKey, 'tag:9');
    expect(s.where((c) => c.source == const TagSource(tagId: 9)), hasLength(1));
  });

  test('AllSource adds no extra chip', () {
    final s = _sources(_entries());
    expect(s, hasLength(3));
    expect(s.where((c) => c.selected).map((c) => c.source), [
      const AllSource(),
    ]);
  });

  test('the active top-3 domain is selected in place, not duplicated', () {
    final e = _entries(
      active: const DomainSource(key: 'A'),
      counts: _counts(byDomain: {'A': 3, 'B': 2}),
    );
    final s = _sources(e);
    expect(s.map((c) => c.source), [
      const AllSource(),
      const PinnedSource(),
      const FlaggedSource(),
      const DomainSource(key: 'A'),
      const DomainSource(key: 'B'),
    ]);
    expect(s[3].selected, isTrue);
    expect(s[3].usageKey, 'A');
    expect(s[4].selected, isFalse);
  });

  test('＋ is last, and absent when docked', () {
    expect(_entries().last, isA<ChipBarMore>());
    expect(_entries(docked: true).whereType<ChipBarMore>(), isEmpty);
  });

  test('falls back to data when counts is null', () {
    final e = chipBarEntries(
      active: const AllSource(),
      data: NotesListData(
        all: const [],
        catalogsById: const {},
        tagsByNoteId: const {
          1: [(id: 4, name: 'x')],
          2: [(id: 4, name: 'x')],
        },
      ),
      counts: null,
      usage: const {},
      sidebarDocked: true,
    );
    expect(_sources(e).last.source, const TagSource(tagId: 4));
  });
}
