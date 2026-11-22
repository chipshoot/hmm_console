import 'dart:convert';

import '../../../core/navigation/route_names.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../notes/data/models/hmm_note.dart';
import '../../notes/rendering/note_display.dart';
import '../data/activity_codec.dart';
import '../data/local_activity_repository.dart' show activityCatalogName;
import '../domain/activity.dart';
import '../domain/activity_kind.dart';
import '../domain/builtin_activity_kinds.dart';
import 'activity_summary.dart';

/// How an activity's note reads in the Notes UI. The subject
/// (`Activity:<id>`) is identity and the content is JSON; neither is shown.
class ActivityNoteDisplay implements NoteDisplayEntry {
  const ActivityNoteDisplay();

  static const catalogName = activityCatalogName;
  static const _prefix = 'Activity:';

  // Built-in kinds only: the display map is const and cannot read
  // activityKindRegistryProvider, so a kind added there later reads
  // `Other (<id>)` in the Notes list.
  static final _kinds = ActivityKindRegistry(builtinActivityKinds);

  @override
  String title(HmmNote note, AppLocalizations l) {
    final a = _decode(note);
    return a == null ? l.activityTitle : activitySummary(a, _kinds, l);
  }

  @override
  NoteDisplay display(HmmNote note, AppLocalizations l) {
    final a = _decode(note);
    if (a == null) return (title: l.activityTitle, preview: '');
    final firstLine = (a.notes ?? '')
        .split('\n')
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    return (title: activitySummary(a, _kinds, l), preview: firstLine);
  }

  @override
  NoteTarget? target(HmmNote note) {
    var id = note.subject.startsWith(_prefix)
        ? note.subject.substring(_prefix.length).trim()
        : '';
    if (id.isEmpty) id = note.uuid.trim();
    if (id.isEmpty) return null;
    return (route: RouterNames.activityEdit, params: {'id': id});
  }

  Activity? _decode(HmmNote note) {
    final content = note.content;
    if (content == null) return null;
    try {
      final json = jsonDecode(content);
      if (json is! Map) return null;
      return ActivityCodec.decode(note.uuid, json.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }
}
