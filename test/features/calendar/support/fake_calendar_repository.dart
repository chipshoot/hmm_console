import 'dart:async';

import 'package:hmm_console/features/calendar/contract/calendar_errors.dart';
import 'package:hmm_console/features/calendar/data/local_calendar_repository.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_expander.dart';

import '../../contacts/data/contact_repository_fakes.dart';

/// In-memory calendar repository for widget and state tests. Extends the
/// local one so screens that need `readAll` (unreadable ids) see it.
class FakeCalendarRepository extends LocalCalendarRepository {
  FakeCalendarRepository({List<String> unreadable = const []})
    : unreadableIds = List.of(unreadable),
      super(FakeNoteRepository(), FakeCatalogRepository());

  final Map<String, CalendarEvent> events = {};
  final List<String> unreadableIds;
  final List<String> log = [];
  final _changes = StreamController<void>.broadcast();

  void seed(CalendarEvent e) => events[e.id] = e;

  @override
  Future<List<CalendarEventReadResult>> readAll() async => [
    for (final e in events.values) CalendarEventReadable(e),
    for (final id in unreadableIds) CalendarEventUnreadableResult(id),
  ];

  @override
  Future<List<CalendarEvent>> eventsBetween(DateTime from, DateTime to) async =>
      [
        for (final e in events.values)
          if (expandOccurrences(e, from, to).isNotEmpty) e,
      ];

  @override
  Future<CalendarEvent?> getEvent(String id) async => events[id];

  @override
  Future<CalendarEvent> saveEvent(CalendarEvent event) async {
    log.add('save:${event.id}');
    events[event.id] = event;
    _changes.add(null);
    return event;
  }

  @override
  Future<void> deleteEvent(String id) async {
    log.add('delete:$id');
    events.remove(id);
    _changes.add(null);
  }

  @override
  Future<CalendarEvent> setOccurrence(
    String eventId,
    OccurrenceOverride o,
  ) async {
    final e = events[eventId];
    if (e == null) throw CalendarEventNotFound(eventId);
    log.add('occ:$eventId:${o.status.name}');
    final list = [
      for (final x in e.occurrences)
        if (x.originalStart != o.originalStart) x,
      o,
    ];
    final saved = CalendarEvent(
      id: e.id,
      title: e.title,
      start: e.start,
      end: e.end,
      rrule: e.rrule,
      occurrences: list,
      updatedAt: DateTime.now().toUtc(),
    );
    events[eventId] = saved;
    _changes.add(null);
    return saved;
  }

  @override
  Stream<void> changes() => _changes.stream;
}
