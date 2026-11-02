import 'dart:ui' show TextRange;

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_flag.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_query_engine.dart';
import 'package:hmm_console/features/notes/query/note_results.dart';
import 'package:hmm_console/features/notes/query/note_text_index.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _Fake implements PinyinTranscriber {
  @override
  List<String> given(String text) => [
    for (final r in text.runes)
      const {'张': 'zhang', '三': 'san'}[String.fromCharCode(r)] ??
          String.fromCharCode(r),
  ];
  @override
  List<String> family(String text) => given(text);
}

const _general = 1;
const _auto = 2;
const carId = 100;
const pinnedCarNoteId = 2;

// now = Wed 2026-11-04 10:00 local; week starts Monday.
final now = DateTime(2026, 11, 4, 10);

HmmNote _n(
  int id,
  String subject, {
  int catalog = _general,
  int? parent,
  DateTime? date,
  DateTime? modified,
  String? content,
}) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
  authorId: 1,
  catalogId: catalog,
  parentNoteId: parent,
  createDate: date ?? DateTime(2026, 1, 1),
  lastModifiedDate: modified,
  content: content,
);

final _notes = <HmmNote>[
  _n(carId, 'Honda', catalog: _auto, date: DateTime(2026, 1, 1)),
  _n(pinnedCarNoteId, 'Oil', parent: carId, date: DateTime(2026, 11, 3, 12)),
  _n(3, 'Today note', date: DateTime(2026, 11, 4, 8)),
  _n(4, 'Old pinned', date: DateTime(2026, 8, 1)),
  _n(5, 'Apple', date: DateTime(2026, 11, 2), modified: DateTime(2026, 11, 4)),
  _n(6, '7 days', date: DateTime(2026, 10, 20)),
  _n(7, 'Crème brûlée', date: DateTime(2026, 10, 21), content: 'BRULEE BRULEE'),
  _n(8, '张三', date: DateTime(2026, 10, 22)),
];

NoteState _st(HmmNote n, {bool pinned = false, int? flag}) => NoteState(
  noteUuid: n.uuid,
  isPinned: pinned,
  flagColor: flag,
  lastModifiedDate: DateTime(2026),
);

HmmNote _byId(int id) => _notes.firstWhere((n) => n.id == id);

NotesListData _corpus() => NotesListData(
  all: _notes,
  catalogsById: const {},
  catalogDomainById: const {_general: 'General', _auto: 'AutomobileMan'},
  targetsById: const {carId: (domain: 'AutomobileMan', subject: 'Honda')},
  tagsByNoteId: const {
    3: [(id: 7, name: 'Garage')],
    5: [(id: 7, name: 'Garage')],
  },
  statesByUuid: {
    'u$pinnedCarNoteId': _st(_byId(pinnedCarNoteId), pinned: true, flag: 2),
    'u4': _st(_byId(4), pinned: true),
    'u3': _st(_byId(3), flag: 0),
    'u5': _st(_byId(5), flag: 99),
  },
);

NoteTextKey _keyOf(HmmNote n) =>
    (noteId: n.id, version: 'v', locale: 'en', parentTitle: '', tags: '');

NoteResults run({
  NoteSource source = const AllSource(),
  String text = '',
  NoteSort sort = NoteSort.dateNewest,
  List<NoteToken> tokens = const [],
}) {
  final cache = NoteTextIndexCache();
  final c = _corpus();
  for (final n in _notes) {
    cache.store(
      _keyOf(n),
      buildNoteTextIndex(
        title: n.subject,
        body: n.content ?? '',
        parentTitle: c.contextSubjectOf(n),
        pinyin: _Fake(),
      ),
    );
  }
  return InMemoryNoteQueryEngine(
    cache: cache,
    keyOf: _keyOf,
    titleOf: (n) => n.subject,
    pinyin: _Fake(),
  ).evaluate(
    NoteQuery(source: source, text: text, sort: sort, tokens: tokens),
    c,
    now: now,
    firstDayOfWeek: DateTime.monday,
  );
}

List<int> idsOf(NoteGroup g) => [for (final h in g.hits) h.note.id];

