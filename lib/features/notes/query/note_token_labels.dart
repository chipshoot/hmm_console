import 'package:intl/intl.dart';

import '../../../core/notes/note_flag.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/models/hmm_note.dart';
import '../presentation/catalog_labels.dart';
import '../states/notes_list_state.dart';
import 'note_query.dart';
import 'note_query_engine.dart' show isRemovedToken;

/// What a token chip shows. [removed] marks a token whose target is gone, so
/// the chip can render muted.
typedef TokenLabel = ({String text, bool removed});

String flagName(int color, AppLocalizations l) =>
    switch (NoteFlagColor.fromStored(color)!) {
      NoteFlagColor.red => l.flagColorRed,
      NoteFlagColor.orange => l.flagColorOrange,
      NoteFlagColor.yellow => l.flagColorYellow,
      NoteFlagColor.green => l.flagColorGreen,
      NoteFlagColor.blue => l.flagColorBlue,
      NoteFlagColor.purple => l.flagColorPurple,
      NoteFlagColor.grey => l.flagColorGrey,
    };

String relativeRangeLabel(RelativeRange r, AppLocalizations l) => switch (r) {
  RelativeRange.last7d => l.notesTokenLast7d,
  RelativeRange.last30d => l.notesTokenLast30d,
  RelativeRange.last90d => l.notesTokenLast90d,
};

/// The text for [t]. Pure: no BuildContext, no Riverpod.
TokenLabel tokenLabel(
  NoteToken t,
  NotesListData c,
  AppLocalizations l, {
  required String Function(HmmNote) titleOf,
  required DateFormat dateFormat,
}) {
  final removed = isRemovedToken(t, c);
  switch (t) {
    case TagToken(:final tagId):
      if (removed) {
        return (text: l.notesTokenRemoved('#$tagId'), removed: true);
      }
      return (
        text: l.notesTokenTag(tagNameOf(c, tagId) ?? '$tagId'),
        removed: false,
      );
    case DomainToken(:final key):
      return (text: domainLabel(key, l), removed: false);
    case CatalogToken(:final catalogId):
      return (
        text: switch (c.catalogsById[catalogId]) {
          final cat? => catalogLabel(cat.name, l),
          null => '#$catalogId',
        },
        removed: false,
      );
    case ParentToken(:final noteUuid):
      if (removed) {
        return (
          text: l.notesTokenRemoved(l.notesTokenParent('…')),
          removed: true,
        );
      }
      final note = c.all.where((n) => n.uuid == noteUuid).firstOrNull;
      return (text: l.notesTokenParent(titleOf(note!)), removed: false);
    case FlagToken(:final color):
      return (text: l.notesTokenFlag(flagName(color, l)), removed: false);
    case DateRangeToken(:final from, :final to):
      return (
        text: l.notesTokenDateRange(
          from == null ? '' : dateFormat.format(from.toLocal()),
          to == null ? '' : dateFormat.format(to.toLocal()),
        ),
        removed: false,
      );
    case RelativeDateToken(:final range):
      return (text: relativeRangeLabel(range, l), removed: false);
    case HasPhotoToken():
      return (text: l.notesTokenHasPhoto, removed: false);
    case HasPlaceToken():
      return (text: l.notesTokenHasPlace, removed: false);
    case HasAttachmentToken():
      return (text: l.notesTokenHasAttachment, removed: false);
    case PinnedToken():
      return (text: l.notesTokenPinned, removed: false);
    case UnknownToken():
      return (text: l.notesTokenUnknown, removed: false);
  }
}

/// A tag's name from the live map, else from the tags notes carry.
String? tagNameOf(NotesListData c, int id) {
  final live = c.liveTagNames?[id];
  if (live != null) return live;
  for (final tags in c.tagsByNoteId.values) {
    for (final t in tags) {
      if (t.id == id) return t.name;
    }
  }
  return null;
}
