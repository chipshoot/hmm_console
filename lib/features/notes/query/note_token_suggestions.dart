import 'package:flutter/material.dart' show IconData, Icons;
import 'package:intl/intl.dart';

import '../../../core/notes/note_flag.dart';
import '../../../core/util/search_normalize.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/models/hmm_note.dart';
import '../states/notes_list_state.dart';
import 'note_query.dart';
import 'note_token_labels.dart';

class TokenSuggestion {
  const TokenSuggestion(this.token, this.label, this.icon);
  final NoteToken token;
  final String label;
  final IconData icon;
}

const _maxSuggestions = 8;
const _maxParents = 3;

/// Tokens whose label contains what the user typed, in kind order (tags,
/// domains, flags, parents, attributes, dates), minus those already applied.
/// Pure: no BuildContext, no Riverpod.
List<TokenSuggestion> suggestTokens(
  String text,
  NotesListData c,
  List<NoteToken> existing,
  AppLocalizations l, {
  required String Function(HmmNote) titleOf,
}) {
  final fragment = normalizeForSearch(text).trim();
  if (fragment.isEmpty) return const [];

  final out = <TokenSuggestion>[];
  var parents = 0;
  void offer(NoteToken t, String label, IconData icon) {
    if (out.length >= _maxSuggestions || existing.contains(t)) return;
    if (!normalizeForSearch(label).contains(fragment)) return;
    out.add(TokenSuggestion(t, label, icon));
  }

  final tags = <int, String>{
    if (c.liveTagNames != null)
      ...c.liveTagNames!
    else
      for (final list in c.tagsByNoteId.values)
        for (final t in list) t.id: t.name,
  };
  for (final e in tags.entries) {
    offer(TagToken(e.key), l.notesTokenTag(e.value), Icons.sell_outlined);
  }
  for (final key in c.countsByDomain.keys) {
    offer(
      DomainToken(key),
      tokenText(DomainToken(key), c, l, titleOf),
      Icons.folder_outlined,
    );
  }
  for (final f in NoteFlagColor.values) {
    final t = FlagToken(f.stored);
    offer(t, tokenText(t, c, l, titleOf), Icons.flag);
  }

  final parentIds = {for (final n in c.all) ?n.parentNoteId};
  final byId = {for (final n in c.all) n.id: n};
  for (final id in parentIds) {
    if (parents >= _maxParents) break;
    final note = byId[id];
    final uuid = note?.uuid;
    final subject = note != null ? titleOf(note) : c.targetsById[id]?.subject;
    if (uuid == null || subject == null) continue;
    final before = out.length;
    offer(ParentToken(uuid), l.notesTokenParent(subject), Icons.link);
    if (out.length > before) parents++;
  }

  offer(const HasPhotoToken(), l.notesTokenHasPhoto, Icons.photo_outlined);
  offer(const HasPlaceToken(), l.notesTokenHasPlace, Icons.place_outlined);
  offer(
    const HasAttachmentToken(),
    l.notesTokenHasAttachment,
    Icons.attach_file,
  );
  offer(const PinnedToken(), l.notesTokenPinned, Icons.push_pin_outlined);
  for (final r in RelativeRange.values) {
    offer(RelativeDateToken(r), relativeRangeLabel(r, l), Icons.date_range);
  }
  return out;
}

String tokenText(
  NoteToken t,
  NotesListData c,
  AppLocalizations l,
  String Function(HmmNote) titleOf,
) => tokenLabel(t, c, l, titleOf: titleOf, dateFormat: DateFormat.yMd()).text;
