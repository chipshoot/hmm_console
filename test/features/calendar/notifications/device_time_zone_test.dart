import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_expander.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('a readable zone becomes tz.local and drives the resolver', () async {
    await initDeviceTimeZone(readZone: () async => 'Asia/Shanghai');
    expect(deviceZoneKnown, isTrue);
    expect(tz.local.name, 'Asia/Shanghai');
    expect(
      deviceLocalResolver(2026, 11, 18, 9, 0),
      DateTime.utc(2026, 11, 18, 1, 0),
    );
  });

  test('a later read picks up a new zone (travel, R-19)', () async {
    await initDeviceTimeZone(readZone: () async => 'Asia/Shanghai');
    await initDeviceTimeZone(readZone: () async => 'America/Toronto');
    expect(tz.local.name, 'America/Toronto');
    expect(
      deviceLocalResolver(2026, 11, 18, 9, 0),
      DateTime.utc(2026, 11, 18, 14, 0),
    );
  });

  test('a failed read uses the platform zone, never UTC', () async {
    await initDeviceTimeZone(readZone: () async => 'Asia/Shanghai');
    await initDeviceTimeZone(readZone: () async => throw StateError('no'));
    expect(deviceZoneKnown, isFalse);
    expect(tz.local.name, isNot('UTC'));
    expect(
      deviceLocalResolver(2026, 11, 18, 9, 0),
      defaultLocalResolver(2026, 11, 18, 9, 0),
    );
  });

  test('an unknown zone id also falls back to the platform zone', () async {
    await initDeviceTimeZone(readZone: () async => 'Mars/Olympus');
    expect(deviceZoneKnown, isFalse);
    expect(
      deviceLocalResolver(2026, 6, 1, 7, 30),
      defaultLocalResolver(2026, 6, 1, 7, 30),
    );
  });
}
