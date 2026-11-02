import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_ref.dart';
import 'package:hmm_console/core/notes/note_state.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/query/note_query_engine.dart';
import 'package:hmm_console/features/notes/query/note_text_index.dart';
import 'package:hmm_console/features/notes/states/notes_list_state.dart';

class _Fake implements PinyinTranscriber {
  static const _m = {
    '张': 'zhang',
    '三': 'san',
    '买': 'mai',
    '菜': 'cai',
    '李': 'li',
  };
  @override
  List<String> given(String text) => [
    for (final r in text.runes)
      _m[String.fromCharCode(r)] ?? String.fromCharCode(r),
  ];
  @override
  List<String> family(String text) => given(text);
}

const _general = 1;
const _auto = 2;
const _contactCat = 3;
const _record = 4;

const carId = 100;
const noteId = 1;
const unpinnedOilId = 2;
const pinnedId = 3;
const zhangSanId = 5;
const groceryId = 6;
const contactNoteId = 8;
const attachedId = noteId; // the oil-change note hangs under the car
const recordId = 9;

final now = DateTime(2026, 3, 15, 12);

HmmNote _note(
  int id,
  String subject, {
  int catalog = _general,
  int? parent,
  DateTime? date,
  DateTime? modified,
  String? content,
  double? lat,
  NoteAttachments? attachments,
}) => HmmNote(
  id: id,
  uuid: 'u$id',
  subject: subject,
  authorId: 1,
  catalogId: catalog,
  parentNoteId: parent,
  createDate: date ?? DateTime(2026, 1, id),
  lastModifiedDate: modified,
  content: content,
  latitude: lat,
  longitude: lat,
  attachments: attachments,
);

const _vault = VaultRef(
  path: 'a/b.jpg',
  contentType: 'image/jpeg',
  byteSize: 1,
);

final _notes = <HmmNote>[
  _note(carId, 'Honda Civic', catalog: _auto, date: DateTime(2026, 1, 1)),
  _note(
    noteId,
    'Oil change',
    parent: carId,
    content: '5W-30',
    date: DateTime(2026, 3, 15, 9),
    attachments: NoteAttachments(primaryImage: _vault),
  ),
  _note(unpinnedOilId, 'Oil filter shop', date: DateTime(2026, 3, 14, 23)),
  _note(pinnedId, 'Shopping list', date: DateTime(2026, 3, 1)),
  _note(4, 'Plain', date: DateTime(2026, 2, 1), lat: 12.5),
  _note(zhangSanId, '张三', date: DateTime(2026, 2, 5)),
  _note(groceryId, '买菜', date: DateTime(2026, 2, 6)),
  _note(7, 'Zebra', date: DateTime(2025, 11, 30)),
  _note(
    contactNoteId,
    'Contact:c-1',
    catalog: _contactCat,
    content: '{"givenName":"Alice"}',
    date: DateTime(2026, 2, 8),
  ),
  _note(recordId, 'Service', catalog: _record, parent: carId),
];

String _titleOf(HmmNote n) => n.id == contactNoteId ? 'Alice' : n.subject;

NoteTextKey _keyOf(HmmNote n) =>
    (noteId: n.id, version: 'v', locale: 'en', parentTitle: '', tags: '');

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
  catalogDomainById: const {
    _general: 'General',
    _auto: 'AutomobileMan',
    _contactCat: 'ContactMan',
    _record: 'AutomobileMan',
  },
  targetsById: const {carId: (domain: 'AutomobileMan', subject: 'Honda Civic')},
  tagsByNoteId: const {
    noteId: [(id: 7, name: 'Garage')],
    4: [(id: 8, name: 'misc')],
  },
  statesByUuid: {
    'u$pinnedId': _st(_byId(pinnedId), pinned: true, flag: 0),
    'u4': _st(_byId(4), flag: 4),
    'u7': _st(_byId(7), flag: 99), // unknown colour -> grey
    'u$groceryId': _st(_byId(groceryId), pinned: true),
  },
);

