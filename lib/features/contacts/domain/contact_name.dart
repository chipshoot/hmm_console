// lib/features/contacts/domain/contact_name.dart
import 'entities/contact.dart';

/// Every rule about how a contact's name parts are ordered and joined.
/// Nothing outside this file re-implements ordering: `Contact.displayName`,
/// the list, the detail screen, the codec and cheatsheet cards all come here.
///
/// `Contact.firstName` is the GIVEN name and `Contact.lastName` the FAMILY
/// name; the stored keys keep their historical names.
abstract final class ContactName {
  /// Han ideographs: CJK Extension A, Unified, Compatibility, and the
  /// supplementary planes (Extensions B and later, Compatibility Supplement).
  static bool isHanRune(int r) =>
      (r >= 0x3400 && r <= 0x4DBF) ||
      (r >= 0x4E00 && r <= 0x9FFF) ||
      (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0x20000 && r <= 0x2FA1F);

  /// Iterates runes, not UTF-16 units, so Extension B (`𠮷`) counts.
  static bool hasChinese(String? s) => s != null && s.runes.any(isHanRune);

  /// [s] split into maximal runs of Han and non-Han text, in order.
  static List<(bool han, String text)> hanRuns(String s) {
    final out = <(bool, String)>[];
    final buf = StringBuffer();
    bool? current;
    for (final r in s.runes) {
      final han = isHanRune(r);
      if (current != null && han != current) {
        out.add((current, buf.toString()));
        buf.clear();
      }
      current = han;
      buf.writeCharCode(r);
    }
    if (current != null) out.add((current, buf.toString()));
    return out;
  }

  /// The override if set; under Auto, family-first when either part contains
  /// a Han character. Never returns [ContactNameOrder.auto].
  static ContactNameOrder effectiveOrder(Contact c) => switch (c.nameOrder) {
    ContactNameOrder.givenFirst => ContactNameOrder.givenFirst,
    ContactNameOrder.familyFirst => ContactNameOrder.familyFirst,
    ContactNameOrder.auto =>
      hasChinese(c.lastName) || hasChinese(c.firstName)
          ? ContactNameOrder.familyFirst
          : ContactNameOrder.givenFirst,
  };

  /// Organizations show [Contact.organizationName]. People show their parts
  /// in [effectiveOrder]; family-first joins with no space only when BOTH
  /// parts contain Chinese. Each part is trimmed (Dart's trim includes
  /// U+3000); a space inside a part is kept as typed.
  static String displayName(Contact c) {
    if (c.contactType == ContactType.organization) {
      return c.organizationName ?? '';
    }
    final given = c.firstName?.trim() ?? '';
    final family = c.lastName?.trim() ?? '';
    if (given.isEmpty) return family;
    if (family.isEmpty) return given;
    return switch (effectiveOrder(c)) {
      ContactNameOrder.familyFirst =>
        hasChinese(family) && hasChinese(given)
            ? '$family$given'
            : '$family $given',
      _ => '$given $family',
    };
  }

  static final _phonetic = RegExp(
    "^[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùüǖǘǚǜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙÜǕǗǙǛ '’　]*\$",
  );

  /// Latin letters (tone marks and ü included), spaces and apostrophes
  /// (straight or iOS's curly U+2019). Checked after trimming; empty is valid.
  static bool isValidPhonetic(String s) => _phonetic.hasMatch(s.trim());
}
