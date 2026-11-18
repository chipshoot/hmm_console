import '../domain/calendar_event.dart';
import '../domain/event_time.dart';

/// What a subsystem hands the calendar; the service turns it into an event.
class CalendarEventDraft {
  const CalendarEventDraft({
    required this.title,
    required this.start,
    this.id,
    this.notes,
    this.end,
    this.rrule,
    this.reminders = const [Reminder(minutesBefore: 15)],
    this.reminderBody,
    this.draft = false,
    this.source = EventSource.subsystem,
  });

  /// Null creates a new event; an existing id updates it.
  final String? id;
  final String title;
  final String? notes;
  final EventTime start;
  final EventTime? end;
  final String? rrule;
  final List<Reminder> reminders;

  /// The line a subsystem adds to the notification; stored in
  /// `extraFields['reminderBody']`.
  final String? reminderBody;
  final bool draft;
  final EventSource source;
}

/// The only calendar API other subsystems use.
abstract interface class CalendarService {
  Future<CalendarEvent> upsertOwnedEvent(
    EventOwner owner,
    CalendarEventDraft draft,
  );
  Future<void> removeOwnedEvents(EventOwner owner);
  Future<List<CalendarEvent>> ownedEvents(EventOwner owner);
}
