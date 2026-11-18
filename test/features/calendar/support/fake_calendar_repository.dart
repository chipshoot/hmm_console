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

  /// Makes `changes()` deliver [error] (what a failing catalog read gives).
  void emitChangeError(Object error) => _changes.addError(error);

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
  Future<CalendarEvent?> getEvent(String id) async {
    if (unreadableIds.contains(id)) throw CalendarEventUnreadable(id);
    return events[id];
  }

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
    final key = o.originalStart.wireKey;
    final list = [...e.occurrences];
    final i = list.indexWhere((x) => x.originalStart.wireKey == key);
    if (i >= 0) {
      list[i] = o;
    } else {
      list.add(o);
    }
    // copyWith keeps every other field, so a test cannot hide field loss.
    final saved = e.copyWith(
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
