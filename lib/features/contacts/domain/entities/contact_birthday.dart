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
