import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../calendar/domain/lunar.dart';
import '../data/contact_birthday_calendar.dart';
import '../domain/entities/contact_birthday.dart';

/// The birthday as text. Gregorian: the locale's date, with the year only when
/// known. Lunar: Chinese month and day (and the year when known).
String birthdayText(ContactBirthday b, String locale) {
  if (b.calendar == BirthdayCalendar.lunar) {
    final md = lunarMonthDayText(b.month, b.day, leap: b.leap);
    return b.year == null ? md : '${b.year} $md';
  }
  return b.year == null
      ? DateFormat.MMMMd(locale).format(DateTime(2000, b.month, b.day))
      : DateFormat.yMMMMd(locale).format(DateTime(b.year!, b.month, b.day));
}

/// Age today, or null when the year is unknown. Lunar: lunar year now minus
/// the stored lunar year. Gregorian: completed years.
int? birthdayAge(ContactBirthday b, DateTime today) {
  final y = b.year;
  if (y == null) return null;
  if (b.calendar == BirthdayCalendar.lunar) {
    final now = toLunar(today)?.year;
    return now == null ? null : now - y;
  }
  var age = today.year - y;
  if (today.month < b.month || (today.month == b.month && today.day < b.day)) {
    age--;
  }
  return age;
}

/// The detail-screen line: date, age when known, and for a lunar birthday the
/// next Gregorian date.
String birthdayDetailText(
  BuildContext context,
  ContactBirthday b, {
  DateTime? today,
}) {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final now = today ?? DateTime.now();
  final parts = <String>[birthdayText(b, locale)];
  final age = birthdayAge(b, now);
  if (age != null && age >= 0) parts.add(l.contactBirthdayAge(age));
  var text = parts.join(' · ');
  if (b.calendar == BirthdayCalendar.lunar) {
    final next = nextBirthday(b, now);
    if (next != null) {
      text +=
          ' · ${l.contactBirthdayNext(DateFormat.yMMMd(locale).format(next))}';
    }
  }
  return text;
}
