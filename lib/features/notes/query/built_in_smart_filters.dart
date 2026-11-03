/// Fixed smart filters shipped with the app. They are saved searches that are
/// never stored, renamed, moved or deleted; their names are localized at
/// display time, so [SavedSearch.name] is empty.
library;

import '../../../l10n/gen/app_localizations.dart';
import 'note_query.dart';
import 'saved_search.dart';

const _prefix = 'builtin.';

const List<SavedSearch> builtInSmartFilters = [
  SavedSearch(
    id: 'builtin.withPhotos',
    name: '',
    order: 0,
    query: NoteQuery(tokens: [HasPhotoToken()]),
  ),
  SavedSearch(
    id: 'builtin.withPlace',
    name: '',
    order: 1,
    query: NoteQuery(tokens: [HasPlaceToken()]),
  ),
  SavedSearch(
    id: 'builtin.last7d',
    name: '',
    order: 2,
    query: NoteQuery(tokens: [RelativeDateToken(RelativeRange.last7d)]),
  ),
];

bool isBuiltInSmartFilter(String id) => id.startsWith(_prefix);

String builtInSmartFilterName(String id, AppLocalizations l) => switch (id) {
  'builtin.withPhotos' => l.notesSmartWithPhotos,
  'builtin.withPlace' => l.notesSmartWithPlace,
  'builtin.last7d' => l.notesSmartLast7d,
  _ => '',
};
