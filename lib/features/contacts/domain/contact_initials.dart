import 'entities/contact.dart';

final _cjk = RegExp(r'[぀-ヿ㐀-鿿가-힯]');

/// Initials for a contact without a photo: the first character of a CJK
/// name, the organization's first letter, or the given then family initial.
/// Null when there is no usable name (callers show a person icon).
String? contactInitials(Contact c) {
  final display = c.displayName.trim();
  if (display.isEmpty) return null;
  final first = String.fromCharCode(display.runes.first);
  if (_cjk.hasMatch(first)) return first;
  String initial(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? '' : String.fromCharCode(t.runes.first).toUpperCase();
  }

  final out = c.contactType == ContactType.organization
      ? initial(c.organizationName)
      : initial(c.firstName) + initial(c.lastName);
  return out.isEmpty ? first.toUpperCase() : out;
}
