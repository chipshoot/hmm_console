import '../../../core/navigation/route_names.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../notes/data/models/hmm_note.dart';
import '../../notes/rendering/note_display.dart';
import '../data/glucose_codec.dart';
import '../data/local_glucose_repository.dart' show glucoseCatalogName;
import '../domain/glucose_reading.dart';

/// How a glucose reading's note reads in the Notes UI. The subject
/// (`Glucose:<id>`) is identity and the content is JSON; neither is shown.
///
/// The title uses the reading's own unit: this const entry cannot read the
/// synced display-unit setting.
class GlucoseNoteDisplay implements NoteDisplayEntry {
  const GlucoseNoteDisplay();

  static const catalogName = glucoseCatalogName;
  static const _prefix = 'Glucose:';

  @override
  String title(HmmNote note, AppLocalizations l) {
    final r = _decode(note);
    return r == null
        ? l.glucoseTitle
        : l.glucoseNoteTitle(r.glucose.display(r.glucose.unit));
  }

  @override
  NoteDisplay display(HmmNote note, AppLocalizations l) {
    final r = _decode(note);
    if (r == null) return (title: l.glucoseTitle, preview: '');
    final firstLine = r.notes
        .split('\n')
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    return (
      title: l.glucoseNoteTitle(r.glucose.display(r.glucose.unit)),
      preview: firstLine,
    );
  }

  @override
  NoteTarget? target(HmmNote note) {
    var id = note.subject.startsWith(_prefix)
        ? note.subject.substring(_prefix.length).trim()
        : '';
    if (id.isEmpty) id = note.uuid.trim();
    if (id.isEmpty) return null;
    return (route: RouterNames.glucoseEdit, params: {'id': id});
  }

  GlucoseReading? _decode(HmmNote note) {
    final content = note.content;
    if (content == null) return null;
    try {
      return GlucoseCodec.decode(note.uuid, content);
    } catch (_) {
      return null;
    }
  }
}
