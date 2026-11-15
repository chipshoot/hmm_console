/// URI builders for the external actions a value can carry (dial it, map it).
///
/// Deliberately free of any feature types so `core` doesn't depend on a
/// feature: the `ValueAction` dispatch lives in
/// `features/cheatsheet/data/cheatsheet_launcher.dart`.
library;

final _nonDigits = RegExp(r'[^0-9]');

/// `tel:` for [phone], stripped of the punctuation people write numbers with.
///
/// A leading `+` survives because it is the international prefix, not
/// decoration; a `+` anywhere else is decoration.
///
/// Dialling stops at the first extension marker (`x`, `ext`, `,`, `;`, `#`):
/// digits after it belong to the extension, not the number.
Uri telUri(String phone) {
  var trimmed = phone.trim();
  final cut = trimmed.indexOf(RegExp(r'[xX,;#]'));
  if (cut >= 0) trimmed = trimmed.substring(0, cut);
  final international = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(_nonDigits, '');
  return Uri.parse('tel:${international ? '+' : ''}$digits');
}

/// Chinese (Han) characters, including the CJK extension A block.
final _han = RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF]');

/// A maps URL for [address].
///
/// An address written with Chinese characters opens Google Maps: Apple Maps
/// search can't find Chinese street addresses and reads "中国" as Japan's
/// Chūgoku region (a Shanghai address landed in Okayama). Everything else
/// opens Apple Maps.
///
/// Both are `https` rather than a `geo:` scheme so there is always a handler:
/// the Google Maps link opens the Google Maps app when it is installed, Apple
/// Maps opens natively on iOS and macOS, and anything else resolves in a
/// browser instead of failing to launch.
Uri mapsUri(String address) {
  final query = address.trim();
  if (_han.hasMatch(query)) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }
  return Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(query)}');
}