InMemoryNoteQueryEngine _engine({bool indexed = true}) {
  final cache = NoteTextIndexCache();
  final c = _corpus();
  if (indexed) {
    for (final n in _notes) {
      cache.store(
        _keyOf(n),
        buildNoteTextIndex(
          title: _titleOf(n),
          body: n.id == contactNoteId ? 'Doctor' : (n.content ?? ''),
          parentTitle: c.contextSubjectOf(n),
          tagNames: [for (final t in c.tagsByNoteId[n.id] ?? []) t.name],
          pinyin: _Fake(),
        ),
      );
    }
  }
  return InMemoryNoteQueryEngine(
    cache: cache,
    keyOf: _keyOf,
    titleOf: _titleOf,
    pinyin: _Fake(),
  );
}

List<int> run({
  NoteSource source = const AllSource(),
  String text = '',
  List<NoteToken> tokens = const [],
  NoteScope scope = NoteScope.currentSource,
  NoteSort sort = NoteSort.dateNewest,
  bool indexed = true,
}) {
  final q = NoteQuery(
    source: source,
    text: text,
    tokens: tokens,
    scope: scope,
    sort: sort,
  );
  final r = _engine(
    indexed: indexed,
  ).evaluate(q, _corpus(), now: now, firstDayOfWeek: DateTime.monday);
  return [
    for (final g in r.groups)
      for (final h in g.hits) h.note.id,
  ];
}

/// Evaluates against an explicit corpus (the shared one cannot carry
/// `liveTagNames` or extra notes).
List<int> _runOn(NotesListData corpus, NoteQuery q) {
  final r = _engine(
    indexed: false,
  ).evaluate(q, corpus, now: now, firstDayOfWeek: DateTime.monday);
  return [
    for (final g in r.groups)
      for (final h in g.hits) h.note.id,
  ];
}

Set<int> ids(List<int> l) => l.toSet();

