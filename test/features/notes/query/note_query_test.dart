import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';

NoteQuery _roundTrip(NoteQuery q) => NoteQuery.fromJson(
  (jsonDecode(jsonEncode(q.toJson())) as Map).cast<String, Object?>(),
);

void main() {
  test('round-trips every source and token', () {
    final q = NoteQuery(
      source: const DomainSource(key: 'AutomobileMan', catalogId: 4),
      text: 'tyres',
      tokens: [
        const TagToken(3),
        const FlagToken(2),
        const DomainToken('General'),
        const CatalogToken(7),
        const ParentToken('u-1'),
        const HasPhotoToken(),
        const HasPlaceToken(),
        const HasAttachmentToken(),
        DateRangeToken(
          from: DateTime.utc(2026, 1, 1),
          to: DateTime.utc(2026, 2, 1),
        ),
        const RelativeDateToken(RelativeRange.last30d),
        const PinnedToken(),
      ],
      scope: NoteScope.all,
      sort: NoteSort.flagColor,
    );
    expect(_roundTrip(q), q);
  });

  test(
    'unknown source, token, sort and top-level fields survive a round trip',
    () {
      final raw = <String, Object?>{
        'source': {'type': 'calendar', 'day': '2026-11-01'},
        'tokens': [
          {'type': 'sharedWith', 'user': 7},
          {'type': 'pinned'},
        ],
        'sort': 'byMood',
        'scope': 'currentSource',
        'text': '',
        'future': 1,
      };
      final q = NoteQuery.fromJson(raw);
      expect(q.source, isA<UnknownSource>());
      expect(q.tokens.first, isA<UnknownToken>());
      expect(q.sort, NoteSort.dateNewest);
      expect(q.toJson(), raw);
    },
  );

  test('an unknown scope reads as the default and is re-emitted', () {
    final q = NoteQuery.fromJson({'scope': 'galaxy', 'sort': 'dateOldest'});
    expect(q.scope, NoteScope.currentSource);
    expect(q.toJson()['scope'], 'galaxy');
    expect(q.toJson()['sort'], 'dateOldest');
  });

  test('changing sort drops the preserved raw unknown sort', () {
    final q = NoteQuery.fromJson({'sort': 'byMood'});
    expect(q.copyWith(sort: NoteSort.subjectAZ).toJson()['sort'], 'subjectAZ');
  });

  test('every source type round-trips', () {
    const sources = <NoteSource>[
      AllSource(),
      PinnedSource(),
      FlaggedSource(),
      FlaggedSource(color: 3),
      TodaySource(),
      DomainSource(key: 'General'),
      DomainSource(key: 'AutomobileMan', catalogId: 4),
      TagSource(tagId: 9),
      SmartSource(savedId: 'abc'),
      RecentlyDeletedSource(),
      UnknownSource(raw: {'type': 'x', 'n': 1}),
    ];
    for (final s in sources) {
      final q = const NoteQuery.initial().copyWith(source: s);
      expect(_roundTrip(q).source, s, reason: '$s');
    }
  });

  test('initial query and equality', () {
    const q = NoteQuery.initial();
    expect(q.source, const AllSource());
    expect(q.text, '');
    expect(q.tokens, isEmpty);
    expect(q.scope, NoteScope.currentSource);
    expect(q.sort, NoteSort.dateNewest);
    expect(q.extra, isEmpty);
    expect(q, const NoteQuery.initial());
    expect(q.hashCode, const NoteQuery.initial().hashCode);
    expect(q.copyWith(text: 'a'), isNot(q));
  });

  group('malformed persisted JSON', () {
    test(
      'a known type with wrong field types becomes Unknown and survives',
      () {
        final raw = <String, Object?>{
          'source': {'type': 'tag', 'tagId': 'x'},
          'tokens': [
            {'type': 'tag', 'tagId': 'x'},
          ],
          'text': '',
          'scope': 'all',
          'sort': 'dateNewest',
        };
        final q = NoteQuery.fromJson(raw);
        expect(q.source, isA<UnknownSource>());
        expect(q.tokens.single, isA<UnknownToken>());
        expect(q.toJson(), raw);
      },
    );

    test('an unparseable date does not throw and survives', () {
      final raw = <String, Object?>{
        'tokens': [
          {'type': 'date', 'from': 'garbage'},
          {'type': 'date', 'to': 5},
        ],
      };
      final q = NoteQuery.fromJson(raw);
      expect(q.tokens, everyElement(isA<UnknownToken>()));
      expect(q.toJson()['tokens'], raw['tokens']);
    });

    test('non-map source and token round-trip verbatim', () {
      final raw = <String, Object?>{
        'source': 'oops',
        'tokens': ['x', 7, null],
      };
      final q = NoteQuery.fromJson(raw);
      expect(q.source, isA<UnknownSource>());
      expect(q.toJson()['source'], 'oops');
      expect(q.toJson()['tokens'], ['x', 7, null]);
    });

    test('wrong-typed text and tokens do not throw and re-emit', () {
      final raw = <String, Object?>{'text': 5, 'tokens': 'nope'};
      final q = NoteQuery.fromJson(raw);
      expect(q.text, '');
      expect(q.tokens, isEmpty);
      expect(q.toJson()['text'], 5);
      expect(q.toJson()['tokens'], 'nope');
      expect(q.copyWith(text: 'a').toJson()['text'], 'a');
      expect(q.copyWith(tokens: const [PinnedToken()]).toJson()['tokens'], [
        {'type': 'pinned'},
      ]);
    });
  });
}
