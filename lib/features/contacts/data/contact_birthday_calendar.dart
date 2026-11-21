import '../../calendar/domain/calendar_event.dart';
import '../../calendar/domain/event_time.dart';
import '../../calendar/domain/lunar.dart';
import '../../calendar/domain/recurrence_expander.dart';
import '../../calendar/domain/recurrence_rule.dart';
import '../domain/entities/contact_birthday.dart';

/// First day of the birthday series: the birth year when known (and, for a
/// lunar date, inside the supported range), else 2000. Null when the lunar
/// date cannot be resolved (the caller skips it).
AllDay? birthdaySeriesStart(ContactBirthday b) {
  if (b.calendar == BirthdayCalendar.gregorian) {
    return AllDay(b.year ?? 2000, b.month, b.day);
  }
  final y = b.year;
  final inRange = y != null && y >= kLunarMinYear && y <= kLunarMaxYear;
  final d = fromLunarBackward(inRange ? y : 2000, b.month, b.day, leap: b.leap);
  return d == null
      ? AllDay(2000, b.month, b.day)
      : AllDay(d.year, d.month, d.day);
}

RecurrenceRule birthdayRule(ContactBirthday b) =>
    b.calendar == BirthdayCalendar.gregorian
    ? RecurrenceRule.gregorianYearlyBackward()
    : RecurrenceRule.lunarYearly(month: b.month, day: b.day, leap: b.leap);

/// The first occurrence on or after [today]'s calendar day (as a UTC date),
/// computed with the calendar's own expander so both always agree. Null when
/// none falls in the next two years (a lunar date past 2099).
DateTime? nextBirthday(ContactBirthday b, DateTime today) {
  final from = DateTime.utc(today.year, today.month, today.day);
  final start = birthdaySeriesStart(b);
  if (start == null) return null;
  final event = CalendarEvent(
    id: 'birthday-probe',
    title: '',
    start: start,
    rrule: birthdayRule(b).format(),
    updatedAt: from,
  );
  // Widen by a day each side: an all-day start is a local-midnight instant.
  final occurrences = expandOccurrences(
    event,
    from.subtract(const Duration(days: 1)),
    DateTime.utc(from.year + 2, from.month, from.day + 1),
  );
  DateTime? best;
  for (final o in occurrences) {
    final s = o.originalStart;
    if (s is! AllDay) continue;
    final d = DateTime.utc(s.year, s.month, s.day);
    if (d.isBefore(from)) continue;
    if (best == null || d.isBefore(best)) best = d;
  }
  return best;
}
