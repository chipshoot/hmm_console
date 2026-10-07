// test/features/contacts/domain/contact_name_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/contact_name.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact.dart';

Contact _p(
  String? family,
  String? given, [
  ContactNameOrder order = ContactNameOrder.auto,
]) => Contact(
  id: 'c',
  contactType: ContactType.person,
  lastName: family,
  firstName: given,
  nameOrder: order,
);

void main() {
  group('display rules table (spec)', () {
    final rows = <(String?, String?, ContactNameOrder, String)>[
      ('张', '伟', ContactNameOrder.auto, '张伟'),
      ('欧阳', '娜娜', ContactNameOrder.auto, '欧阳娜娜'),
      ('张', 'David', ContactNameOrder.auto, '张 David'),
      ('Smith', 'John', ContactNameOrder.auto, 'John Smith'),
      ('Zhang', 'Wei', ContactNameOrder.auto, 'Wei Zhang'),
      ('Zhang', 'Wei', ContactNameOrder.familyFirst, 'Zhang Wei'),
      ('张', '伟', ContactNameOrder.givenFirst, '伟 张'),
      ('张', null, ContactNameOrder.auto, '张'),
      (null, 'John', ContactNameOrder.auto, 'John'),
    ];
    for (final (family, given, order, shown) in rows) {
      test('$family / $given / ${order.name} -> $shown', () {
        final c = _p(family, given, order);
        expect(ContactName.displayName(c), shown);
        expect(c.displayName, shown);
      });
    }

    test('an organization shows its organization name', () {
      const org = Contact(
        id: 'o',
        contactType: ContactType.organization,
        organizationName: '人民医院',
        firstName: 'ignored',
        lastName: 'ignored',
      );
      expect(org.displayName, '人民医院');
      expect(
        const Contact(id: 'o', contactType: ContactType.organization)
            .displayName,
        '',
      );
    });
  });

  test('display: Chinese only in the given part', () {
    expect(_p('Smith', '伟').displayName, 'Smith 伟');
    expect(
      ContactName.effectiveOrder(_p('Smith', '伟')),
      ContactNameOrder.familyFirst,
    );
  });

  test('display: surrounding ASCII and full-width spaces are trimmed', () {
    expect(_p(' 张 ', '伟　').displayName, '张伟');
    expect(_p('  ', '').displayName, '');
    expect(_p('', 'John').displayName, 'John');
  });

  test('display: a space typed inside a Chinese part is kept', () {
    expect(_p('欧阳', '娜 娜').displayName, '欧阳娜 娜');
  });

  test('display: other scripts', () {
    // Kana and hangul are not Han: given-first with a space under Auto.
    expect(_p('やまだ', 'たろう').displayName, 'たろう やまだ');
    expect(_p('김', '민준').displayName, '민준 김');
    // Kanji are Han, so family-first with no space (right for Japanese too).
    expect(_p('山田', '太郎').displayName, '山田太郎');
    expect(_p('😀', 'Ann').displayName, 'Ann 😀');
    // The per-contact override still applies.
    expect(
      _p('김', '민준', ContactNameOrder.familyFirst).displayName,
      '김 민준',
    );
  });

  test('hasChinese reads supplementary-plane Han by rune', () {
    expect(ContactName.hasChinese('𠮷'), isTrue); // U+20BB7
    expect(_p('𠮷', '田').displayName, '𠮷田');
    expect(ContactName.hasChinese('😀'), isFalse);
    expect(ContactName.hasChinese('　'), isFalse);
    expect(ContactName.hasChinese('㐀'), isTrue); // U+3400
    expect(ContactName.hasChinese('豈'), isTrue); // U+F900
    expect(ContactName.hasChinese(null), isFalse);
    expect(ContactName.hasChinese(''), isFalse);
  });

  test('hanRuns splits maximal Han and non-Han runs', () {
    expect(ContactName.hanRuns('张David 伟'), [
      (true, '张'),
      (false, 'David '),
      (true, '伟'),
    ]);
    expect(ContactName.hanRuns(''), isEmpty);
  });

  test('effectiveOrder never returns auto', () {
    expect(
      ContactName.effectiveOrder(_p('Zhang', 'Wei')),
      ContactNameOrder.givenFirst,
    );
    expect(
      ContactName.effectiveOrder(_p('张', '伟')),
      ContactNameOrder.familyFirst,
    );
    expect(
      ContactName.effectiveOrder(_p('张', '伟', ContactNameOrder.givenFirst)),
      ContactNameOrder.givenFirst,
    );
  });

  test('phonetic validation table', () {
    const valid = [
      '',
      'Zhang',
      'Zhāng',
      'lǚ',
      'Lǜ',
      "Xi'an",
      'Xi’an', // iOS smart punctuation types U+2019
      ' wei ',
      'ou yang',
      'ou　yang',
    ];
    const invalid = ['张', 'zh4ng', 'a-b', 'wei.', 'x|y', 'Иван'];
    for (final v in valid) {
      expect(ContactName.isValidPhonetic(v), isTrue, reason: v);
    }
    for (final v in invalid) {
      expect(ContactName.isValidPhonetic(v), isFalse, reason: v);
    }
  });

  test('copyWith sets and clears the name options', () {
    final c = _p('张', '伟').copyWith(
      nameOrder: ContactNameOrder.givenFirst,
      phoneticFamily: 'Zhang',
      phoneticGiven: 'Wei',
    );
    expect(c.nameOrder, ContactNameOrder.givenFirst);
    expect(c.phoneticFamily, 'Zhang');
    final cleared = c.copyWith(phoneticFamily: null);
    expect(cleared.phoneticFamily, isNull);
    expect(cleared.phoneticGiven, 'Wei');
    expect(c == _p('张', '伟'), isFalse);
    expect(
      _p('张', '伟').copyWith(phoneticFamily: 'Zhang'),
      _p('张', '伟').copyWith(phoneticFamily: 'Zhang'),
    );
  });
}
