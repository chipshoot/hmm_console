import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/calendar_view_state.dart';

import '../support/fake_calendar_repository.dart';

CalendarEvent _ev(String id, EventTime start, {String? rrule, String? title}) =>
    CalendarEvent(
      id: id,
      title: title ?? id,
      start: start,
      rrule: rrule,
      updatedAt: DateTime.utc(2020),
    );

ProviderContainer _c(FakeCalendarRepository repo) {
  final c = ProviderContainer(
    overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('a day lists occurrences in time order, all-day first', () async {
    final repo = FakeCalendarRepository()
      ..seed(_ev('late', const FloatingTime(2026, 11, 18, 19, 0)))
      ..seed(_ev('early', const FloatingTime(2026, 11, 18, 7, 0)))
      ..seed(_ev('all', const AllDay(2026, 11, 18)))
      ..seed(_ev('other', const FloatingTime(2026, 11, 19, 8, 0)));
    final c = _c(repo);
    c.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 18));
    final data = await c.read(calendarViewProvider.future);
    expect(data.agenda.map((a) => a.event.id), ['all', 'early', 'late']);
  });

  test('event days of the month include a repeating event\'s days', () async {
    final repo = FakeCalendarRepository()
      ..seed(
        _ev(
          'daily',
          const FloatingTime(2026, 11, 10, 8, 0),
          rrule: 'FREQ=DAILY;COUNT=3',
        ),
      )
      ..seed(_ev('once', const FloatingTime(2026, 11, 25, 8, 0)));
    final c = _c(repo);
    c.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 1));
    final data = await c.read(calendarViewProvider.future);
    expect(data.eventDays, {10, 11, 12, 25});
  });

  test('unreadable events are reported and do not hide the others', () async {
    final repo = FakeCalendarRepository(unreadable: ['bad'])
      ..seed(_ev('ok', const FloatingTime(2026, 11, 18, 7, 0)));
    final c = _c(repo);
    c.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 18));
    final data = await c.read(calendarViewProvider.future);
    expect(data.agenda.map((a) => a.event.id), ['ok']);
    expect(data.unreadableIds, ['bad']);
  });

  test('re-reads when the repository changes', () async {
    final repo = FakeCalendarRepository();
    final c = _c(repo);
    c.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 18));
    final sub = c.listen(calendarViewProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(calendarViewProvider.future)).agenda, isEmpty);
    await repo.saveEvent(_ev('new', const FloatingTime(2026, 11, 18, 7, 0)));
    await Future<void>.delayed(Duration.zero);
    expect((await c.read(calendarViewProvider.future)).agenda, hasLength(1));
  });
}