void main() {
  test('pinned notes lead every sort and are not repeated', () {
    for (final s in NoteSort.values) {
      final r = run(sort: s);
      expect(r.groups.first.key, const PinnedGroup(), reason: '$s');
      expect(idsOf(r.groups.first).toSet(), {pinnedCarNoteId, 4});
      final rest = r.groups.skip(1).expand(idsOf);
      expect(rest, isNot(contains(4)));
      expect(rest, isNot(contains(pinnedCarNoteId)));
      expect(r.total, _notes.length);
    }
  });

  test('pinned hits keep the active sort order', () {
    final r = run();
    expect(idsOf(r.groups.first), [pinnedCarNoteId, 4]); // newest first
    expect(idsOf(run(sort: NoteSort.dateOldest).groups.first), [
      4,
      pinnedCarNoteId,
    ]);
  });

  test('a pinned note outside the view is not in its Pinned section', () {
    final r = run(source: const DomainSource(key: 'General'));
    final all = r.groups.expand((g) => g.hits).map((h) => h.note.id);
    expect(all, isNot(contains(pinnedCarNoteId)));
    expect(idsOf(r.groups.first), [4]);
    expect(r.groups.first.key, const PinnedGroup());
  });

  test('Pinned source has no separate Pinned section', () {
    final r = run(source: const PinnedSource());
    expect(r.groups.map((g) => g.key), isNot(contains(const PinnedGroup())));
    expect(r.groups.expand(idsOf).toSet(), {pinnedCarNoteId, 4});
  });

  test('date sort groups in order and omits empty groups', () {
    final keys = run().groups.map((g) => g.key).toList();
    expect(keys, [
      const PinnedGroup(),
      const TodayGroup(),
      const ThisWeekGroup(), // Nov 2
      const MonthGroup(2026, 10),
      const MonthGroup(2026, 1),
    ]);
  });

  test('last modified groups by modified date, falling back to note date', () {
    final r = run(sort: NoteSort.lastModified);
    final today = r.groups.firstWhere((g) => g.key is TodayGroup);
    expect(idsOf(today), containsAll([5, 3])); // 5 was modified today
  });

  test('# group is last in A-Z; Unflagged last in flag sort', () {
    final az = run(sort: NoteSort.subjectAZ).groups.map((g) => g.key).toList();
    expect(az.first, const PinnedGroup());
    expect(az.last, const LetterGroup('#'));
    expect(az, contains(const LetterGroup('Z')));
    expect(
      az.indexOf(const LetterGroup('A')),
      lessThan(az.indexOf(const LetterGroup('Z'))),
    );

    final fl = run(sort: NoteSort.flagColor).groups.map((g) => g.key).toList();
    expect(fl.last, const FlagGroup(null));
    expect(fl, [
      const PinnedGroup(),
      const FlagGroup(NoteFlagColor.red),
      const FlagGroup(NoteFlagColor.grey),
      const FlagGroup(null),
    ]);
  });

  test(
    'counts: attached note under its parent domain; General = unattached',
    () {
      final c = run().counts;
      expect(c.all, _notes.length);
      expect(c.pinned, 2);
      expect(c.byDomain['AutomobileMan'], 2); // car + attached note
      expect(c.byDomain['General'], _notes.length - 2);
      expect(c.byTag, {7: 2});
      expect(c.byFlag, {
        NoteFlagColor.red.index: 1,
        NoteFlagColor.yellow.index: 1,
        NoteFlagColor.grey.index: 1,
      });
    },
  );

  test('counts ignore the active source, tokens and text', () {
    final base = run().counts;
    final narrowed = run(
      source: const DomainSource(key: 'General'),
      text: 'apple',
      tokens: [const PinnedToken()],
    );
    expect(narrowed.counts.all, base.all);
    expect(narrowed.counts.pinned, base.pinned);
    expect(narrowed.counts.byDomain, base.byDomain);
    expect(narrowed.counts.byFlag, base.byFlag);
  });

  test('title match ranges are case- and accent-insensitive', () {
    final r = run(text: 'BRULEE');
    final hit = r.groups.expand((g) => g.hits).single;
    expect(hit.titleMatches, [const TextRange(start: 6, end: 12)]);
    expect(hit.previewMatches, [
      const TextRange(start: 0, end: 6),
      const TextRange(start: 7, end: 13),
    ]);
  });

  test('pinyin-only matches have no ranges', () {
    final hit = run(text: 'zs').groups.expand((g) => g.hits).single;
    expect(hit.note.id, 8);
    expect(hit.titleMatches, isEmpty);
    expect(hit.previewMatches, isEmpty);
  });

  test('no ranges without a text query', () {
    for (final h in run().groups.expand((g) => g.hits)) {
      expect(h.titleMatches, isEmpty);
    }
  });
}
