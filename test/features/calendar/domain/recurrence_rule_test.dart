import 'package:flutter_test/flutter_test.dart';
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

  test('unsupported parts are kept verbatim and make it custom', () {
    final r = RecurrenceRule.parse('FREQ=MONTHLY;BYSETPOS=-1;BYDAY=FR');
    expect(r.isCustom, isTrue);
    expect(r.format(), contains('BYSETPOS=-1'));
  });

  test('lunar rule parses, is custom and is returned unchanged', () {
    const text = 'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15';
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
}
