/// Expands a live query whose source is a saved search into the query the
/// engine evaluates. Saved searches never nest.
library;

import 'note_query.dart';
import 'saved_search.dart';

/// The saved search a [SmartSource] points at, or null for any other source
/// or an id that no longer exists.
SavedSearch? savedSearchFor(NoteSource s, List<SavedSearch> saved) {
  if (s is! SmartSource) return null;
  for (final x in saved) {
    if (x.id == s.savedId) return x;
  }
  return null;
}

/// Source, text and tokens come from the saved search (plus the live text and
/// tokens); scope and sort stay the live ones. A missing id passes [live]
/// through unchanged.
NoteQuery resolveSmartQuery(NoteQuery live, List<SavedSearch> saved) {
  final found = savedSearchFor(live.source, saved);
  if (found == null) return live;
  final q = found.query;
  return live.copyWith(
    source: q.source is SmartSource ? const AllSource() : q.source,
    text: [q.text, live.text].where((t) => t.isNotEmpty).join(' '),
    tokens: [
      ...q.tokens,
      for (final t in live.tokens)
        if (!q.tokens.contains(t)) t,
    ],
  );
}
