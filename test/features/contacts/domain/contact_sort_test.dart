// test/features/contacts/domain/contact_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort.dart';
import 'package:hmm_console/features/contacts/domain/contact_sort_by.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';

import '../fake_pinyin_transcriber.dart';

Contact _p(
  String id,
  String? family,
  String? given, {
  String? phFamily,
  String? phGiven,
}) => Contact(
  id: id,
  contactType: ContactType.person,
  lastName: family,
  firstName: given,
  phoneticFamily: phFamily,
  phoneticGiven: phGiven,
);

Contact _org(String id, String name) => Contact(
  id: id,
  contactType: ContactType.organization,
  organizationName: name,
);

List<String> _sorted(
  List<Contact> cs,
  ContactSortBy by,
  FakePinyinTranscriber t,
) {
  final keys = {for (final c in cs) c.id: sortKey(c, by, t)};
  final out = [...cs]
    ..sort((a, b) => compareContactKeys(a, keys[a.id]!, b, keys[b.id]!));
  return [for (final c in out) c.id];
}

void main() {
  late FakePinyinTranscriber t;
  setUp(() => t = FakePinyinTranscriber());

  group('ContactSortBy.fromName', () {
    test('reads given; anything else is family', () {
      expect(ContactSortBy.fromName('given'), ContactSortBy.given);
      expect(ContactSortBy.fromName('family'), ContactSortBy.family);
      expect(ContactSortBy.fromName(null), ContactSortBy.family);
      expect(ContactSortBy.fromName('bogus'), ContactSortBy.family);
      expect(ContactSortBy.fromName(3), ContactSortBy.family);
    });
  });

  group('name order override', () {
    test('never changes the sort key, in either sort mode', () {
      for (final by in ContactSortBy.values) {
        final keys = {
          for (final o in ContactNameOrder.values)
            o: sortKey(
              _p('a', '张', '伟').copyWith(nameOrder: o),
              by,
              t,
            ),
        };
        expect(keys.values.toSet(), hasLength(1), reason: '$by: $keys');
      }
    });
  });

  group('normalizeForSearch', () {
    test('lowercases, folds accents, collapses whitespace, drops |', () {
      expect(normalizeForSearch('  Émile   ZOLA '), 'emile zola');
      expect(normalizeForSearch('Müller'), 'muller');
      expect(normalizeForSearch('lǚ Zhāng'), 'lu zhang');
      expect(normalizeForSearch('a　b'), 'a b');
      expect(normalizeForSearch('A|B'), 'a b');
      expect(normalizeForSearch('张伟'), '张伟');
    });
  });

  group('sortKey', () {
    test('family and given modes for Chinese and Latin names', () {
      expect(sortKey(_p('1', '张', '伟'), ContactSortBy.family, t), 'zhang|wei');
      expect(sortKey(_p('1', '张', '伟'), ContactSortBy.given, t), 'wei|zhang');
      expect(
        sortKey(_p('2', 'Smith', 'John'), ContactSortBy.family, t),
        'smith|john',
      );
      expect(
        sortKey(_p('2', 'Smith', 'John'), ContactSortBy.given, t),
        'john|smith',
      );
      expect(
        sortKey(_p('3', '欧阳', '娜娜'), ContactSortBy.family, t),
        'ou yang|na na',
      );
    });

    test('accent folding', () {
      expect(
        sortKey(_p('1', 'Zola', 'Émile'), ContactSortBy.family, t),
        'zola|emile',
      );
      expect(
        sortKey(_p('2', 'Müller', 'Jürgen'), ContactSortBy.family, t),
        'muller|jurgen',
      );
    });

    test('a phonetic field overrides automatic pinyin', () {
      expect(
        sortKey(_p('1', '曾', '伟', phFamily: 'Tsang'), ContactSortBy.family, t),
        'tsang|wei',
      );
      expect(
        sortKey(_p('2', '曾', '伟', phFamily: 'Zēng'), ContactSortBy.family, t),
        'zeng|wei',
      );
      expect(
        sortKey(
          _p('3', 'Smith', 'John', phGiven: "Jo'n"),
          ContactSortBy.family,
          t,
        ),
        'smith|jo n',
      );
    });

    test('sort: an empty phonetic beside a filled one falls back to pinyin',
        () {
      for (final empty in [null, '', '   ']) {
        expect(
          sortKey(
            _p('1', '曾', '伟', phFamily: 'Tsang', phGiven: empty),
            ContactSortBy.family,
            t,
          ),
          'tsang|wei',
          reason: '$empty',
        );
      }
    });

    test('sort: Chinese only in the given part', () {
      expect(
        sortKey(_p('1', 'Smith', '伟'), ContactSortBy.family, t),
        'smith|wei',
      );
    });

    test('sort: full-width spaces collapse', () {
      expect(
        sortKey(_p('1', ' Zhang　', 'Wei  Li'), ContactSortBy.family, t),
        'zhang|wei li',
      );
    });

    test('a single name part leads the key in either mode', () {
      expect(sortKey(_p('1', '张', null), ContactSortBy.family, t), 'zhang|');
      expect(sortKey(_p('1', '张', null), ContactSortBy.given, t), 'zhang|');
      expect(sortKey(_p('2', null, 'John'), ContactSortBy.family, t), 'john|');
    });

    test('organizations key on their name, transcribed when Chinese', () {
      expect(
        sortKey(_org('o', 'Kaiser Clinic'), ContactSortBy.family, t),
        'kaiser clinic',
      );
      expect(
        sortKey(_org('o', '人民医院'), ContactSortBy.given, t),
        'ren min yi yuan',
      );
    });

    test('a nameless contact has an empty key', () {
      expect(sortKey(_p('1', null, '  '), ContactSortBy.family, t), '');
      expect(sortKey(_org('o', ''), ContactSortBy.family, t), '');
    });

    test('sort: a throwing transcriber falls back to raw text', () {
      final failing = FakePinyinTranscriber(throwOn: {'张'});
      final errors = <Object>[];
      expect(
        sortKey(
          _p('1', '张', '伟'),
          ContactSortBy.family,
          failing,
          onError: errors.add,
        ),
        '张|wei',
      );
      expect(errors.single, isA<StateError>());
    });

    test('a null transcriber sorts by raw text', () {
      expect(sortKey(_p('1', '张', '伟'), ContactSortBy.family, null), '张|伟');
    });

    test('sort: kana, hangul and emoji never reach the transcriber', () {
      expect(
        sortKey(_p('1', 'やまだ', 'たろう'), ContactSortBy.family, t),
        'やまだ|たろう',
      );
      expect(sortKey(_p('2', '김', '민준'), ContactSortBy.family, t), '김|민준');
      expect(sortKey(_p('3', '😀', 'Ann'), ContactSortBy.family, t), '😀|ann');
      expect(t.calls, 0);
    });
  });

  group('compareContactKeys', () {
    test('mixed scripts interleave; orgs sit among people; nameless last', () {
      final cs = [
        _p('nameless', null, null),
        _p('zw-zh', '张', '伟'),
        _p('zw-lat', 'Zhang', 'Wei'),
        _p('ll', '李', '丽'),
        _org('kaiser', 'Kaiser Clinic'),
        _p('al', 'Adams', 'Lee'),
        _p('lin', '林', '明'),
      ];
      expect(_sorted(cs, ContactSortBy.family, t), [
        'al', // adams|lee
        'kaiser', // kaiser clinic
        'll', // li|li
        'lin', // lin|ming (li before lin, part-wise)
        'zw-lat', // zhang|wei, display "Wei Zhang" < "张伟"
        'zw-zh',
        'nameless',
      ]);
    });

    test('given-name mode reorders', () {
      final cs = [_p('a', 'Adams', 'Zoe'), _p('b', 'Young', 'Amy')];
      expect(_sorted(cs, ContactSortBy.family, t), ['a', 'b']);
      expect(_sorted(cs, ContactSortBy.given, t), ['b', 'a']);
    });

    test('ties break by display name, then id', () {
      final cs = [_p('b', 'Lee', 'Ann'), _p('a', 'Lee', 'Ann')];
      expect(_sorted(cs, ContactSortBy.family, t), ['a', 'b']);
    });

    test('a | typed in a name cannot split the key', () {
      expect(
        sortKey(_p('1', 'A|B', 'C'), ContactSortBy.family, t),
        'a b|c',
      );
    });
  });

  group('searchTerms and matchesSearch', () {
    test('ü is also searchable as v, as pinyin input methods type it', () {
      final c = _p('lw', '吕', '伟');
      final terms = searchTerms(c, t);
      for (final q in ['lvwei', 'lv wei', 'luwei', 'lu wei', 'lw']) {
        expect(matchesSearch(c, terms, q), isTrue, reason: q);
      }
      expect(terms.prefixes, ['lw']);
    });

    bool m(Contact c, String q, [FakePinyinTranscriber? tr]) =>
        matchesSearch(c, searchTerms(c, tr ?? t), q);

    test('张伟 matches by pinyin, initials, either order, and Chinese', () {
      final c = _p('1', '张', '伟');
      for (final q in [
        'zw',
        'ZW',
        'zhangwei',
        ' zhang  wei ',
        'weizhang',
        'wei zhang',
        'zhang',
        '张',
        '张伟',
      ]) {
        expect(m(c, q), isTrue, reason: q);
      }
      expect(m(c, 'li'), isFalse);
    });

    test('initials match as a prefix only', () {
      final c = _p('1', '张', '伟明');
      expect(m(c, 'zwm'), isTrue);
      expect(m(c, 'zw'), isTrue);
      expect(m(c, 'wm'), isFalse);
    });

    test('Latin names match in either order, with no initials term', () {
      final c = _p('1', 'Lovelace', 'Ada');
      expect(m(c, 'ada lovelace'), isTrue);
      expect(m(c, 'lovelace ada'), isTrue);
      expect(m(c, 'al'), isFalse);
    });

    test('accent folding applies to queries and terms', () {
      final c = _p('1', 'Zola', 'Émile');
      expect(m(c, 'emile'), isTrue);
      expect(m(c, 'ÉMILE'), isTrue);
    });

    test('search: Chinese only in the given part', () {
      final c = _p('1', 'Smith', '伟');
      expect(m(c, 'smithwei'), isTrue);
      expect(m(c, 'sw'), isTrue);
    });

    test('a phonetic field wins over automatic pinyin', () {
      final c = _p('1', '曾', '伟', phFamily: 'Tsang');
      expect(m(c, 'tsangwei'), isTrue);
      expect(m(c, 'tw'), isTrue);
      expect(m(c, 'zengwei'), isFalse);
    });

    test('a throwing transcriber omits pinyin terms only', () {
      final failing = FakePinyinTranscriber(throwOn: {'张', '伟'});
      final c = _p('1', '张', '伟');
      final errors = <Object>[];
      final terms = searchTerms(c, failing, onError: errors.add);
      expect(matchesSearch(c, terms, 'zhangwei'), isFalse);
      expect(matchesSearch(c, terms, '张伟'), isTrue);
      expect(errors, isNotEmpty);
    });

    test('Chinese organizations match by pinyin and initials', () {
      final c = _org('o', '人民医院');
      expect(m(c, 'renmin'), isTrue);
      expect(m(c, 'rmyy'), isTrue);
    });

    test('phones by digits and emails still match', () {
      const c = Contact(
        id: '1',
        contactType: ContactType.person,
        firstName: 'Ann',
        phones: [ContactPhone(label: 'mobile', number: '(604) 555-0100')],
        emails: [ContactEmail(label: 'work', address: 'Ann@Example.com')],
      );
      expect(m(c, '6045550100'), isTrue);
      expect(m(c, '555-01'), isTrue);
      expect(m(c, 'example.COM'), isTrue);
      expect(m(c, '777'), isFalse);
    });

    test('an empty query matches everything', () {
      expect(m(_p('1', null, null), '   '), isTrue);
    });
  });
}
