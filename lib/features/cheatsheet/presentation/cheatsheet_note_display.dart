import 'dart:convert';

import '../../../core/data/local/local_cheatsheet_repository.dart';
import '../../../core/navigation/route_names.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../notes/data/models/hmm_note.dart';
import '../../notes/rendering/note_display.dart';
import '../data/cheatsheet_codec.dart';
import '../data/cheatsheet_templates.dart';
import '../domain/entities/cheatsheet_card.dart';

/// How a cheatsheet card's note reads in the Notes UI. The subject
/// (`Cheatsheet:<id>`) is identity and is never shown.
class CheatsheetNoteDisplay implements NoteDisplayEntry {
  const CheatsheetNoteDisplay();

  static const catalogName = cheatsheetCatalogName;
  static const _prefix = 'Cheatsheet:';

  @override
  NoteDisplay display(HmmNote note, AppLocalizations l) {
    final c = _decode(note);
    if (c == null || c.title.trim().isEmpty) {
      return (title: l.notesCheatsheetTitleFallback, preview: '');
    }
    return (
      title: c.title.trim(),
      preview: l.notesCheatsheetPreview(
        cheatsheetGroupLabel(c.walletGroup, l),
        c.rows.length,
      ),
    );
  }

  @override
  NoteTarget? target(HmmNote note) {
    var id = note.subject.startsWith(_prefix)
        ? note.subject.substring(_prefix.length).trim()
        : '';
    if (id.isEmpty) id = _decode(note)?.id ?? '';
    if (id.isEmpty) return null;
    return (route: RouterNames.cheatsheetDetail, params: {'id': id});
  }

  CheatsheetCard? _decode(HmmNote note) {
    final content = note.content;
    if (content == null) return null;
    try {
      final data =
          (jsonDecode(content) as Map)['note']?['content']?['Cheatsheet'];
      if (data is! Map) return null;
      return CheatsheetCodec.fromMap(data.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}
