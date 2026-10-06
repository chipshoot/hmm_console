/// First-level administrative regions for the countries whose postal address
/// format the contact editor knows: United States, Canada and China.
///
/// Pure Dart: no Flutter imports. Names here are REFERENCE DATA, not UI copy:
/// US and Canadian regions carry their English names, Chinese provinces their
/// official Chinese names plus pinyin and English for search. They are not
/// translated by locale.
///
/// Codes are what a contact address stores in `region`:
/// * US: USPS two-letter codes (50 states, DC and the inhabited territories).
/// * CA: Canada Post two-letter codes (10 provinces, 3 territories).
/// * CN: the subdivision part of ISO 3166-2:CN as revised in 2017 (`GD` for
///   CN-GD Guangdong, `SN` for CN-SN Shaanxi, `HK` for CN-HK, ...), all 34
///   provincial-level divisions.
library;

class AddressRegion {
  const AddressRegion(this.code, this.name, {this.nameZh, this.pinyin});

  /// Stored code, e.g. `NY`, `ON`, `GD`.
  final String code;

  /// English name.
  final String name;

  /// Chinese name (CN only), e.g. `广东省`.
  final String? nameZh;

  /// Pinyin (CN only), e.g. `Guangdong`.
  final String? pinyin;

  /// The name an address shows: Chinese for CN, English otherwise.
  String get displayName => nameZh ?? name;
}

const List<AddressRegion> usRegions = [
  AddressRegion('AL', 'Alabama'),
  AddressRegion('AK', 'Alaska'),
  AddressRegion('AZ', 'Arizona'),
  AddressRegion('AR', 'Arkansas'),
  AddressRegion('CA', 'California'),
  AddressRegion('CO', 'Colorado'),
  AddressRegion('CT', 'Connecticut'),
  AddressRegion('DE', 'Delaware'),
  AddressRegion('DC', 'District of Columbia'),
  AddressRegion('FL', 'Florida'),
  AddressRegion('GA', 'Georgia'),
  AddressRegion('HI', 'Hawaii'),
  AddressRegion('ID', 'Idaho'),
  AddressRegion('IL', 'Illinois'),
  AddressRegion('IN', 'Indiana'),
  AddressRegion('IA', 'Iowa'),
  AddressRegion('KS', 'Kansas'),
  AddressRegion('KY', 'Kentucky'),
  AddressRegion('LA', 'Louisiana'),
  AddressRegion('ME', 'Maine'),
  AddressRegion('MD', 'Maryland'),
  AddressRegion('MA', 'Massachusetts'),
  AddressRegion('MI', 'Michigan'),
  AddressRegion('MN', 'Minnesota'),
  AddressRegion('MS', 'Mississippi'),
  AddressRegion('MO', 'Missouri'),
  AddressRegion('MT', 'Montana'),
  AddressRegion('NE', 'Nebraska'),
  AddressRegion('NV', 'Nevada'),
  AddressRegion('NH', 'New Hampshire'),
  AddressRegion('NJ', 'New Jersey'),
  AddressRegion('NM', 'New Mexico'),
  AddressRegion('NY', 'New York'),
  AddressRegion('NC', 'North Carolina'),
  AddressRegion('ND', 'North Dakota'),
  AddressRegion('OH', 'Ohio'),
  AddressRegion('OK', 'Oklahoma'),
  AddressRegion('OR', 'Oregon'),
  AddressRegion('PA', 'Pennsylvania'),
  AddressRegion('RI', 'Rhode Island'),
  AddressRegion('SC', 'South Carolina'),
  AddressRegion('SD', 'South Dakota'),
  AddressRegion('TN', 'Tennessee'),
  AddressRegion('TX', 'Texas'),
  AddressRegion('UT', 'Utah'),
  AddressRegion('VT', 'Vermont'),
  AddressRegion('VA', 'Virginia'),
  AddressRegion('WA', 'Washington'),
  AddressRegion('WV', 'West Virginia'),
  AddressRegion('WI', 'Wisconsin'),
  AddressRegion('WY', 'Wyoming'),
  AddressRegion('AS', 'American Samoa'),
  AddressRegion('GU', 'Guam'),
  AddressRegion('MP', 'Northern Mariana Islands'),
  AddressRegion('PR', 'Puerto Rico'),
  AddressRegion('VI', 'U.S. Virgin Islands'),
];

const List<AddressRegion> caRegions = [
  AddressRegion('AB', 'Alberta'),
  AddressRegion('BC', 'British Columbia'),
  AddressRegion('MB', 'Manitoba'),
  AddressRegion('NB', 'New Brunswick'),
  AddressRegion('NL', 'Newfoundland and Labrador'),
  AddressRegion('NS', 'Nova Scotia'),
  AddressRegion('ON', 'Ontario'),
  AddressRegion('PE', 'Prince Edward Island'),
  AddressRegion('QC', 'Quebec'),
  AddressRegion('SK', 'Saskatchewan'),
  AddressRegion('NT', 'Northwest Territories'),
  AddressRegion('NU', 'Nunavut'),
  AddressRegion('YT', 'Yukon'),
];

