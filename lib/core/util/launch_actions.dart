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

/// A maps URL for [address].
///
/// `https://maps.apple.com` rather than a `geo:` scheme so there is always a
/// handler: iOS and macOS open Maps natively, and everywhere else it resolves
/// in a browser instead of failing to launch.
Uri mapsUri(String address) => Uri.parse(
      'https://maps.apple.com/?q=${Uri.encodeComponent(address.trim())}',
    );
