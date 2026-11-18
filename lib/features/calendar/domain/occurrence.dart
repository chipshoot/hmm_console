import 'calendar_event.dart';
import 'event_time.dart';

/// One occurrence of an event, computed by expansion and never stored.
///
/// [start] and [end] are UTC instants. [originalStart] is the slot this
/// occurrence has in the series (its override key), even when it was moved.
class Occurrence {
  const Occurrence({
    required this.eventId,
    required this.originalStart,
    required this.start,
    this.end,
    this.allDay = false,
    this.status,
    this.titleOverride,
  });

  final String eventId;
  final EventTime originalStart;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final OccurrenceStatus? status;
  final String? titleOverride;

  @override
  bool operator ==(Object other) =>
      other is Occurrence &&
      other.eventId == eventId &&
      other.originalStart == originalStart &&
      other.start == start &&
      other.end == end &&
      other.allDay == allDay &&
      other.status == status &&
      other.titleOverride == titleOverride;

  @override
  int get hashCode => Object.hash(
    eventId,
    originalStart,
    start,
    end,
    allDay,
    status,
    titleOverride,
  );

  @override
  String toString() => 'Occurrence($eventId, $start, $status)';
}

/// The calendar date of an all-day occurrence of [e]: the moved-to date when
/// it was moved to an all-day slot, else its original all-day date. Null
/// when neither is all-day (the occurrence is then timed).
///
/// Dates come from the stored times, never from [Occurrence.start], which is
/// the UTC instant of local midnight and can fall on the previous UTC date.
AllDay? allDayDateOf(CalendarEvent e, Occurrence o) {
  for (final ov in e.occurrences) {
    if (ov.originalStart.wireKey == o.originalStart.wireKey) {
      final m = ov.movedTo;
      if (m is AllDay) return m;
      if (m != null) return null;
      break;
    }
  }
  final orig = o.originalStart;
  return orig is AllDay ? orig : null;
}

/// Extra days an all-day [e] spans after its first (0 for a single day).
int allDaySpanDays(CalendarEvent e) {
  final s = e.start;
  final end = e.end;
  if (s is! AllDay || end is! AllDay) return 0;
  final span = DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(s.year, s.month, s.day)).inDays;
  return span < 0 ? 0 : span;
}
