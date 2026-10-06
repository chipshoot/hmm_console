import '../../../core/util/address_regions.dart';
import 'entities/contact_field.dart';

/// Country-aware postal address formatting and postal-code rules.
///
/// Pure Dart: no Flutter imports. The country names written into an address
/// (`United States`, `Canada`, `中国`) are part of the postal format, not UI
/// copy, so they do not follow the app language: a Chinese address always
/// reads big-to-small in Chinese.

/// Countries whose structured format this version knows.
const knownAddressCountries = ['US', 'CA', 'CN'];

String? _t(String? s) {
  final v = s?.trim() ?? '';
  return v.isEmpty ? null : v;
}

String _join(Iterable<String?> parts, String sep) =>
    parts.whereType<String>().where((p) => p.isNotEmpty).join(sep);

/// The address as display lines. A free-form address returns its stored
/// text; a structured one with no part filled in returns ''.
String formatMultiline(ContactAddress a) =>
    a.country == null ? a.value : _lines(a).join('\n');

/// The canonical single-line form stored in `ContactAddress.value` for a
/// structured address: the lines joined with ", " (spaces for CN).
String formatSingleLine(ContactAddress a) {
  if (a.country == null) return a.value;
  return _lines(a).join(a.country == 'CN' ? ' ' : ', ');
}

List<String> _lines(ContactAddress a) {
  final street1 = _t(a.street1);
  final street2 = _t(a.street2);
  final city = _t(a.city);
  final district = _t(a.district);
  final regionCode = _t(a.region);
  final postal = _t(a.postalCode);
  final region = findRegion(a.country, regionCode);
  final hasParts = [
    street1,
    street2,
    city,
    district,
    regionCode,
    postal,
  ].any((p) => p != null);

  switch (a.country) {
    case 'CN':
      if (!_hasCnParts(a)) return const [];
      final head = _join([
        '中国',
        region?.displayName ?? regionCode,
        city,
        district,
      ], ' ');
      return [head, ?street1, if (postal != null) '邮编 $postal'];
    case 'US':
      if (!hasParts) return const [];
      final last = _join([
        city,
        _join([regionCode, postal], ' '),
      ], ', ');
      return [?street1, ?street2, if (last.isNotEmpty) last, 'United States'];
    case 'CA':
      if (!hasParts) return const [];
      final last = _join([city, regionCode, postal], ' ');
      return [?street1, ?street2, if (last.isNotEmpty) last, 'Canada'];
    default:
      // A country this version does not know (a newer client's): show the
      // parts it does model, generic order, plus the code.
      if (!hasParts) return const [];
      final last = _join([city, district, regionCode, postal], ' ');
      return [?street1, ?street2, if (last.isNotEmpty) last, a.country!];
  }
}

bool _hasCnParts(ContactAddress a) => [
  a.street1,
  a.city,
  a.district,
  a.region,
  a.postalCode,
].any((p) => _t(p) != null);

final _postalPatterns = {
  'US': RegExp(r'^\d{5}(-\d{4})?$'),
  'CA': RegExp(r'^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$'),
  'CN': RegExp(r'^\d{6}$'),
};

/// False only for a non-blank postal code that breaks its country's format.
bool isValidPostalCode(String? country, String postal) {
  final t = postal.trim();
  if (t.isEmpty) return true;
  final p = _postalPatterns[country];
  return p == null || p.hasMatch(t);
}

/// Trimmed; a valid Canadian code becomes `A1A 1A1` uppercase. An invalid
/// code is returned trimmed but otherwise as typed.
String normalizePostalCode(String? country, String postal) {
  final t = postal.trim();
  if (country == 'CA' && isValidPostalCode('CA', t)) {
    final compact = t.toUpperCase().replaceAll(RegExp(r'[ -]'), '');
    return '${compact.substring(0, 3)} ${compact.substring(3)}';
  }
  return t;
}

/// [a] with `value` re-derived from its parts (`formatSingleLine`). A
/// free-form address is returned unchanged. Called by the editor when a
/// structured address is edited; the codec never re-derives, so an untouched
/// address is written back exactly as stored.
ContactAddress withDerivedValue(ContactAddress a) => a.country == null
    ? a
    : ContactAddress(
        label: a.label,
        value: formatSingleLine(a),
        country: a.country,
        street1: a.street1,
        street2: a.street2,
        city: a.city,
        district: a.district,
        region: a.region,
        postalCode: a.postalCode,
        extraFields: a.extraFields,
        rawKnownValues: a.rawKnownValues,
      );
