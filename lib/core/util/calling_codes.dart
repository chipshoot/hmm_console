/// Country calling codes (ITU E.164) for the contact phone picker.
///
/// Pure Dart: no Flutter imports. Country names are reference data in
/// English, deliberately NOT translated UI copy; only the picker's title,
/// search hint and placeholder are localized.
library;

class CallingCode {
  const CallingCode(this.iso, this.code, this.name);

  /// ISO 3166-1 alpha-2 region code (`XK` is the user-assigned Kosovo code).
  final String iso;

  /// Digits only, without `+`.
  final String code;
  final String name;

  /// The flag and code, e.g. `+86` preceded by the China flag.
  String get label => '${flagEmoji(iso)} +$code';

  @override
  bool operator ==(Object other) =>
      other is CallingCode && other.iso == iso && other.code == code;

  @override
  int get hashCode => Object.hash(iso, code);
}

/// Regional-indicator flag emoji for an ISO alpha-2 code.
String flagEmoji(String iso) => String.fromCharCodes([
  for (final u in iso.toUpperCase().codeUnits) 0x1F1E6 + (u - 0x41),
]);

/// Region preferred when a bare code is shared by several regions.
const _primaryIso = {
  '1': 'US',
  '7': 'RU',
  '39': 'IT',
  '44': 'GB',
  '47': 'NO',
  '61': 'AU',
  '212': 'MA',
  '262': 'RE',
  '358': 'FI',
  '590': 'GP',
  '599': 'CW',
};

