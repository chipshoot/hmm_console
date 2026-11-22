import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';

void main() {
  test('parses an offset time and round-trips it', () {
    final t = OffsetDateTime.tryParse('2026-11-21T18:40:00-05:00')!;
    expect(t.utc, DateTime.utc(2026, 11, 21, 23, 40));
    expect(t.offset, const Duration(hours: -5));
    expect(t.toIso(), '2026-11-21T18:40:00-05:00');
    expect(t.wallDate, DateTime.utc(2026, 11, 21));
  });

  test('wall date is the recorded one, not the UTC one', () {
    final t = OffsetDateTime.tryParse('2026-11-21T23:30:00-05:00')!;
    expect(t.utc.day, 22);
    expect(t.wallDate, DateTime.utc(2026, 11, 21));
    expect(t.wall, DateTime.utc(2026, 11, 21, 23, 30));
  });

  test('garbage is null', () {
    expect(OffsetDateTime.tryParse('garbage'), isNull);
    expect(OffsetDateTime.tryParse('2026-11-21T18:40:00'), isNull);
  });

  test('Z reads as a zero offset and writes +00:00', () {
    final t = OffsetDateTime.tryParse('2026-11-21T18:40:00Z')!;
    expect(t.offset, Duration.zero);
    expect(t.toIso(), endsWith('+00:00'));
  });

  test('fromLocal keeps the device offset', () {
    final local = DateTime(2026, 11, 21, 8, 5);
    final t = OffsetDateTime.fromLocal(local);
    expect(t.utc, local.toUtc());
    expect(t.offset, local.timeZoneOffset);
  });
}