void main() {
  group('removed tokens and scope over tokens', () {
    test('a tag token for a removed tag is ignored', () {
      final c = _corpus().copyWith(liveTagNames: const {1: 'car'});
      final withGone = _runOn(
        c,
        NoteQuery(tokens: const [TagToken(1), TagToken(99)]),
      );
      final onlyLive = _runOn(c, NoteQuery(tokens: const [TagToken(1)]));
      expect(withGone, onlyLive);
      expect(isRemovedToken(const TagToken(99), c), isTrue);
      expect(isRemovedToken(const TagToken(1), c), isFalse);
    });

    test('a removed tag token alone leaves every note', () {
      final c = _corpus().copyWith(liveTagNames: const {1: 'car'});
      expect(
        _runOn(c, NoteQuery(tokens: const [TagToken(99)])),
        hasLength(_notes.length),
      );
    });

    test('with unknown live tags every tag token filters', () {
      final c = _corpus();
      expect(c.liveTagNames, isNull);
      expect(_runOn(c, NoteQuery(tokens: const [TagToken(99)])), isEmpty);
      expect(isRemovedToken(const TagToken(99), c), isFalse);
    });

    test('a parent token for a note not in the corpus is ignored', () {
      final c = _corpus();
      expect(
        _runOn(c, NoteQuery(tokens: const [ParentToken('gone')])),
        hasLength(_notes.length),
      );
      expect(isRemovedToken(const ParentToken('gone'), c), isTrue);
      expect(isRemovedToken(ParentToken('u$carId'), c), isFalse);
    });

    test('scope all with only tokens ignores the source', () {
      final photoGeneral = _note(
        50,
        'Receipt',
        attachments: NoteAttachments(primaryImage: _vault),
      );
      final base = _corpus();
      final c = base.copyWith(all: [..._notes, photoGeneral]);
      NoteQuery q(NoteScope scope) => NoteQuery(
        source: const DomainSource(key: 'AutomobileMan'),
        tokens: const [HasPhotoToken()],
        scope: scope,
      );
      expect(_runOn(c, q(NoteScope.all)), contains(50));
      expect(_runOn(c, q(NoteScope.currentSource)), isNot(contains(50)));
    });
  });

  group('sources', () {
    test('source all', () => expect(run(), hasLength(_notes.length)));
    test('source pinned', () {
      expect(ids(run(source: const PinnedSource())), {pinnedId, groceryId});
    });
    test('source flagged (any) and by colour', () {
      expect(ids(run(source: const FlaggedSource())), {pinnedId, 4, 7});
      expect(ids(run(source: const FlaggedSource(color: 0))), {pinnedId});
      // an unknown stored colour is grey on both sides
      expect(ids(run(source: const FlaggedSource(color: 6))), {7});
      expect(ids(run(source: const FlaggedSource(color: 42))), {7});
    });
    test('source today', () {
      expect(ids(run(source: const TodaySource())), {noteId});
    });
    test('source domain', () {
      expect(ids(run(source: const DomainSource(key: 'ContactMan'))), {
        contactNoteId,
      });
    });
    test('source domain with catalog: exact catalog unless re-homed', () {
      // The record keeps its exact catalog; the oil note is General but hangs
      // under the car, so it follows the parent's domain into any catalog of
      // that domain.
      expect(
        ids(
          run(
            source: const DomainSource(
              key: 'AutomobileMan',
              catalogId: _record,
            ),
          ),
        ),
        {recordId, noteId},
      );
      expect(
        run(
          source: const DomainSource(key: 'General', catalogId: _general),
        ),
        isNot(contains(noteId)),
      );
    });
    test('source tag', () {
      expect(ids(run(source: const TagSource(tagId: 7))), {noteId});
    });
    test('source smart, recentlyDeleted and unknown match nothing', () {
      expect(run(source: const SmartSource(savedId: 'x')), isEmpty);
      expect(run(source: const RecentlyDeletedSource()), isEmpty);
      expect(
        run(source: const UnknownSource(raw: {'type': 'future'})),
        isEmpty,
      );
    });
    test(
      'a General note attached to a car lists under Automobile, not General',
      () {
        expect(
          run(source: const DomainSource(key: 'AutomobileMan')),
          containsAll([carId, attachedId]),
        );
        expect(
          run(source: const DomainSource(key: 'General')),
          isNot(contains(attachedId)),
        );
      },
    );
  });

  group('tokens', () {
    test('token tag', () => expect(run(tokens: [const TagToken(8)]), [4]));
    test('token flag matches display colour', () {
      expect(run(tokens: [const FlagToken(4)]), [4]);
      expect(run(tokens: [const FlagToken(6)]), [7]);
    });
    test('token domain', () {
      expect(ids(run(tokens: [const DomainToken('AutomobileMan')])), {
        carId,
        noteId,
        recordId,
      });
    });
    test('token catalog', () {
      expect(run(tokens: [const CatalogToken(_contactCat)]), [contactNoteId]);
    });
    test('token parent', () {
      expect(ids(run(tokens: [const ParentToken('u$carId')])), {
        noteId,
        recordId,
      });
    });
    test('token hasPhoto / hasAttachment', () {
      expect(run(tokens: [const HasPhotoToken()]), [noteId]);
      expect(run(tokens: [const HasAttachmentToken()]), [noteId]);
    });
    test(
      'token hasPlace',
      () => expect(run(tokens: [const HasPlaceToken()]), [4]),
    );
    test('token date range is inclusive and either end optional', () {
      final r = DateRangeToken(
        from: DateTime(2026, 2, 5),
        to: DateTime(2026, 2, 8),
      );
      expect(ids(run(tokens: [r])), {zhangSanId, groceryId, contactNoteId});
      expect(ids(run(tokens: [DateRangeToken(from: DateTime(2026, 3, 14))])), {
        noteId,
        unpinnedOilId,
      });
      expect(ids(run(tokens: [DateRangeToken(to: DateTime(2025, 11, 30))])), {
        7,
      });
    });
    test('token relative date counts back from the start of today', () {
      // now = Mar 15; last7d starts Mar 9.
      expect(
        ids(run(tokens: [const RelativeDateToken(RelativeRange.last7d)])),
        {noteId, unpinnedOilId},
      );
      // last30d starts Feb 14: Mar 1 note joins, Feb 8 does not.
      expect(
        ids(run(tokens: [const RelativeDateToken(RelativeRange.last30d)])),
        {noteId, unpinnedOilId, pinnedId},
      );
      expect(
        ids(run(tokens: [const RelativeDateToken(RelativeRange.last90d)])),
        containsAll([4, contactNoteId, carId]),
      );
      expect(
        ids(run(tokens: [const RelativeDateToken(RelativeRange.last90d)])),
        isNot(contains(7)),
      );
    });
    test('token pinned', () {
      expect(ids(run(tokens: [const PinnedToken()])), {pinnedId, groceryId});
    });
    test('unknown token is ignored, not a filter', () {
      expect(
        run(
          tokens: [
            const UnknownToken({'type': 'future'}),
          ],
        ),
        hasLength(_notes.length),
      );
    });
    test('tokens are AND-ed with the source', () {
      expect(run(source: const PinnedSource(), tokens: [const FlagToken(0)]), [
        pinnedId,
      ]);
    });
  });

  group('text', () {
    test('words are AND-ed across title, body, parent and tags', () {
      expect(run(text: 'honda 5w-30'), [noteId]);
      expect(run(text: 'garage oil'), [noteId]);
      expect(run(text: 'honda toyota'), isEmpty);
    });
    test('pinyin initials find a Han title', () {
      expect(run(text: 'zs'), [zhangSanId]);
      expect(run(text: 'zhangsan'), [zhangSanId]);
    });
    test('a Han word matches Han text directly', () {
      expect(run(text: '买菜'), [groceryId]);
    });
    test('scope all ignores the source when searching', () {
      expect(
        run(source: const PinnedSource(), text: 'oil', scope: NoteScope.all),
        containsAll([unpinnedOilId, noteId]),
      );
      expect(run(source: const PinnedSource(), text: 'oil'), isEmpty);
      // tokens still apply under scope all
      expect(
        run(
          source: const PinnedSource(),
          text: 'oil',
          scope: NoteScope.all,
          tokens: [const HasPhotoToken()],
        ),
        [noteId],
      );
      // empty text keeps the source
      expect(ids(run(source: const PinnedSource(), scope: NoteScope.all)), {
        pinnedId,
        groceryId,
      });
    });
    test('entity note is searched by its display title, never its JSON', () {
      expect(run(text: 'givenname'), isEmpty);
      expect(run(text: 'alice'), [contactNoteId]);
      expect(run(text: 'doctor'), [contactNoteId]);
    });
    test('unindexed note still matches by title and parent title', () {
      expect(run(text: 'alice', indexed: false), [contactNoteId]);
      expect(
        run(text: 'oil', indexed: false),
        containsAll([noteId, unpinnedOilId]),
      );
      expect(
        run(text: 'honda', indexed: false),
        containsAll([noteId, recordId]),
      );
      expect(run(text: '5w-30', indexed: false), isEmpty); // body not indexed
    });
    test('accents and case fold', () {
      expect(run(text: 'OIL  FILTER'), [unpinnedOilId]);
    });
  });

  group('sorts', () {
    List<int> sorted(NoteSort s) => run(
      sort: s,
      source: const AllSource(),
      tokens: [const DomainToken('General')],
    );

    test('dateNewest / dateOldest', () {
      // The Pinned section leads every sort; within it and below it the
      // order follows the sort.
      final pinned = {pinnedId, groceryId};
      List<int> unpinned(List<int> l) =>
          l.where((i) => !pinned.contains(i)).toList();
      final newest = sorted(NoteSort.dateNewest);
      expect(newest.take(2).toSet(), pinned);
      expect(unpinned(newest).first, unpinnedOilId);
      expect(newest.last, 7);
      final oldest = sorted(NoteSort.dateOldest);
      expect(oldest.take(2), newest.take(2).toList().reversed);
      expect(unpinned(oldest), unpinned(newest).reversed.toList());
    });

    test(
      'lastModified uses lastModifiedDate, falling back to the note date',
      () {
        // 7 (Nov 30) was modified most recently of all.
        final notes = [
          _note(
            50,
            'a',
            date: DateTime(2026, 1, 1),
            modified: DateTime(2026, 3, 1),
          ),
          _note(51, 'b', date: DateTime(2026, 2, 1)),
          _note(
            52,
            'c',
            date: DateTime(2026, 1, 2),
            modified: DateTime(2026, 3, 10),
          ),
        ];
        final r =
            InMemoryNoteQueryEngine(
              cache: NoteTextIndexCache(),
              keyOf: _keyOf,
              titleOf: _titleOf,
              pinyin: _Fake(),
            ).evaluate(
              const NoteQuery(sort: NoteSort.lastModified),
              NotesListData(all: notes, catalogsById: const {}),
              now: now,
              firstDayOfWeek: 1,
            );
        expect(
          [
            for (final g in r.groups)
              for (final h in g.hits) h.note.id,
          ],
          [52, 50, 51],
        );
      },
    );

    test('subjectAZ is case-insensitive; Han sorts by pinyin', () {
      final order = run(sort: NoteSort.subjectAZ);
      // alice(contact) < civic... titles: Alice, Honda Civic, Oil change,
      // Oil filter shop, Plain, Service, Shopping list, Zebra; 买菜 = mai...,
      // 张三 = zhang... slot between Service/Shopping and Zebra by pinyin.
      expect(order, [
        // Pinned section first, in A-Z order.
        groceryId, // mai cai
        pinnedId, // Shopping list
        contactNoteId, // Alice
        carId, // Honda Civic
        noteId, // Oil change
        unpinnedOilId, // Oil filter shop
        4, // Plain
        recordId, // Service
        7, // Zebra
        zhangSanId, // zhang san
      ]);
    });

    test('flagColor: colour order, unflagged last, ties newest first', () {
      final order = run(sort: NoteSort.flagColor);
      // Pinned section first (red, then unflagged), then blue, (unknown) grey.
      expect(order.take(4), [pinnedId, groceryId, 4, 7]);
      // unflagged: newest first
      expect(order.skip(4).first, noteId);
    });

    test('ties break by note id descending', () {
      final notes = [
        _note(60, 'same', date: DateTime(2026, 1, 1)),
        _note(61, 'same', date: DateTime(2026, 1, 1)),
      ];
      for (final s in NoteSort.values) {
        final r =
            InMemoryNoteQueryEngine(
              cache: NoteTextIndexCache(),
              keyOf: _keyOf,
              titleOf: _titleOf,
              pinyin: _Fake(),
            ).evaluate(
              NoteQuery(sort: s),
              NotesListData(all: notes, catalogsById: const {}),
              now: now,
              firstDayOfWeek: 1,
            );
        expect(
          [
            for (final g in r.groups)
              for (final h in g.hits) h.note.id,
          ],
          [61, 60],
        );
      }
    });
  });

  test('titleOf runs at most once per note per evaluate', () {
    final calls = <int, int>{};
    final engine = InMemoryNoteQueryEngine(
      cache: NoteTextIndexCache(),
      keyOf: _keyOf,
      titleOf: (n) {
        calls[n.id] = (calls[n.id] ?? 0) + 1;
        return n.subject;
      },
      pinyin: _Fake(),
    );
    engine.evaluate(
      const NoteQuery(text: 'o', sort: NoteSort.subjectAZ),
      _corpus(),
      now: now,
      firstDayOfWeek: 1,
    );
    expect(calls.values.every((c) => c <= 1), isTrue);
  });
}
