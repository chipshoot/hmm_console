import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/contacts/domain/address_format.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_field.dart';

void main() {
  const us = ContactAddress(
    label: 'home',
    value: '',
    country: 'US',
    street1: '1 Main St',
    street2: 'Apt 4B',
    city: 'Springfield',
    region: 'IL',
    postalCode: '62701',
  );
  const ca = ContactAddress(
    label: 'home',
    value: '',
    country: 'CA',
    street1: '24 Sussex Dr',
    city: 'Ottawa',
    region: 'ON',
    postalCode: 'K1M 1M4',
  );
  const cn = ContactAddress(
    label: 'home',
    value: '',
    country: 'CN',
    region: 'GD',
    city: '深圳市',
    district: '南山区',
    street1: '科技园路1号 3栋 1201室',
    postalCode: '518000',
  );

  group('formatMultiline', () {
    test('US', () {
      expect(
        formatMultiline(us),
        '1 Main St\nApt 4B\nSpringfield, IL 62701\nUnited States',
      );
    });

    test('CA', () {
      expect(formatMultiline(ca), '24 Sussex Dr\nOttawa ON K1M 1M4\nCanada');
    });

    test('CN: big to small, Chinese names', () {
      expect(formatMultiline(cn), '中国 广东省 深圳市 南山区\n科技园路1号 3栋 1201室\n邮编 518000');
    });

    test('empty parts are omitted', () {
      const a = ContactAddress(
        label: 'home',
        value: '',
        country: 'US',
        city: 'Springfield',
        postalCode: '62701',
      );
      expect(formatMultiline(a), 'Springfield, 62701\nUnited States');
      const b = ContactAddress(
        label: 'home',
        value: '',
        country: 'US',
        region: 'IL',
      );
      expect(formatMultiline(b), 'IL\nUnited States');
      const c = ContactAddress(
        label: 'home',
        value: '',
        country: 'CN',
        region: 'BJ',
        street1: '长安街1号',
      );
      expect(formatMultiline(c), '中国 北京市\n长安街1号');
      const blank = ContactAddress(
        label: 'home',
        value: '',
        country: 'CA',
        street1: '  ',
      );
      expect(formatMultiline(blank), '', reason: 'country alone is empty');
    });

    test('an unknown region code is shown as stored', () {
      const a = ContactAddress(
        label: 'home',
        value: '',
        country: 'CN',
        region: 'ZZ',
        city: '某市',
      );
      expect(formatMultiline(a), '中国 ZZ 某市');
    });

    test('free-form returns the stored text', () {
      const a = ContactAddress(label: 'home', value: '10 Downing St\nLondon');
      expect(formatMultiline(a), '10 Downing St\nLondon');
    });
  });

  group('formatSingleLine', () {
    test('US and CA join lines with ", "', () {
      expect(
        formatSingleLine(us),
        '1 Main St, Apt 4B, Springfield, IL 62701, United States',
      );
      expect(formatSingleLine(ca), '24 Sussex Dr, Ottawa ON K1M 1M4, Canada');
    });

    test('CN joins with spaces, no commas', () {
      expect(formatSingleLine(cn), '中国 广东省 深圳市 南山区 科技园路1号 3栋 1201室 邮编 518000');
    });

    test('CN uses Chinese names whatever the region code', () {
      const a = ContactAddress(
        label: 'home',
        value: '',
        country: 'CN',
        region: 'NM',
      );
      expect(formatSingleLine(a), '中国 内蒙古自治区');
    });
  });

  group('postal codes', () {
    test('US: 5 digits or ZIP+4', () {
      expect(isValidPostalCode('US', '62701'), isTrue);
      expect(isValidPostalCode('US', '62701-1234'), isTrue);
      expect(isValidPostalCode('US', '6270'), isFalse);
      expect(isValidPostalCode('US', '62701-12'), isFalse);
    });

    test('CA: A1A 1A1 with optional space or dash, any case', () {
      expect(isValidPostalCode('CA', 'K1M 1M4'), isTrue);
      expect(isValidPostalCode('CA', 'k1m1m4'), isTrue);
      expect(isValidPostalCode('CA', 'K1M-1M4'), isTrue);
      expect(isValidPostalCode('CA', 'K1M 1M'), isFalse);
      expect(isValidPostalCode('CA', '123 456'), isFalse);
    });

    test('CN: 6 digits', () {
      expect(isValidPostalCode('CN', '518000'), isTrue);
      expect(isValidPostalCode('CN', '51800'), isFalse);
    });

    test('blank and unknown countries are never invalid', () {
      expect(isValidPostalCode('US', ''), isTrue);
      expect(isValidPostalCode('US', '  '), isTrue);
      expect(isValidPostalCode(null, 'anything'), isTrue);
      expect(isValidPostalCode('GB', 'SW1A 2AA'), isTrue);
    });

    test('normalize: CA becomes A1A 1A1 uppercase; others trimmed', () {
      expect(normalizePostalCode('CA', 'k1m1m4'), 'K1M 1M4');
      expect(normalizePostalCode('CA', 'k1m-1m4'), 'K1M 1M4');
      expect(normalizePostalCode('US', ' 62701 '), '62701');
      expect(normalizePostalCode('CA', 'bad'), 'bad', reason: 'invalid kept');
    });
  });

  group('displayAddress', () {
    test('known country with parts: the multi-line form', () {
      expect(displayAddress(us), formatMultiline(us));
    });

    test('known country with no modelled parts: the stored value', () {
      const a = ContactAddress(
        label: 'home',
        value: '1 Main St, Springfield',
        country: 'US',
      );
      expect(displayAddress(a), '1 Main St, Springfield');
    });

    test('unknown country: the stored value, even with parts', () {
      const a = ContactAddress(
        label: 'home',
        value: '10 Downing St, London SW1A 2AA',
        country: 'GB',
        city: 'London',
      );
      expect(displayAddress(a), '10 Downing St, London SW1A 2AA');
    });

    test('free-form: the stored value', () {
      const a = ContactAddress(label: 'home', value: 'a\nb');
      expect(displayAddress(a), 'a\nb');
    });
  });
}
