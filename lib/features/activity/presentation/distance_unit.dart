import 'dart:ui';

/// Countries that measure road distance in miles.
const _mileCountries = {'US', 'GB', 'LR', 'MM'};

/// `'mi'` where distances are in miles, `'km'` everywhere else (and when
/// the locale has no country).
String defaultDistanceUnit(Locale locale) =>
    _mileCountries.contains(locale.countryCode?.toUpperCase()) ? 'mi' : 'km';
