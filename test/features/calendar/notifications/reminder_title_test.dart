import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/i18n/locale_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/occurrence.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _event = CalendarEvent(
  id: 'w',
  title: 'Evening walk',
  start: const FloatingTime(2026, 11, 18, 19, 0),
  updatedAt: DateTime.utc(2026),
);

Occurrence _timed(DateTime startUtc, {String? override}) => Occurrence(
  eventId: 'w',
  originalStart: const FloatingTime(2026, 11, 18, 19, 0),
  start: startUtc,
  titleOverride: override,
);

final _allDay = Occurrence(
  eventId: 'w',
  originalStart: const AllDay(2026, 11, 18),
  start: DateTime.utc(2026, 11, 17, 16),
  allDay: true,
);

/// Device zone pinned to UTC+8 whatever the host's.
DateTime _plus8(DateTime utc) => utc.toUtc().add(const Duration(hours: 8));

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('timed: "<local time> · <title>" in the device zone', () {
    final t = reminderTitle(
      _event,
      _timed(DateTime.utc(2026, 11, 18, 11, 0)),
      allDayLabel: 'All day',
      formatTime: shortTimeFormatter('en', use24h: true),
      toLocal: _plus8,
    );
    expect(t, '19:00 · Evening walk');
  });

  test('12-hour locale format when the device is not on 24-hour time', () {
    final t = reminderTitle(
      _event,
      _timed(DateTime.utc(2026, 11, 18, 11, 0)),
      allDayLabel: 'All day',
      formatTime: shortTimeFormatter('en', use24h: false),
      toLocal: _plus8,
    );
    expect(t, matches(RegExp(r'^7:00\sPM · Evening walk$')));
  });

  test('all-day: "<All day> · <title>"; a per-occurrence title wins', () {
    expect(
      reminderTitle(
        _event,
        _allDay,
        allDayLabel: '全天',
        formatTime: shortTimeFormatter('en', use24h: true),
        toLocal: _plus8,
      ),
      '全天 · Evening walk',
    );
    expect(
      reminderTitle(
        _event,
        _timed(DateTime.utc(2026, 11, 18, 11, 0), override: 'Short walk'),
        allDayLabel: 'All day',
        formatTime: shortTimeFormatter('en', use24h: true),
        toLocal: _plus8,
      ),
      '19:00 · Short walk',
    );
  });

  test('the default title carries the time too', () {
    final o = _timed(DateTime.utc(2026, 11, 18, 11, 0));
    final t = defaultReminderTitle(_event, o);
    expect(t, endsWith(' · Evening walk'));
    expect(t, contains(':'));
    expect(defaultReminderTitle(_event, _allDay), 'All day · Evening walk');
  });

  test('provider formatter follows the chosen app locale', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'zh'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(localeProvider);
    await pumpEventQueue();
    expect(c.read(localeProvider), const Locale('zh'));
    final format = c.read(reminderTitleFormatProvider);
    expect(format(_event, _allDay), '全天 · Evening walk');
  });
}
