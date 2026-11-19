import 'package:intl/intl.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/lunar.dart';
import '../../domain/recurrence_rule.dart';

/// Short weekday name ("Mon", "周一") in [l]'s locale.
String weekdayShortName(Weekday w, AppLocalizations l) =>
    // 2024-01-01 was a Monday.
    DateFormat.E(l.localeName).format(DateTime(2024, 1, w.isoWeekday));

/// [r] in words, e.g. "Every Mon, Wed, Fri", "Every day, 5 times" or "Every
/// year on 农历八月十五" (the lunar part is Chinese in every language). Any
/// other lunar rule reads "Lunar repeat" and any other rule outside the
/// subset "Custom repeat" (ruling R-3).
String describeRepeat(RecurrenceRule r, AppLocalizations l) {
  if (r.isLunar && !r.isSupportedLunar) return l.calendarRepeatLunar;
  if (r.isCustom) return l.calendarRepeatCustom;
  final n = r.interval;
  final base = r.isSupportedLunar
      ? l.calendarRepeatLunarYearlyText(
          n,
          lunarMonthDayText(
            r.byMonth!,
            r.byMonthDay.single,
            leap: r.byMonthLeap,
          ),
        )
      : switch (r.freq) {
          Frequency.daily => l.calendarRepeatDailyText(n),
          Frequency.weekly =>
            r.byDay.isEmpty
                ? l.calendarRepeatWeeklyText(n)
                : l.calendarRepeatWeeklyOnText(
                    n,
                    ([...r.byDay]..sort((a, b) => a.index - b.index))
                        .map((d) => weekdayShortName(d, l))
                        .join(l.calendarListSeparator),
                  ),
          Frequency.monthly =>
            r.byMonthDay.isEmpty
                ? l.calendarRepeatMonthlyText(n)
                : l.calendarRepeatMonthlyOnText(
                    n,
                    r.byMonthDay.join(l.calendarListSeparator),
                  ),
          Frequency.yearly => l.calendarRepeatYearlyText(n),
        };
  final count = r.count;
  final until = r.until;
  if (count != null) {
    return l.calendarRepeatWithLimit(base, l.calendarRepeatTimes(count));
  }
  if (until != null) {
    final date = DateFormat.yMMMd(
      l.localeName,
    ).format(DateTime(until.year, until.month, until.day));
    return l.calendarRepeatWithLimit(base, l.calendarRepeatUntil(date));
  }
  return base;
}
