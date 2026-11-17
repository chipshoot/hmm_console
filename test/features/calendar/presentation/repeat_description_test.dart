import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_rule.dart';
import 'package:hmm_console/features/calendar/presentation/widgets/repeat_description.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  // In the app the localization delegates load this.
  setUpAll(initializeDateFormatting);
  final en = lookupAppLocalizations(const Locale('en'));
  String d(String rule) => describeRepeat(RecurrenceRule.parse(rule), en);

  test('weekly with weekdays reads as a list of days', () {
    expect(d('FREQ=WEEKLY;BYDAY=MO,WE,FR'), 'Every Mon, Wed, Fri');
  });

  test('simple frequencies and intervals', () {
    expect(d('FREQ=DAILY'), 'Every day');
    expect(d('FREQ=DAILY;INTERVAL=3'), 'Every 3 days');
    expect(d('FREQ=WEEKLY'), 'Every week');
    expect(d('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU'), 'Every 2 weeks on Tue');
    expect(d('FREQ=MONTHLY'), 'Every month');
    expect(d('FREQ=MONTHLY;BYMONTHDAY=15'), 'Monthly on day 15');
    expect(d('FREQ=YEARLY'), 'Every year');
  });

  test('count and until are appended', () {
    expect(d('FREQ=DAILY;COUNT=5'), 'Every day, 5 times');
    expect(d('FREQ=DAILY;UNTIL=20300114'), 'Every day, until Jan 14, 2030');
  });

  test('a rule with parts outside the subset reads "Custom repeat"', () {
    expect(d('FREQ=MONTHLY;BYDAY=1MO'), 'Custom repeat');
    expect(d('FREQ=DAILY;BYHOUR=9'), 'Custom repeat');
  });

  test('a lunar rule reads "Lunar repeat"', () {
    expect(
      d('RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15'),
      'Lunar repeat',
    );
  });

  test('zh has its own wording', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(
      describeRepeat(RecurrenceRule.parse('FREQ=DAILY'), zh),
      isNot('Every day'),
    );
  });
}
