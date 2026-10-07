// lib/features/contacts/domain/contact_sort.dart
import 'contact_name.dart';
import 'contact_sort_by.dart';
import 'entities/contact.dart';
import 'pinyin_transcriber.dart';

final _ws = RegExp(r'\s+');
final _apostrophes = RegExp("['’]");
final _phoneNoise = RegExp(r'[\s\-.()]');

const _fold = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ǎ': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ě': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ǐ': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ǒ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ǔ': 'u',
  'ǖ': 'u', 'ǘ': 'u', 'ǚ': 'u', 'ǜ': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
  // The key separator; a typed `|` must not split a sort key.
  '|': ' ',
};

/// Lowercase, accent-folded, whitespace (U+3000 included) collapsed and
/// trimmed. Used for sort keys, search terms and queries alike.
String normalizeForSearch(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(_fold[ch] ?? ch);
  }
  return b.toString().replaceAll(_ws, ' ').trim();
}

List<String> _words(String s, {bool vForUmlaut = false}) =>
    normalizeForSearch(vForUmlaut ? _umlautToV(s) : s)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

/// Pinyin input methods type ü as `v` (lü is `lv`).
String _umlautToV(String s) =>
    s.toLowerCase().replaceAll(RegExp('[üǖǘǚǜ]'), 'v');

/// The part's romanized syllables: the phonetic field when set, else the
/// transcriber's output when the part contains Chinese. Null when neither
/// applies or the transcriber threw (reported to [onError]).
List<String>? _syllables(
  String part,
  String? phonetic,
  bool family,
  PinyinTranscriber? t,
  void Function(Object error)? onError, {
  bool vForUmlaut = false,
}) {
  final ph = phonetic?.trim() ?? '';
  if (ph.isNotEmpty) {
    return _words(ph.replaceAll(_apostrophes, ' '), vForUmlaut: vForUmlaut);
  }
  if (t == null || !ContactName.hasChinese(part)) return null;
  try {
    return [
      for (final s in family ? t.family(part) : t.given(part)) ..._words(s, vForUmlaut: vForUmlaut),
    ];
  } catch (e) {
    onError?.call(e);
    return null;
  }
}

String _sortPart(
  String part,
  String? phonetic,
  bool family,
  PinyinTranscriber? t,
  void Function(Object error)? onError,
) =>
    _syllables(part, phonetic, family, t, onError)?.join(' ') ??
    normalizeForSearch(part);

/// `family|given` (or `given|family`) in sortable text; an organization's
/// normalized name; `''` for a contact with no name at all. A single
/// present part leads (`zhang|`), so a given-only contact does not sort
/// ahead of everyone under family-name sort.
String sortKey(
  Contact c,
  ContactSortBy by,
  PinyinTranscriber? t, {
  void Function(Object error)? onError,
}) {
  if (c.contactType == ContactType.organization) {
    final name = c.organizationName?.trim() ?? '';
    return name.isEmpty ? '' : _sortPart(name, null, false, t, onError);
  }
  final family = _sortPart(
    c.lastName?.trim() ?? '',
    c.phoneticFamily,
    true,
    t,
    onError,
  );
  final given = _sortPart(
    c.firstName?.trim() ?? '',
    c.phoneticGiven,
    false,
    t,
    onError,
  );
  final (primary, secondary) =
      by == ContactSortBy.family ? (family, given) : (given, family);
  if (primary.isEmpty) return secondary.isEmpty ? '' : '$secondary|';
  return '$primary|$secondary';
}

(String, String) _split(String key) {
  final i = key.indexOf('|');
  return i < 0 ? (key, '') : (key.substring(0, i), key.substring(i + 1));
}

/// Empty keys last; then primary part, secondary part (compared part-wise so
/// `li|` sorts before `lin|`), display name, id. Deterministic on every
/// device.
int compareContactKeys(Contact a, String keyA, Contact b, String keyB) {
  if (keyA.isEmpty != keyB.isEmpty) return keyA.isEmpty ? 1 : -1;
  final (pa, sa) = _split(keyA);
  final (pb, sb) = _split(keyB);
  var r = pa.compareTo(pb);
  if (r != 0) return r;
  r = sa.compareTo(sb);
  if (r != 0) return r;
  r = a.displayName.compareTo(b.displayName);
  if (r != 0) return r;
  return a.id.compareTo(b.id);
}

/// Normalized search terms for one contact. [contains] match anywhere;
/// [prefixes] (pinyin initials such as `zw`) match only from the start.
class ContactSearchTerms {
  const ContactSearchTerms({required this.contains, required this.prefixes});

  final List<String> contains;
  final List<String> prefixes;
}

ContactSearchTerms searchTerms(
  Contact c,
  PinyinTranscriber? t, {
  void Function(Object error)? onError,
}) {
  final contains = <String>{};
  final prefixes = <String>{};
  void add(String s) {
    final n = normalizeForSearch(s);
    if (n.isNotEmpty) contains.add(n);
  }

  void addRomanized(List<String> forward, List<String> backward) {
    if (forward.isEmpty) return;
    contains
      ..add(forward.join(' '))
      ..add(forward.join())
      ..add(backward.join(' '))
      ..add(backward.join());
    prefixes.add(forward.map((s) => s[0]).join());
  }

  add(c.displayName);
  if (c.contactType == ContactType.organization) {
    final org = c.organizationName?.trim() ?? '';
    final syl = _syllables(org, null, false, t, onError);
    if (syl != null) {
      addRomanized(syl, syl);
      final v = _syllables(org, null, false, t, onError, vForUmlaut: true);
      if (v != null) addRomanized(v, v);
    }
  } else {
    final given = c.firstName?.trim() ?? '';
    final family = c.lastName?.trim() ?? '';
    add('$given $family');
    add('$family $given');
    final fs = _syllables(family, c.phoneticFamily, true, t, onError);
    final gs = _syllables(given, c.phoneticGiven, false, t, onError);
    if (fs != null || gs != null) {
      final f = fs ?? _words(family);
      final g = gs ?? _words(given);
      addRomanized([...f, ...g], [...g, ...f]);
      // The same terms with ü spelled v, as pinyin input methods type it.
      final fv =
          _syllables(family, c.phoneticFamily, true, t, onError,
              vForUmlaut: true) ??
          _words(family, vForUmlaut: true);
      final gv =
          _syllables(given, c.phoneticGiven, false, t, onError,
              vForUmlaut: true) ??
          _words(given, vForUmlaut: true);
      addRomanized([...fv, ...gv], [...gv, ...fv]);
    }
  }
  return ContactSearchTerms(
    contains: contains.toList(),
    prefixes: prefixes.toList(),
  );
}

/// True when [query] (normalized like the terms) is contained in a term, is
/// a prefix of the initials, or matches an email / phone (digits compared
/// with spaces, dashes, dots and parentheses ignored, as before).
bool matchesSearch(Contact c, ContactSearchTerms terms, String query) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;
  if (terms.contains.any((term) => term.contains(q))) return true;
  if (terms.prefixes.any((p) => p.startsWith(q))) return true;
  final lower = query.trim().toLowerCase();
  if (c.emails.any((e) => e.address.toLowerCase().contains(lower))) {
    return true;
  }
  final digits = lower.replaceAll(_phoneNoise, '');
  return c.phones.any(
    (p) =>
        p.number.toLowerCase().contains(lower) ||
        (digits.isNotEmpty &&
            p.number.replaceAll(_phoneNoise, '').contains(digits)),
  );
}
