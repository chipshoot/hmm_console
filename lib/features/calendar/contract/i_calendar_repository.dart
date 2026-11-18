import '../domain/calendar_event.dart';

abstract interface class ICalendarRepository {
  /// Events with at least one occurrence overlapping [from, to). Unreadable
  /// events are skipped.
  Future<List<CalendarEvent>> eventsBetween(DateTime from, DateTime to);

  /// Null when absent or deleted. Throws `CalendarEventUnreadable` when a note
  /// is stored but cannot be decoded.
  Future<CalendarEvent?> getEvent(String id);

  /// Upsert by id; sets `updatedAt`. A deleted id is restored, not duplicated.
  Future<CalendarEvent> saveEvent(CalendarEvent event);

  /// Soft delete; a missing or already-deleted id is a no-op.
  Future<void> deleteEvent(String id);

  Future<List<CalendarEvent>> eventsOwnedBy(EventOwner owner);

  /// Replaces the override with the same `originalStart`, else appends.
  /// Throws `CalendarEventNotFound` for a missing event.
  Future<CalendarEvent> setOccurrence(String eventId, OccurrenceOverride o);

  /// Emits on local edits and sync pulls.
  Stream<void> changes();
}
