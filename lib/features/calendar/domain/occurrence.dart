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
