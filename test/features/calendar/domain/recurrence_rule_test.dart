import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/presentation/widgets/repeat_picker.dart'
    show describeRuleText;
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_rule.dart';

void main() {
  test('weekly rule round-trips', () {
    const text = 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=6';
    final r = RecurrenceRule.parse(text);
    expect(r.freq, Frequency.weekly);
    expect(r.interval, 2);
    expect(r.byDay, [Weekday.mo, Weekday.we]);
    expect(r.count, 6);
    expect(r.isCustom, isFalse);
    expect(r.isLunar, isFalse);
    expect(r.format(), text);
  });

  test('monthly BYMONTHDAY and UNTIL parse and format', () {
    final r = RecurrenceRule.parse(
      'FREQ=MONTHLY;BYMONTHDAY=1,15;UNTIL=20271231',
    );
    expect(r.byMonthDay, [1, 15]);
    expect(r.until, DateTime.utc(2027, 12, 31));
    expect(r.format(), 'FREQ=MONTHLY;BYMONTHDAY=1,15;UNTIL=20271231');
    final z = RecurrenceRule.parse('FREQ=DAILY;UNTIL=20271231T235959Z');
    expect(z.until, DateTime.utc(2027, 12, 31, 23, 59, 59));
    expect(z.format(), 'FREQ=DAILY;UNTIL=20271231T235959Z');
  });

  test('local-form UNTIL (no Z) is floating wall-clock and round-trips', () {
    final r = RecurrenceRule.parse('FREQ=DAILY;UNTIL=20271231T090000');
    expect(r.untilIsDate, isFalse);
    expect(r.untilIsFloating, isTrue);
    // Wall-clock fields, not converted.
    expect(r.until, DateTime.utc(2027, 12, 31, 9, 0, 0));
    expect(r.isCustom, isFalse);
    expect(r.format(), 'FREQ=DAILY;UNTIL=20271231T090000');
    final z = RecurrenceRule.parse('FREQ=DAILY;UNTIL=20271231T090000Z');
    expect(z.untilIsFloating, isFalse);
  });

  test('unsupported parts are kept verbatim and make it custom', () {
    final r = RecurrenceRule.parse('FREQ=MONTHLY;BYSETPOS=-1;BYDAY=FR');
    expect(r.isCustom, isTrue);
    expect(r.format(), contains('BYSETPOS=-1'));
  });

  test('lunar rule parses, is custom and is returned unchanged', () {
    const text = 'RSCALE=CHINESE;FREQ=MONTHLY;BYMONTHDAY=1';
    final r = RecurrenceRule.parse(text);
    expect(r.isLunar, isTrue);
    expect(r.isCustom, isTrue);
    expect(r.rscale, 'CHINESE');
    expect(r.format(), text);
  });

  test('RSCALE=GREGORIAN is an ordinary rule', () {
    final r = RecurrenceRule.parse('RSCALE=GREGORIAN;FREQ=DAILY');
    expect(r.isLunar, isFalse);
    expect(r.isCustom, isFalse);
  });

  test('garbage is a FormatException', () {
    expect(() => RecurrenceRule.parse('INTERVAL=2'), throwsFormatException);
    expect(() => RecurrenceRule.parse('FREQ=HOURLY'), throwsFormatException);
    expect(
      () => RecurrenceRule.parse('FREQ=DAILY;COUNT=x'),
      throwsFormatException,
    );
  });

  test('supported lunar rule parses BYMONTH/SKIP', () {
    final r = RecurrenceRule.parse(
      'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4L;BYMONTHDAY=30;SKIP=BACKWARD',
    );
    expect(
      [r.byMonth, r.byMonthLeap, r.skip, r.byMonthDay],
      [
        4,
        true,
        'BACKWARD',
        [30],
      ],
    );
    expect(r.isSupportedLunar, isTrue);
    expect(r.isCustom, isFalse);
    expect(r.unsupported, '');
  });

  test('SKIP absent is still supported (read as BACKWARD)', () {
    final r = RecurrenceRule.parse(
      'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15',
    );
    expect(r.isSupportedLunar, isTrue);
    expect(r.format(), 'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15');
  });

  test('unsupported lunar shapes stay custom and verbatim', () {
    for (final t in [
      'RSCALE=CHINESE;FREQ=MONTHLY;BYMONTHDAY=1',
      'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15;SKIP=FORWARD',
      'RSCALE=HEBREW;FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=1',
      'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4,5;BYMONTHDAY=15',
    ]) {
      final r = RecurrenceRule.parse(t);
      expect(r.isSupportedLunar, isFalse, reason: t);
      expect(r.isCustom, isTrue, reason: t);
      expect(r.format(), t, reason: t);
    }
  });

  test('lunarYearly formats canonically', () {
    expect(
      RecurrenceRule.lunarYearly(month: 10, day: 28).format(),
      'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=28;SKIP=BACKWARD',
    );
    expect(
      RecurrenceRule.lunarYearly(
        month: 4,
        day: 30,
        leap: true,
        interval: 2,
        count: 5,
      ).format(),
      'RSCALE=CHINESE;FREQ=YEARLY;INTERVAL=2;BYMONTH=4L;BYMONTHDAY=30;SKIP=BACKWARD;COUNT=5',
    );
    expect(
      RecurrenceRule.parse(
        RecurrenceRule.lunarYearly(month: 4, day: 8, leap: true).format(),
      ).isSupportedLunar,
      isTrue,
    );
  });

  test('Gregorian rules with BYMONTH/SKIP are unchanged', () {
    const t = 'FREQ=YEARLY;BYMONTH=3;SKIP=OMIT;BYDAY=1MO';
    final r = RecurrenceRule.parse(t);
    expect(r.byMonth, isNull);
    expect(r.isCustom, isTrue);
    expect(r.format(), t);
  });

  test(
    'RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD round-trips and is not custom',
    () {
      final r = RecurrenceRule.parse(
        'RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD',
      );
      expect(r.skip, 'BACKWARD');
      expect(r.unsupported, isEmpty);
      expect(r.isCustom, isFalse);
      expect(r.isGregorianSkipBackward, isTrue);
      expect(
        RecurrenceRule.gregorianYearlyBackward().format(),
        'RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD',
      );
      expect(
        RecurrenceRule.parse('FREQ=YEARLY').isGregorianSkipBackward,
        isFalse,
      );
    },
  );

  test('repeat description reads the Gregorian fallback rule as yearly', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(
      describeRuleText(RecurrenceRule.gregorianYearlyBackward().format(), l),
      describeRuleText('FREQ=YEARLY', l),
    );
    expect(
      describeRuleText(RecurrenceRule.gregorianYearlyBackward().format(), l),
      isNot(l.calendarRepeatCustom),
    );
  });
}
