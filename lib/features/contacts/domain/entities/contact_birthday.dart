import '../../../calendar/domain/calendar_event.dart';
import '../../../calendar/domain/event_time.dart';
import '../../../calendar/domain/lunar.dart';
import '../../../calendar/domain/recurrence_expander.dart';
import '../../../calendar/domain/recurrence_rule.dart';

/// Stored by `name`. NEVER localize.
enum BirthdayCalendar { gregorian, lunar }

/// A contact's birthday: a month and day on the Gregorian or lunar calendar,
/// with an optional birth year (gives the age).
class ContactBirthday {
  const ContactBirthday({
    required this.calendar,
    required this.month,
    required this.day,
    this.leap = false,
    this.year,
  });

  final BirthdayCalendar calendar;
  final int month;
  final int day;

  /// Lunar leap month; always false for a Gregorian birthday.
  final bool leap;
  final int? year;

  Map<String, Object?> toJson() => {
    'calendar': calendar.name,
    'month': month,
    'day': day,
    if (calendar == BirthdayCalendar.lunar) 'leap': leap,
    if (year != null) 'year': year,
  };

  /// Null on any invalid value (wrong type, out-of-range month or day, leap
  /// on a Gregorian date).
  static ContactBirthday? fromJson(Object? v) {
    if (v is! Map) return null;
    final cal = BirthdayCalendar.values
        .where((c) => c.name == v['calendar'])
        .firstOrNull;
    final month = v['month'];
    final day = v['day'];
    final leap = v['leap'] ?? false;
    final year = v['year'];
    if (cal == null || month is! int || day is! int || leap is! bool) {
      return null;
    }
    if (year != null && (year is! int || year < 1000 || year > 9999)) {
      return null;
    }
    if (month < 1 || month > 12) return null;
    if (cal == BirthdayCalendar.gregorian) {
      if (leap) return null;
      // The series anchors on the birth year, or on a leap year (2000).
      final y = (year as int?) ?? 2000;
      if (day < 1 || day > DateTime.utc(y, month + 1, 0).day) return null;
    } else if (day < 1 || day > 30) {
      return null;
    }
    return ContactBirthday(
      calendar: cal,
      month: month,
      day: day,
      leap: leap,
      year: year as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ContactBirthday &&
      other.calendar == calendar &&
      other.month == month &&
      other.day == day &&
      other.leap == leap &&
      other.year == year;

  @override
  int get hashCode => Object.hash(calendar, month, day, leap, year);
}

/// First day of the birthday series: the birth year when known (and, for a
/// lunar date, inside the supported range), else 2000.
AllDay birthdaySeriesStart(ContactBirthday b) {
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
  final event = CalendarEvent(
    id: 'birthday-probe',
    title: '',
    start: birthdaySeriesStart(b),
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
