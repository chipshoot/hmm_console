import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/local_calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/event_time.dart';
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

/// Resolves wall-clock times in the device zone (the `timezone` zone once
/// initialised, else the platform zone).
LocalResolver deviceResolver() =>
    _deviceZoneReady() ? deviceLocalResolver : defaultLocalResolver;

/// Wall-clock [w] in the device zone as a [FixedTime] carrying the device's
/// offset at that instant.
FixedTime fixedTimeAtWall(DateTime w) {
  if (_deviceZoneReady()) {
    final t = tz.TZDateTime(tz.local, w.year, w.month, w.day, w.hour, w.minute);
    return FixedTime(t.toUtc(), t.timeZoneOffset);
  }
  final d = DateTime(w.year, w.month, w.day, w.hour, w.minute);
  return FixedTime(d.toUtc(), d.timeZoneOffset);
}

/// [utc] as wall-clock time in the device zone.
DateTime localTimeOf(DateTime utc) =>
    _deviceZoneReady() ? tz.TZDateTime.from(utc, tz.local) : utc.toLocal();

/// First and last local dates [o] (an occurrence of [e]) covers.
///
/// An all-day occurrence takes its dates from the stored all-day times, so
/// it lands on its own date in any zone; a timed one converts its start and
/// end (less a minute, the end being exclusive) with [toLocal].
({DateTime first, DateTime last}) occurrenceDays(
  CalendarEvent e,
  Occurrence o, {
  DateTime Function(DateTime utc) toLocal = localTimeOf,
}) {
  if (o.allDay) {
    final d = allDayDateOf(e, o);
    if (d != null) {
      final first = DateTime(d.year, d.month, d.day);
      return (
        first: first,
        last: DateTime(d.year, d.month, d.day + allDaySpanDays(e)),
      );
    }
  }
  final s = toLocal(o.start);
  final first = DateTime(s.year, s.month, s.day);
  var last = first;
  final end = o.end;
  if (end != null && end.isAfter(o.start)) {
    final probe = end.subtract(const Duration(minutes: 1));
    final l = toLocal(probe.isBefore(o.start) ? o.start : probe);
    final endDay = DateTime(l.year, l.month, l.day);
    if (endDay.isAfter(first)) last = endDay;
  }
  return (first: first, last: last);
}

/// The zone the calendar screens do day math in. Null (the default) means
/// the device zone: `tz.local` once initialised, else the platform zone.
/// Tests override it to pin a zone whatever the host's.
final calendarDeviceZoneProvider = Provider<tz.Location?>((ref) => null);

/// Wall-clock → UTC in [zone].
LocalResolver resolverFor(tz.Location zone) =>
    (y, m, d, hh, mm) => tz.TZDateTime(zone, y, m, d, hh, mm).toUtc();

/// Re-reads whenever the repository changes (local edits, sync pulls). In
/// cloud API mode the repository provider throws, which surfaces as an error
/// the screen recognises with `isCalendarCloudApiUnavailable`.
final calendarViewProvider = FutureProvider.autoDispose<CalendarViewData>((
  ref,
) async {
  final day = ref.watch(selectedDayProvider);
  final month = ref.watch(visibleMonthProvider);
  final repo = ref.watch(calendarRepositoryProvider);
  final zone = ref.watch(calendarDeviceZoneProvider);
  final resolve = zone == null ? deviceResolver() : resolverFor(zone);
  final DateTime Function(DateTime) toLocal = zone == null
      ? localTimeOf
      : (u) => tz.TZDateTime.from(u, zone);
  DateTime localMidnightUtc(DateTime d) =>
      resolve(d.year, d.month, d.day, 0, 0);
  final sub = repo.changes().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);

  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 1);
  // The agenda day can lie outside the visible month (jump from a search).
  final rangeStart = day.isBefore(from) ? day : from;
  final rangeEnd = day.isBefore(to) ? to : day.add(const Duration(days: 1));
  final fromUtc = localMidnightUtc(rangeStart);
  final toUtc = localMidnightUtc(rangeEnd);

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
    for (final o in expandOccurrences(e, fromUtc, toUtc, resolve: resolve)) {
      // Mark every day a multi-day occurrence spans (capped).
      final (:first, :last) = occurrenceDays(e, o, toLocal: toLocal);
      final start = first;
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
