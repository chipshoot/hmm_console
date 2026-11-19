import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_rule.dart';
import 'package:hmm_console/features/calendar/states/event_edit_state.dart';

CalendarEvent _ev(EventTime start, String rrule) => CalendarEvent(
  id: 'e1',
  title: 'T',
  start: start,
  rrule: rrule,
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('truncateBefore with lunar rules', () {
    test('a supported lunar series keeps its lunar parts and gets UNTIL', () {
      final e = _ev(
        const AllDay(2024, 2, 9),
        'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=30;SKIP=BACKWARD',
      );
      final t = truncateBefore(e, const AllDay(2026, 2, 16));
      expect(t, isNotNull);
      final r = RecurrenceRule.parse(t!.rrule!);
      expect(r.isSupportedLunar, isTrue);
      expect(r.byMonth, 12);
      expect(r.byMonthLeap, isFalse);
      expect(r.byMonthDay, [30]);
      expect(r.skip, 'BACKWARD');
      expect(r.until, DateTime.utc(2026, 2, 15));
      expect(r.untilIsDate, isTrue);
      expect(t.rrule, contains('UNTIL=20260215'));
    });

    test('a leap-month series keeps the leap flag', () {
      final e = _ev(
        const AllDay(2025, 7, 25),
        'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=6L;BYMONTHDAY=1',
      );
      final t = truncateBefore(e, const AllDay(2026, 7, 14));
      expect(t, isNotNull);
      final r = RecurrenceRule.parse(t!.rrule!);
      expect(r.byMonth, 6);
      expect(r.byMonthLeap, isTrue);
    });

    test('an unsupported lunar series still returns null', () {
      final e = _ev(
        const AllDay(2024, 2, 10),
        'RSCALE=CHINESE;FREQ=MONTHLY;BYMONTHDAY=1',
      );
      expect(truncateBefore(e, const AllDay(2024, 3, 10)), isNull);
    });
  });
}