const List<AddressRegion> cnRegions = [
  AddressRegion('BJ', 'Beijing', nameZh: '北京市', pinyin: 'Beijing'),
  AddressRegion('TJ', 'Tianjin', nameZh: '天津市', pinyin: 'Tianjin'),
  AddressRegion('HE', 'Hebei', nameZh: '河北省', pinyin: 'Hebei'),
  AddressRegion('SX', 'Shanxi', nameZh: '山西省', pinyin: 'Shanxi'),
  AddressRegion('NM', 'Inner Mongolia', nameZh: '内蒙古自治区', pinyin: 'Neimenggu'),
  AddressRegion('LN', 'Liaoning', nameZh: '辽宁省', pinyin: 'Liaoning'),
  AddressRegion('JL', 'Jilin', nameZh: '吉林省', pinyin: 'Jilin'),
  AddressRegion('HL', 'Heilongjiang', nameZh: '黑龙江省', pinyin: 'Heilongjiang'),
  AddressRegion('SH', 'Shanghai', nameZh: '上海市', pinyin: 'Shanghai'),
  AddressRegion('JS', 'Jiangsu', nameZh: '江苏省', pinyin: 'Jiangsu'),
  AddressRegion('ZJ', 'Zhejiang', nameZh: '浙江省', pinyin: 'Zhejiang'),
  AddressRegion('AH', 'Anhui', nameZh: '安徽省', pinyin: 'Anhui'),
  AddressRegion('FJ', 'Fujian', nameZh: '福建省', pinyin: 'Fujian'),
  AddressRegion('JX', 'Jiangxi', nameZh: '江西省', pinyin: 'Jiangxi'),
  AddressRegion('SD', 'Shandong', nameZh: '山东省', pinyin: 'Shandong'),
  AddressRegion('HA', 'Henan', nameZh: '河南省', pinyin: 'Henan'),
  AddressRegion('HB', 'Hubei', nameZh: '湖北省', pinyin: 'Hubei'),
  AddressRegion('HN', 'Hunan', nameZh: '湖南省', pinyin: 'Hunan'),
  AddressRegion('GD', 'Guangdong', nameZh: '广东省', pinyin: 'Guangdong'),
  AddressRegion('GX', 'Guangxi', nameZh: '广西壮族自治区', pinyin: 'Guangxi'),
  AddressRegion('HI', 'Hainan', nameZh: '海南省', pinyin: 'Hainan'),
  AddressRegion('CQ', 'Chongqing', nameZh: '重庆市', pinyin: 'Chongqing'),
  AddressRegion('SC', 'Sichuan', nameZh: '四川省', pinyin: 'Sichuan'),
  AddressRegion('GZ', 'Guizhou', nameZh: '贵州省', pinyin: 'Guizhou'),
  AddressRegion('YN', 'Yunnan', nameZh: '云南省', pinyin: 'Yunnan'),
  AddressRegion('XZ', 'Tibet', nameZh: '西藏自治区', pinyin: 'Xizang'),
  AddressRegion('SN', 'Shaanxi', nameZh: '陕西省', pinyin: 'Shaanxi'),
  AddressRegion('GS', 'Gansu', nameZh: '甘肃省', pinyin: 'Gansu'),
  AddressRegion('QH', 'Qinghai', nameZh: '青海省', pinyin: 'Qinghai'),
  AddressRegion('NX', 'Ningxia', nameZh: '宁夏回族自治区', pinyin: 'Ningxia'),
  AddressRegion('XJ', 'Xinjiang', nameZh: '新疆维吾尔自治区', pinyin: 'Xinjiang'),
  AddressRegion('TW', 'Taiwan', nameZh: '台湾省', pinyin: 'Taiwan'),
  AddressRegion('HK', 'Hong Kong', nameZh: '香港特别行政区', pinyin: 'Xianggang'),
  AddressRegion('MO', 'Macao', nameZh: '澳门特别行政区', pinyin: 'Aomen'),
];

/// The region table for an ISO country code, or empty for any other country.
List<AddressRegion> regionsFor(String? country) => switch (country) {
  'US' => usRegions,
  'CA' => caRegions,
  'CN' => cnRegions,
  _ => const [],
};

AddressRegion? findRegion(String? country, String? code) {
  if (code == null) return null;
  for (final r in regionsFor(country)) {
    if (r.code == code) return r;
  }
  return null;
}

String _fold(String s) => s.toLowerCase().replaceAll(' ', '');

/// Matches code, English name, Chinese name and pinyin (case- and
/// space-insensitive). A blank query returns the whole table; an exact code
/// match sorts first.
List<AddressRegion> searchRegions(String? country, String query) {
  final all = regionsFor(country);
  final q = _fold(query.trim());
  if (q.isEmpty) return all;
  bool hit(AddressRegion r) =>
      _fold(r.code) == q ||
      _fold(r.name).contains(q) ||
      (r.nameZh?.contains(q) ?? false) ||
      (r.pinyin != null && _fold(r.pinyin!).contains(q));
  final hits = [
    for (final r in all)
      if (hit(r)) r,
  ];
  hits.sort((a, b) {
    final ea = _fold(a.code) == q ? 0 : 1;
    final eb = _fold(b.code) == q ? 0 : 1;
    return ea - eb;
  });
  return hits;
}
