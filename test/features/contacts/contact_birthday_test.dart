import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_expander.dart';
import 'package:hmm_console/features/contacts/data/contact_birthday_calendar.dart';
import 'package:hmm_console/features/contacts/domain/entities/contact_birthday.dart';

List<AllDay> _years(ContactBirthday b, int from, int to) {
  final e = CalendarEvent(
    id: 'x',
    title: 't',
    start: birthdaySeriesStart(b)!,
    rrule: birthdayRule(b).format(),
    updatedAt: DateTime.utc(2026),
  );
  return [
    for (final o in expandOccurrences(
      e,
      DateTime.utc(from, 1, 1),
      DateTime.utc(to, 1, 1),
    ))
      o.originalStart as AllDay,
  ];
}

void main() {
  test('29 Feb with unknown year anchors on AllDay(2000, 2, 29)', () {
    const b = ContactBirthday(
      calendar: BirthdayCalendar.gregorian,
      month: 2,
      day: 29,
    );
    final s = birthdaySeriesStart(b)!;
    expect((s.year, s.month, s.day), (2000, 2, 29));
    final days = _years(b, 2026, 2030);
    expect(
      [for (final d in days) (d.year, d.month, d.day)],
      [(2026, 2, 28), (2027, 2, 28), (2028, 2, 29), (2029, 2, 28)],
    );
  });

  for (final b in const [
    ContactBirthday(calendar: BirthdayCalendar.lunar, month: 4, day: 30),
    ContactBirthday(
      calendar: BirthdayCalendar.lunar,
      month: 6,
      day: 1,
      leap: true,
    ),
  ]) {
    test('lunar 三十 and leap-month birthdays occur once every year '
        '2026-2035 (${b.month}/${b.day} leap ${b.leap})', () {
      final days = _years(b, 2026, 2036);
      expect(days, hasLength(10));
      expect(
        [for (final d in days) d.year],
        [for (var y = 2026; y < 2036; y++) y],
      );
    });
  }

  test('fromJson rejects invalid values', () {
    for (final bad in <Object?>[
      'x',
      {'calendar': 'gregorian', 'month': 13, 'day': 1},
      {'calendar': 'gregorian', 'month': 2, 'day': 30},
      {'calendar': 'gregorian', 'month': 2, 'day': 29, 'year': 1900},
      {'calendar': 'gregorian', 'month': 1, 'day': 1, 'leap': true},
      {'calendar': 'lunar', 'month': 1, 'day': 31},
      {'calendar': 'lunar', 'month': 0, 'day': 1},
      {'calendar': 'lunar', 'month': 1, 'day': 1, 'year': '1990'},
      {'calendar': 'solar', 'month': 1, 'day': 1},
    ]) {
      expect(ContactBirthday.fromJson(bad), isNull, reason: '$bad');
    }
  });

  test('json round-trips', () {
    const b = ContactBirthday(
      calendar: BirthdayCalendar.lunar,
      month: 4,
      day: 5,
      leap: true,
      year: 1985,
    );
    expect(ContactBirthday.fromJson(b.toJson()), b);
  });

  test(
    'nextBirthday is today when today is the birthday, else the next one',
    () {
      const b = ContactBirthday(
        calendar: BirthdayCalendar.gregorian,
        month: 3,
        day: 10,
        year: 1990,
      );
      expect(nextBirthday(b, DateTime(2026, 3, 10)), DateTime.utc(2026, 3, 10));
      expect(nextBirthday(b, DateTime(2026, 3, 11)), DateTime.utc(2027, 3, 10));
    },
  );

  test('lunar 2099 month 12 day 30 resolves into February 2100', () {
    const b = ContactBirthday(
      calendar: BirthdayCalendar.lunar,
      month: 12,
      day: 30,
      year: 2099,
    );
    final s = birthdaySeriesStart(b)!;
    expect((s.year, s.month, s.day), (2100, 2, 8));
    expect(nextBirthday(b, DateTime(2026, 1, 1)), isNull);
  });

  test('an unresolvable lunar birthday has no start and no next date', () {
    // Not constructible through fromJson; the model is const-unvalidated.
    const b = ContactBirthday(
      calendar: BirthdayCalendar.lunar,
      month: 13,
      day: 1,
    );
    expect(birthdaySeriesStart(b), isNull);
    expect(nextBirthday(b, DateTime(2026, 1, 1)), isNull);
  });
}
