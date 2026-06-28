import 'launcher_destination.dart';

/// Ranks destinations against a command-mode query. Highest first:
///   4 exact alias, 3 title/synonym prefix, 2 substring, 1 subsequence.
/// Ties broken alphabetically by title. Empty query -> const [].
/// Pure (no Flutter beyond the value type) — unit-tested in isolation.
List<LauncherDestination> match(
  String query, {
  required List<LauncherDestination> registry,
  required Map<String, String> aliases,
}) {
  var q = query.trim().toLowerCase();
  if (q.startsWith('/')) q = q.substring(1).trim();
  if (q.isEmpty) return const [];

  final ranked = <_Ranked>[];
  for (final d in registry) {
    final r = _rank(q, d, aliases);
    if (r > 0) ranked.add(_Ranked(r, d));
  }
  ranked.sort((a, b) {
    if (a.rank != b.rank) return b.rank.compareTo(a.rank);
    return a.dest.title.toLowerCase().compareTo(b.dest.title.toLowerCase());
  });
  return ranked.map((e) => e.dest).toList();
}

int _rank(String q, LauncherDestination d, Map<String, String> aliases) {
  if (aliases[q] == d.id) return 4;
  final hays = [d.title.toLowerCase(), ...d.synonyms.map((s) => s.toLowerCase())];
  if (hays.any((h) => h.startsWith(q))) return 3;
  if (hays.any((h) => h.contains(q))) return 2;
  if (_isSubsequence(q, d.title.toLowerCase())) return 1;
  return 0;
}

bool _isSubsequence(String needle, String haystack) {
  var i = 0;
  for (var j = 0; j < haystack.length && i < needle.length; j++) {
    if (needle[i] == haystack[j]) i++;
  }
  return i == needle.length;
}

class _Ranked {
  const _Ranked(this.rank, this.dest);
  final int rank;
  final LauncherDestination dest;
}
