import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/calendar_view_state.dart';
import 'package:hmm_console/features/calendar/states/event_edit_state.dart';

import '../support/fake_calendar_repository.dart';

CalendarEvent _ev(String id, EventTime start, {String? rrule, String? title}) =>
    CalendarEvent(
      id: id,
      title: title ?? id,
      start: start,
      rrule: rrule,
      updatedAt: DateTime.utc(2020),
    );

ProviderContainer _c(FakeCalendarRepository repo, {String? zone}) {
  final c = ProviderContainer(
    overrides: [
      calendarRepositoryProvider.overrideWithValue(repo),
      if (zone != null)
        calendarDeviceZoneProvider.overrideWithValue(tz.getLocation(zone)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  for (final zone in ['Asia/Shanghai', 'Pacific/Auckland', 'America/Toronto']) {
    group('in $zone', () {
      test('an all-day event lists on its own date, first', () async {
        final repo = FakeCalendarRepository()
          ..seed(_ev('late', const FloatingTime(2026, 11, 18, 19, 0)))
          ..seed(_ev('early', const FloatingTime(2026, 11, 18, 7, 0)))
          ..seed(_ev('all', const AllDay(2026, 11, 18)))
          ..seed(_ev('prev', const AllDay(2026, 11, 17)))
          ..seed(_ev('next', const AllDay(2026, 11, 19)));
        final c = _c(repo, zone: zone);
        c.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 18));
        final data = await c.read(calendarViewProvider.future);
        expect(data.agenda.map((a) => a.event.id), ['all', 'early', 'late']);
      });

      test('event days mark an all-day span on its own dates', () async {
        final repo = FakeCalendarRepository()
          ..seed(
            CalendarEvent(
              id: 'trip',
              title: 'trip',
              start: const AllDay(2026, 11, 10),
              end: const AllDay(2026, 11, 12),
              updatedAt: DateTime.utc(2020),
            ),
          )
          ..seed(_ev('once', const AllDay(2026, 11, 1)));
        final c = _c(repo, zone: zone);
        c.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 11));
        final data = await c.read(calendarViewProvider.future);
        expect(data.eventDays, {1, 10, 11, 12});
        expect(data.agenda.map((a) => a.event.id), ['trip']);
      });

      test('a timed event late in the evening stays on its day', () async {
        final repo = FakeCalendarRepository()
          ..seed(_ev('late', const FloatingTime(2026, 11, 18, 23, 30)));
        final c = _c(repo, zone: zone);
        c.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 18));
        final data = await c.read(calendarViewProvider.future);
        expect(data.agenda.map((a) => a.event.id), ['late']);
        expect(data.eventDays, {18});
      });
    });
  }

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

  test('a changes() error keeps the agenda (no unhandled error)', () async {
    final repo = FakeCalendarRepository()
      ..seed(_ev('ok', const FloatingTime(2026, 11, 18, 7, 0)));
    final c = _c(repo);
    c.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 18));
    final sub = c.listen(calendarViewProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(calendarViewProvider.future);
    repo.emitChangeError(StateError('catalog'));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(calendarViewProvider).value!.agenda, hasLength(1));
  });

  test('calendarEventProvider survives a changes() error', () async {
    final repo = FakeCalendarRepository()
      ..seed(_ev('ok', const FloatingTime(2026, 11, 18, 7, 0)));
    final c = _c(repo);
    final sub = c.listen(calendarEventProvider('ok'), (_, _) {});
    addTearDown(sub.close);
    await c.read(calendarEventProvider('ok').future);
    repo.emitChangeError(StateError('catalog'));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(calendarEventProvider('ok')).value!.id, 'ok');
  });
}
