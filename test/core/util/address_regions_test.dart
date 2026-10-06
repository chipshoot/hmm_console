import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/util/address_regions.dart';

void main() {
  test('table sizes: US >= 51 (states + DC + territories), CA 13, CN 34', () {
    expect(regionsFor('US').length, greaterThanOrEqualTo(51));
    expect(regionsFor('US').length, 56, reason: '50 + DC + PR GU VI AS MP');
    expect(regionsFor('CA').length, 13);
    expect(regionsFor('CN').length, 34);
    expect(regionsFor('GB'), isEmpty);
    expect(regionsFor(null), isEmpty);
  });

  test('codes are unique within each country', () {
    for (final c in ['US', 'CA', 'CN']) {
      final codes = regionsFor(c).map((r) => r.code).toList();
      expect(codes.toSet().length, codes.length, reason: c);
    }
  });

  test('lookups by code', () {
    expect(findRegion('US', 'NY')!.name, 'New York');
    expect(findRegion('US', 'DC')!.name, 'District of Columbia');
    expect(findRegion('US', 'PR')!.name, 'Puerto Rico');
    expect(findRegion('CA', 'ON')!.name, 'Ontario');
    expect(findRegion('CA', 'NU')!.name, 'Nunavut');
    final gd = findRegion('CN', 'GD')!;
    expect(gd.nameZh, '广东省');
    expect(gd.pinyin, 'Guangdong');
    expect(findRegion('CN', 'SN')!.nameZh, '陕西省');
    expect(findRegion('CN', 'SX')!.nameZh, '山西省');
    expect(findRegion('US', 'ZZ'), isNull);
    expect(findRegion('CN', null), isNull);
  });

  test('display name: English for US/CA, Chinese for CN', () {
    expect(findRegion('US', 'CA')!.displayName, 'California');
    expect(findRegion('CN', 'BJ')!.displayName, '北京市');
  });

  group('search', () {
    List<String> codes(String c, String q) =>
        searchRegions(c, q).map((r) => r.code).toList();

    test('blank returns the whole table', () {
      expect(searchRegions('CA', '  ').length, 13);
    });

    test('by code, exact code first', () {
      expect(codes('US', 'ny').first, 'NY');
      expect(codes('CA', 'BC'), ['BC']);
    });

    test('by English name', () {
      expect(codes('US', 'york'), ['NY']);
      expect(codes('CA', 'scotia'), ['NS']);
      expect(codes('CN', 'inner mongolia'), ['NM']);
    });

    test('by Chinese name', () {
      expect(codes('CN', '广东'), ['GD']);
      expect(codes('CN', '新疆'), ['XJ']);
    });

    test('by pinyin, case- and space-insensitive', () {
      expect(codes('CN', 'guangdong'), ['GD']);
      expect(codes('CN', 'Hei Long'), ['HL']);
      expect(codes('CN', 'shaanxi'), ['SN']);
    });

    test('no match is empty', () {
      expect(codes('US', 'qqq'), isEmpty);
    });
  });
}
