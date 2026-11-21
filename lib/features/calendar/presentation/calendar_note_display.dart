import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../core/navigation/route_names.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../notes/data/models/hmm_note.dart';
import '../../notes/rendering/note_display.dart';
import '../data/calendar_event_codec.dart';
import '../data/local_calendar_repository.dart' show calendarCatalogName;
import '../domain/calendar_event.dart';
import '../domain/event_time.dart';
import '../domain/linked_event.dart';
import '../states/calendar_view_state.dart' show localTimeOf;
import 'linked_event_title.dart' show linkedTitle;

/// How a calendar event's note reads in the Notes UI. The subject
/// (`Event:<id>`) is identity and the content is JSON; neither is shown.
class CalendarNoteDisplay implements NoteDisplayEntry {
  const CalendarNoteDisplay();

  static const catalogName = calendarCatalogName;
  static const _prefix = 'Event:';

  @override
  String title(HmmNote note, AppLocalizations l) {
    final d = _decode(note);
    final t = d == null ? '' : _titleOf(d, l);
    return t.isEmpty ? l.notesCalendarEventTitleFallback : t;
  }

  @override
  NoteDisplay display(HmmNote note, AppLocalizations l) {
    final e = _decode(note);
    final t = e == null ? '' : _titleOf(e, l);
    if (e == null || t.isEmpty) {
      return (title: l.notesCalendarEventTitleFallback, preview: '');
    }
    final firstNoteLine = (e.notes ?? '')
        .split('\n')
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (firstNoteLine.isNotEmpty) return (title: t, preview: firstNoteLine);
    final repeats = (e.rrule ?? '').trim().isNotEmpty;
    final preview = [
      _when(e.start, l.localeName),
      if (repeats) l.calendarRepeats,
    ].join(' · ');
    return (title: t, preview: preview);
  }

  @override
  NoteTarget? target(HmmNote note) {
    var id = note.subject.startsWith(_prefix)
        ? note.subject.substring(_prefix.length).trim()
        : '';
    if (id.isEmpty) id = note.uuid.trim();
    if (id.isEmpty) return null;
    return (route: RouterNames.calendarEvent, params: {'id': id});
  }

  /// The start as a short local date (and time for a timed event).
  static String _when(EventTime start, String locale) {
    final (DateTime wall, bool timed) = switch (start) {
      FixedTime(:final instant) => (localTimeOf(instant), true),
      FloatingTime(
        :final year,
        :final month,
        :final day,
        :final hour,
        :final minute,
      ) =>
        (DateTime(year, month, day, hour, minute), true),
      AllDay(:final year, :final month, :final day) => (
        DateTime(year, month, day),
        false,
      ),
    };
    try {
      final f = DateFormat.yMMMd(locale);
      return (timed ? f.add_Hm() : f).format(wall);
    } catch (_) {
      // Locale data unavailable: a plain ISO date still beats raw JSON.
      return wall.toIso8601String().substring(0, timed ? 16 : 10);
    }
  }

  static String _titleOf(CalendarEvent e, AppLocalizations l) {
    final info = linkedInfoOf(e);
    return (info == null ? e.title : linkedTitle(info, l)).trim();
  }

  CalendarEvent? _decode(HmmNote note) {
    final content = note.content;
    if (content == null) return null;
    try {
      final json = jsonDecode(content);
      if (json is! Map) return null;
      return CalendarEventCodec.decode(note.uuid, json.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }
}
