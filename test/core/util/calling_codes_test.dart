import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/calling_codes.dart';

void main() {
  group('splitInternationalNumber', () {
    test('two-digit code', () {
      final r = splitInternationalNumber('+8613800138000')!;
      expect(r.code.code, '86');
      expect(r.national, '13800138000');
    });
    test('one-digit code', () {
      final r = splitInternationalNumber('+12125551234')!;
      expect(r.code.code, '1');
      expect(r.national, '2125551234');
    });
    test('three-digit code', () {
      final r = splitInternationalNumber('+35312345')!;
      expect(r.code.code, '353');
      expect(r.national, '12345');
    });
    test('separators after the code are dropped', () {
      expect(
        splitInternationalNumber('+44 20 7946 0958')!.national,
        '20 7946 0958',
      );
      expect(splitInternationalNumber('+1-555-0100')!.national, '555-0100');
    });
    test('brackets in the national part are kept', () {
      expect(
        splitInternationalNumber('+1 (555) 123-4567')!.national,
        '(555) 123-4567',
      );
      expect(
        splitInternationalNumber('+44 (0)20 7946 0958')!.national,
        '(0)20 7946 0958',
      );
    });
    test('unknown code and non-international input do not match', () {
      expect(splitInternationalNumber('+999 1'), isNull);
      expect(splitInternationalNumber('604-555-0100'), isNull);
      expect(splitInternationalNumber('+'), isNull);
    });
    test('shared codes resolve to a primary region', () {
      expect(splitInternationalNumber('+1 5')!.code.iso, 'US');
      expect(splitInternationalNumber('+7 9')!.code.iso, 'RU');
    });
  });

  group('search', () {
    test('by digits with or without +', () {
      expect(searchCallingCodes('86').map((c) => c.iso), contains('CN'));
      expect(searchCallingCodes('+86').map((c) => c.iso), contains('CN'));
      expect(
        searchCallingCodes('+86').every((c) => c.code.startsWith('86')),
        isTrue,
      );
    });
    test('by ISO code, exact match first', () {
      expect(searchCallingCodes('ca').first.iso, 'CA');
    });
    test('by English name, case-insensitive', () {
      expect(searchCallingCodes('GERMA').map((c) => c.iso), ['DE']);
    });
    test('blank query returns everything', () {
      expect(searchCallingCodes('  '), callingCodes);
    });
  });

  test('shared codes list every region', () {
    final plus1 = callingCodes.where((c) => c.code == '1').map((c) => c.iso);
    expect(plus1, containsAll(['US', 'CA', 'JM', 'PR']));
    expect(
      callingCodes.where((c) => c.code == '7').map((c) => c.iso),
      containsAll(['RU', 'KZ']),
    );
  });

  test('flag emoji derives from the ISO code', () {
    expect(flagEmoji('CN'), '\u{1F1E8}\u{1F1F3}');
    expect(callingCodeForRegion('cn')!.label, '\u{1F1E8}\u{1F1F3} +86');
  });

  test('callingCodeForRegion', () {
    expect(callingCodeForRegion('GB')!.code, '44');
    expect(callingCodeForRegion('ZZ'), isNull);
    expect(callingCodeForRegion(null), isNull);
  });

  test('table has unique ISO codes', () {
    final isos = callingCodes.map((c) => c.iso).toList();
    expect(isos.toSet().length, isos.length);
  });
}
