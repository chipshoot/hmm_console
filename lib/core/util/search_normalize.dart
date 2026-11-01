// lib/core/util/search_normalize.dart
final _ws = RegExp(r'\s+');

const _fold = <String, String>{
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ǎ': 'a',
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

/// Lowercase + per-character accent fold with **output length == input
/// length** (UTF-16 units), so match offsets map back to the original text.
/// A lowercase or fold result that is not exactly as long as the character
/// it replaces is skipped. No whitespace collapsing.
String foldForMatch(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    var out = ch.toLowerCase();
    if (out.length != ch.length) out = ch;
    final f = _fold[out];
    if (f != null && f.length == out.length) out = f;
    b.write(out);
  }
  return b.toString();
}