/// Every ITU-assigned region, alphabetical by name. Shared codes (+1, +7, ...)
/// list each region.
const List<CallingCode> callingCodes = [
  CallingCode('AF', '93', 'Afghanistan'),
  CallingCode('AL', '355', 'Albania'),
  CallingCode('DZ', '213', 'Algeria'),
  CallingCode('AS', '1', 'American Samoa'),
  CallingCode('AD', '376', 'Andorra'),
  CallingCode('AO', '244', 'Angola'),
  CallingCode('AI', '1', 'Anguilla'),
  CallingCode('AG', '1', 'Antigua and Barbuda'),
  CallingCode('AR', '54', 'Argentina'),
  CallingCode('AM', '374', 'Armenia'),
  CallingCode('AW', '297', 'Aruba'),
  CallingCode('AU', '61', 'Australia'),
  CallingCode('AT', '43', 'Austria'),
  CallingCode('AZ', '994', 'Azerbaijan'),
  CallingCode('BS', '1', 'Bahamas'),
  CallingCode('BH', '973', 'Bahrain'),
  CallingCode('BD', '880', 'Bangladesh'),
  CallingCode('BB', '1', 'Barbados'),
  CallingCode('BY', '375', 'Belarus'),
  CallingCode('BE', '32', 'Belgium'),
  CallingCode('BZ', '501', 'Belize'),
  CallingCode('BJ', '229', 'Benin'),
  CallingCode('BM', '1', 'Bermuda'),
  CallingCode('BT', '975', 'Bhutan'),
  CallingCode('BO', '591', 'Bolivia'),
  CallingCode('BQ', '599', 'Bonaire, Sint Eustatius and Saba'),
  CallingCode('BA', '387', 'Bosnia and Herzegovina'),
  CallingCode('BW', '267', 'Botswana'),
  CallingCode('BR', '55', 'Brazil'),
  CallingCode('VG', '1', 'British Virgin Islands'),
  CallingCode('BN', '673', 'Brunei'),
  CallingCode('BG', '359', 'Bulgaria'),
  CallingCode('BF', '226', 'Burkina Faso'),
  CallingCode('BI', '257', 'Burundi'),
  CallingCode('KH', '855', 'Cambodia'),
  CallingCode('CM', '237', 'Cameroon'),
  CallingCode('CA', '1', 'Canada'),
  CallingCode('CV', '238', 'Cape Verde'),
  CallingCode('KY', '1', 'Cayman Islands'),
  CallingCode('CF', '236', 'Central African Republic'),
  CallingCode('TD', '235', 'Chad'),
  CallingCode('CL', '56', 'Chile'),
  CallingCode('CN', '86', 'China'),
  CallingCode('CX', '61', 'Christmas Island'),
  CallingCode('CC', '61', 'Cocos (Keeling) Islands'),
  CallingCode('CO', '57', 'Colombia'),
  CallingCode('KM', '269', 'Comoros'),
  CallingCode('CG', '242', 'Congo'),
  CallingCode('CD', '243', 'Congo (Democratic Republic)'),
  CallingCode('CK', '682', 'Cook Islands'),
  CallingCode('CR', '506', 'Costa Rica'),
  CallingCode('CI', '225', 'Côte d\'Ivoire'),
  CallingCode('HR', '385', 'Croatia'),
  CallingCode('CU', '53', 'Cuba'),
  CallingCode('CW', '599', 'Curaçao'),
  CallingCode('CY', '357', 'Cyprus'),
  CallingCode('CZ', '420', 'Czechia'),
  CallingCode('DK', '45', 'Denmark'),
  CallingCode('DJ', '253', 'Djibouti'),
  CallingCode('DM', '1', 'Dominica'),
  CallingCode('DO', '1', 'Dominican Republic'),
  CallingCode('EC', '593', 'Ecuador'),
  CallingCode('EG', '20', 'Egypt'),
  CallingCode('SV', '503', 'El Salvador'),
  CallingCode('GQ', '240', 'Equatorial Guinea'),
  CallingCode('ER', '291', 'Eritrea'),
  CallingCode('EE', '372', 'Estonia'),
  CallingCode('SZ', '268', 'Eswatini'),
  CallingCode('ET', '251', 'Ethiopia'),
  CallingCode('FK', '500', 'Falkland Islands'),
  CallingCode('FO', '298', 'Faroe Islands'),
  CallingCode('FJ', '679', 'Fiji'),
  CallingCode('FI', '358', 'Finland'),
  CallingCode('FR', '33', 'France'),
  CallingCode('GF', '594', 'French Guiana'),
  CallingCode('PF', '689', 'French Polynesia'),
  CallingCode('GA', '241', 'Gabon'),
  CallingCode('GM', '220', 'Gambia'),
  CallingCode('GE', '995', 'Georgia'),
  CallingCode('DE', '49', 'Germany'),
  CallingCode('GH', '233', 'Ghana'),
  CallingCode('GI', '350', 'Gibraltar'),
  CallingCode('GR', '30', 'Greece'),
  CallingCode('GL', '299', 'Greenland'),
  CallingCode('GD', '1', 'Grenada'),
  CallingCode('GP', '590', 'Guadeloupe'),
  CallingCode('GU', '1', 'Guam'),
  CallingCode('GT', '502', 'Guatemala'),
  CallingCode('GG', '44', 'Guernsey'),
  CallingCode('GN', '224', 'Guinea'),
  CallingCode('GW', '245', 'Guinea-Bissau'),
  CallingCode('GY', '592', 'Guyana'),
  CallingCode('HT', '509', 'Haiti'),
  CallingCode('HN', '504', 'Honduras'),
  CallingCode('HK', '852', 'Hong Kong'),
  CallingCode('HU', '36', 'Hungary'),
  CallingCode('IS', '354', 'Iceland'),
  CallingCode('IN', '91', 'India'),
  CallingCode('ID', '62', 'Indonesia'),
  CallingCode('IR', '98', 'Iran'),
  CallingCode('IQ', '964', 'Iraq'),
  CallingCode('IE', '353', 'Ireland'),
  CallingCode('IM', '44', 'Isle of Man'),
  CallingCode('IL', '972', 'Israel'),
  CallingCode('IT', '39', 'Italy'),
  CallingCode('JM', '1', 'Jamaica'),
  CallingCode('JP', '81', 'Japan'),
  CallingCode('JE', '44', 'Jersey'),
  CallingCode('JO', '962', 'Jordan'),
  CallingCode('KZ', '7', 'Kazakhstan'),
  CallingCode('KE', '254', 'Kenya'),
  CallingCode('KI', '686', 'Kiribati'),
  CallingCode('XK', '383', 'Kosovo'),
  CallingCode('KW', '965', 'Kuwait'),
  CallingCode('KG', '996', 'Kyrgyzstan'),
  CallingCode('LA', '856', 'Laos'),
  CallingCode('LV', '371', 'Latvia'),
  CallingCode('LB', '961', 'Lebanon'),
  CallingCode('LS', '266', 'Lesotho'),
  CallingCode('LR', '231', 'Liberia'),
  CallingCode('LY', '218', 'Libya'),
  CallingCode('LI', '423', 'Liechtenstein'),
  CallingCode('LT', '370', 'Lithuania'),
  CallingCode('LU', '352', 'Luxembourg'),
  CallingCode('MO', '853', 'Macao'),
  CallingCode('MG', '261', 'Madagascar'),
  CallingCode('MW', '265', 'Malawi'),
  CallingCode('MY', '60', 'Malaysia'),
  CallingCode('MV', '960', 'Maldives'),
  CallingCode('ML', '223', 'Mali'),
  CallingCode('MT', '356', 'Malta'),
  CallingCode('MH', '692', 'Marshall Islands'),
  CallingCode('MQ', '596', 'Martinique'),
  CallingCode('MR', '222', 'Mauritania'),
  CallingCode('MU', '230', 'Mauritius'),
  CallingCode('YT', '262', 'Mayotte'),
  CallingCode('MX', '52', 'Mexico'),
  CallingCode('FM', '691', 'Micronesia'),
  CallingCode('MD', '373', 'Moldova'),
  CallingCode('MC', '377', 'Monaco'),
  CallingCode('MN', '976', 'Mongolia'),
  CallingCode('ME', '382', 'Montenegro'),
  CallingCode('MS', '1', 'Montserrat'),
  CallingCode('MA', '212', 'Morocco'),
  CallingCode('MZ', '258', 'Mozambique'),
  CallingCode('MM', '95', 'Myanmar'),
  CallingCode('NA', '264', 'Namibia'),
  CallingCode('NR', '674', 'Nauru'),
  CallingCode('NP', '977', 'Nepal'),
  CallingCode('NL', '31', 'Netherlands'),
  CallingCode('NC', '687', 'New Caledonia'),
  CallingCode('NZ', '64', 'New Zealand'),
  CallingCode('NI', '505', 'Nicaragua'),
  CallingCode('NE', '227', 'Niger'),
  CallingCode('NG', '234', 'Nigeria'),
  CallingCode('NU', '683', 'Niue'),
  CallingCode('NF', '672', 'Norfolk Island'),
  CallingCode('KP', '850', 'North Korea'),
  CallingCode('MK', '389', 'North Macedonia'),
  CallingCode('MP', '1', 'Northern Mariana Islands'),
  CallingCode('NO', '47', 'Norway'),
  CallingCode('OM', '968', 'Oman'),
  CallingCode('PK', '92', 'Pakistan'),
  CallingCode('PW', '680', 'Palau'),
  CallingCode('PS', '970', 'Palestine'),
  CallingCode('PA', '507', 'Panama'),
  CallingCode('PG', '675', 'Papua New Guinea'),
  CallingCode('PY', '595', 'Paraguay'),
  CallingCode('PE', '51', 'Peru'),
  CallingCode('PH', '63', 'Philippines'),
  CallingCode('PL', '48', 'Poland'),
  CallingCode('PT', '351', 'Portugal'),
  CallingCode('PR', '1', 'Puerto Rico'),
  CallingCode('QA', '974', 'Qatar'),
  CallingCode('RE', '262', 'Réunion'),
  CallingCode('RO', '40', 'Romania'),
  CallingCode('RU', '7', 'Russia'),
  CallingCode('RW', '250', 'Rwanda'),
  CallingCode('BL', '590', 'Saint Barthélemy'),
  CallingCode('SH', '290', 'Saint Helena'),
  CallingCode('KN', '1', 'Saint Kitts and Nevis'),
  CallingCode('LC', '1', 'Saint Lucia'),
  CallingCode('MF', '590', 'Saint Martin'),
  CallingCode('PM', '508', 'Saint Pierre and Miquelon'),
  CallingCode('VC', '1', 'Saint Vincent and the Grenadines'),
  CallingCode('WS', '685', 'Samoa'),
  CallingCode('SM', '378', 'San Marino'),
  CallingCode('ST', '239', 'São Tomé and Príncipe'),
  CallingCode('SA', '966', 'Saudi Arabia'),
  CallingCode('SN', '221', 'Senegal'),
  CallingCode('RS', '381', 'Serbia'),
  CallingCode('SC', '248', 'Seychelles'),
  CallingCode('SL', '232', 'Sierra Leone'),
  CallingCode('SG', '65', 'Singapore'),
  CallingCode('SX', '1', 'Sint Maarten'),
  CallingCode('SK', '421', 'Slovakia'),
  CallingCode('SI', '386', 'Slovenia'),
  CallingCode('SB', '677', 'Solomon Islands'),
  CallingCode('SO', '252', 'Somalia'),
  CallingCode('ZA', '27', 'South Africa'),
  CallingCode('KR', '82', 'South Korea'),
  CallingCode('SS', '211', 'South Sudan'),
  CallingCode('ES', '34', 'Spain'),
  CallingCode('LK', '94', 'Sri Lanka'),
  CallingCode('SD', '249', 'Sudan'),
  CallingCode('SR', '597', 'Suriname'),
  CallingCode('SJ', '47', 'Svalbard and Jan Mayen'),
  CallingCode('SE', '46', 'Sweden'),
  CallingCode('CH', '41', 'Switzerland'),
  CallingCode('SY', '963', 'Syria'),
  CallingCode('TW', '886', 'Taiwan'),
  CallingCode('TJ', '992', 'Tajikistan'),
  CallingCode('TZ', '255', 'Tanzania'),
  CallingCode('TH', '66', 'Thailand'),
  CallingCode('TL', '670', 'Timor-Leste'),
  CallingCode('TG', '228', 'Togo'),
  CallingCode('TK', '690', 'Tokelau'),
  CallingCode('TO', '676', 'Tonga'),
  CallingCode('TT', '1', 'Trinidad and Tobago'),
  CallingCode('TN', '216', 'Tunisia'),
  CallingCode('TR', '90', 'Türkiye'),
  CallingCode('TM', '993', 'Turkmenistan'),
  CallingCode('TC', '1', 'Turks and Caicos Islands'),
  CallingCode('TV', '688', 'Tuvalu'),
  CallingCode('VI', '1', 'US Virgin Islands'),
  CallingCode('UG', '256', 'Uganda'),
  CallingCode('UA', '380', 'Ukraine'),
  CallingCode('AE', '971', 'United Arab Emirates'),
  CallingCode('GB', '44', 'United Kingdom'),
  CallingCode('US', '1', 'United States'),
  CallingCode('UY', '598', 'Uruguay'),
  CallingCode('UZ', '998', 'Uzbekistan'),
  CallingCode('VU', '678', 'Vanuatu'),
  CallingCode('VA', '39', 'Vatican City'),
  CallingCode('VE', '58', 'Venezuela'),
  CallingCode('VN', '84', 'Vietnam'),
  CallingCode('WF', '681', 'Wallis and Futuna'),
  CallingCode('EH', '212', 'Western Sahara'),
  CallingCode('YE', '967', 'Yemen'),
  CallingCode('ZM', '260', 'Zambia'),
  CallingCode('ZW', '263', 'Zimbabwe'),
  CallingCode('AX', '358', 'Åland Islands'),
];

