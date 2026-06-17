/// Extracts a one-line human-readable preview from a note's content.
///
/// Returns the first non-blank line with common Markdown markers stripped.
/// Domain notes store a JSON blob in `content`; those are not human text, so a
/// payload that starts with `{` or `[` yields an empty string (the row then
/// shows only its title + secondary metadata).
String notePreview(String? content) {
  if (content == null) return '';
  final trimmed = content.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return '';

  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    return _stripMarkdown(line);
  }
  return '';
}

String _stripMarkdown(String line) {
  var s = line;
  // Leading block markers: heading #, blockquote >, list bullets -, *, +.
  s = s.replaceFirst(RegExp(r'^\s*(#{1,6}|>|[-*+])\s+'), '');
  // Inline emphasis/code markers.
  s = s.replaceAll(RegExp(r'[*_`]'), '');
  return s.trim();
}
