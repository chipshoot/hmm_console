import '../../../core/util/uuid.dart';
import '../contract/calendar_service.dart';
import '../contract/i_calendar_repository.dart';
import '../domain/calendar_event.dart';

class DefaultCalendarService implements CalendarService {
  DefaultCalendarService(this._repo);

  final ICalendarRepository _repo;

  @override
  Future<CalendarEvent> upsertOwnedEvent(
    EventOwner owner,
    CalendarEventDraft draft,
  ) async {
    final source = draft.source == EventSource.assistant
        ? EventSource.assistant
        : EventSource.subsystem;
    final existing = draft.id == null ? null : await _repo.getEvent(draft.id!);
    if (existing != null && !_sameOwner(existing.owner, owner)) {
      throw ArgumentError.value(
        draft.id,
        'draft.id',
        'event belongs to another owner',
      );
    }
    final extra = <String, Object?>{...?existing?.extraFields};
    if (draft.reminderBody == null) {
      extra.remove('reminderBody');
    } else {
      extra['reminderBody'] = draft.reminderBody;
    }
    final base =
        existing ??
        CalendarEvent(
          id: draft.id ?? generateUuid(),
          title: draft.title,
          start: draft.start,
          updatedAt: DateTime.now(),
        );
    final event = CalendarEvent(
      id: base.id,
      schemaVersion: base.schemaVersion,
      title: draft.title,
      notes: draft.notes,
      start: draft.start,
      end: draft.end,
      rrule: draft.rrule,
      reminders: draft.reminders,
      owner: owner,
      status: base.status,
      source: source,
      draft: draft.draft,
      timeSensitive: draft.timeSensitive,
      occurrences: base.occurrences,
      updatedAt: base.updatedAt,
      extraFields: extra,
      rawKnownValues: base.rawKnownValues,
      unreadableEntries: base.unreadableEntries,
    );
    return _repo.saveEvent(event);
  }

  bool _sameOwner(EventOwner? a, EventOwner b) =>
      a != null && a.subsystem == b.subsystem && a.noteUuid == b.noteUuid;

  @override
  Future<void> removeOwnedEvents(EventOwner owner) async {
    for (final e in await _repo.eventsOwnedBy(owner)) {
      await _repo.deleteEvent(e.id);
    }
  }

  @override
  Future<List<CalendarEvent>> ownedEvents(EventOwner owner) =>
      _repo.eventsOwnedBy(owner);
}