final Map<String, CallingCode> _byIso = {
  for (final c in callingCodes) c.iso: c,
};

final Map<String, CallingCode> _primaryByCode = () {
  final m = <String, CallingCode>{};
  for (final c in callingCodes) {
    m.putIfAbsent(c.code, () => c);
  }
  _primaryIso.forEach((code, iso) => m[code] = _byIso[iso]!);
  return m;
}();

/// The calling code of an ISO region, or null when unknown.
CallingCode? callingCodeForRegion(String? iso) =>
    iso == null ? null : _byIso[iso.toUpperCase()];

/// The primary region for a bare calling code (`1` -> US), or null.
CallingCode? primaryCallingCode(String code) => _primaryByCode[code];

/// Splits `+<code><rest>` by longest-prefix match (1-3 digits). Returns null
/// when [input] does not start with `+` or the code is not in the table. The
/// national part has its leading separators removed.
({CallingCode code, String national})? splitInternationalNumber(String input) {
  final s = input.trimLeft();
  if (!s.startsWith('+')) return null;
  final digits = RegExp(r'^\d{1,3}').stringMatch(s.substring(1)) ?? '';
  for (var n = digits.length; n >= 1; n--) {
    final hit = _primaryByCode[digits.substring(0, n)];
    if (hit != null) {
      final rest = s.substring(1 + n).replaceFirst(RegExp(r'^[\s\-.]+'), '');
      return (code: hit, national: rest);
    }
  }
  return null;
}

/// Matches calling-code digits (prefix, with or without `+`), ISO code, and
/// English name. A blank query returns the whole table; an exact ISO match
/// sorts first.
List<CallingCode> searchCallingCodes(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return callingCodes;
  final digits = q.startsWith('+') ? q.substring(1) : q;
  if (digits.isNotEmpty && RegExp(r'^\d+$').hasMatch(digits)) {
    return [
      for (final c in callingCodes)
        if (c.code.startsWith(digits)) c,
    ];
  }
  final hits = [
    for (final c in callingCodes)
      if (c.iso.toLowerCase() == q || c.name.toLowerCase().contains(q)) c,
  ];
  hits.sort((a, b) {
    final ea = a.iso.toLowerCase() == q ? 0 : 1;
    final eb = b.iso.toLowerCase() == q ? 0 : 1;
    return ea - eb;
  });
  return hits;
}
