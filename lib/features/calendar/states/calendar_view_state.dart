import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/local_calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/occurrence.dart';
import '../domain/recurrence_expander.dart';
import '../notifications/reminder_sync.dart' show deviceLocalResolver;
import 'calendar_providers.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The day whose agenda is shown (date only, device calendar).
class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => _dateOnly(DateTime.now());

  /// Also moves the visible month to the day's month.
  void select(DateTime day) {
    final d = _dateOnly(day);
    state = d;
    ref.read(visibleMonthProvider.notifier).show(d);
  }
}

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(
  SelectedDayNotifier.new,
);

/// First day of the month the grid shows.
class VisibleMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final d = ref.read(selectedDayProvider);
    return DateTime(d.year, d.month);
  }

  void show(DateTime anyDayInMonth) =>
      state = DateTime(anyDayInMonth.year, anyDayInMonth.month);

  void shift(int months) => state = DateTime(state.year, state.month + months);
}

final visibleMonthProvider = NotifierProvider<VisibleMonthNotifier, DateTime>(
  VisibleMonthNotifier.new,
);

/// An occurrence with the event it belongs to.
class AgendaItem {
  const AgendaItem(this.event, this.occurrence);

  final CalendarEvent event;
  final Occurrence occurrence;
}

class CalendarViewData {
  const CalendarViewData({
    required this.day,
    required this.month,
    required this.agenda,
    required this.eventDays,
    required this.unreadableIds,
  });

  final DateTime day;
  final DateTime month;

  /// The selected day's occurrences: all-day first, then by start.
  final List<AgendaItem> agenda;

  /// Day-of-month numbers in [month] that have an occurrence.
  final Set<int> eventDays;

  /// Notes that could not be decoded (never hidden, never fatal).
  final List<String> unreadableIds;
}

/// The time-zone database is initialised at app start; before that (and in
/// widget tests) `tz.local` is unusable and the platform zone applies.
bool _deviceZoneReady() {
  try {
    tz.local;
    return true;
  } catch (_) {
    return false;
  }
}

LocalResolver _resolver() =>
    _deviceZoneReady() ? deviceLocalResolver : defaultLocalResolver;

/// [utc] as wall-clock time in the device zone.
DateTime localTimeOf(DateTime utc) =>
    _deviceZoneReady() ? tz.TZDateTime.from(utc, tz.local) : utc.toLocal();

/// Local date of [o] in the device zone; all-day occurrences are stored at UTC
/// midnight of their date.
DateTime occurrenceDay(Occurrence o) {
  if (o.allDay) return DateTime(o.start.year, o.start.month, o.start.day);
  final l = localTimeOf(o.start);
  return DateTime(l.year, l.month, l.day);
}

DateTime _localMidnightUtc(DateTime d) =>
    _resolver()(d.year, d.month, d.day, 0, 0);

/// Re-reads whenever the repository changes (local edits, sync pulls). In
/// cloud API mode the repository provider throws, which surfaces as an error
/// the screen recognises with `isCalendarCloudApiUnavailable`.
final calendarViewProvider = FutureProvider.autoDispose<CalendarViewData>((
  ref,
) async {
  final day = ref.watch(selectedDayProvider);
  final month = ref.watch(visibleMonthProvider);
  final repo = ref.watch(calendarRepositoryProvider);
  final sub = repo.changes().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);

  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 1);
  // The agenda day can lie outside the visible month (jump from a search).
  final rangeStart = day.isBefore(from) ? day : from;
  final rangeEnd = day.isBefore(to) ? to : day.add(const Duration(days: 1));
  final fromUtc = _localMidnightUtc(rangeStart);
  final toUtc = _localMidnightUtc(rangeEnd);

  final events = <CalendarEvent>[];
  final unreadable = <String>[];
  if (repo is LocalCalendarRepository) {
    for (final r in await repo.readAll()) {
      switch (r) {
        case CalendarEventReadable(:final event):
          events.add(event);
        case CalendarEventUnreadableResult(:final id):
          unreadable.add(id);
      }
    }
  } else {
    events.addAll(await repo.eventsBetween(fromUtc, toUtc));
  }

  final agenda = <AgendaItem>[];
  final days = <int>{};
  for (final e in events) {
    for (final o in expandOccurrences(
      e,
      fromUtc,
      toUtc,
      resolve: _resolver(),
    )) {
      final start = occurrenceDay(o);
      // Mark every day a multi-day occurrence spans (capped).
      var last = start;
      final end = o.end;
      if (end != null && end.isAfter(o.start)) {
        final probe = o.allDay
            ? end.subtract(const Duration(days: 1))
            : end.subtract(const Duration(minutes: 1));
        final endDay = occurrenceDay(
          Occurrence(
            eventId: o.eventId,
            originalStart: o.originalStart,
            start: probe.isBefore(o.start) ? o.start : probe,
            allDay: o.allDay,
          ),
        );
        if (endDay.isAfter(start)) last = endDay;
      }
      var d = start;
      for (var i = 0; i < 62 && !d.isAfter(last); i++) {
        if (d.year == month.year && d.month == month.month) days.add(d.day);
        d = DateTime(d.year, d.month, d.day + 1);
      }
      if (!day.isBefore(start) && !day.isAfter(last)) {
        agenda.add(AgendaItem(e, o));
      }
    }
  }
  agenda.sort((a, b) {
    if (a.occurrence.allDay != b.occurrence.allDay) {
      return a.occurrence.allDay ? -1 : 1;
    }
    return a.occurrence.start.compareTo(b.occurrence.start);
  });

  return CalendarViewData(
    day: day,
    month: month,
    agenda: agenda,
    eventDays: days,
    unreadableIds: unreadable,
  );
});
