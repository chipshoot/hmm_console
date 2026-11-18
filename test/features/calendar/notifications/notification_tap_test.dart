import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/notifications/notification_tap.dart';

void main() {
  test('a calendar payload routes to the event occurrence', () {
    expect(
      calendarRouteForPayload('calendar|abc|floating:2026-11-18T19:00'),
      '/calendar/event/abc?at=floating%3A2026-11-18T19%3A00',
    );
  });

  test('a payload without an occurrence routes to the event', () {
    expect(calendarRouteForPayload('calendar|abc'), '/calendar/event/abc');
  });

  test('non-calendar and malformed payloads are ignored', () {
    expect(calendarRouteForPayload('other|x'), isNull);
    expect(calendarRouteForPayload('calendar|'), isNull);
    expect(calendarRouteForPayload(''), isNull);
  });
}
