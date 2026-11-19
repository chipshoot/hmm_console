import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/notifications/local_reminder_scheduler.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_plan.dart';

import '../support/fake_notification_gateway.dart';

PlannedReminder _r(int id, String payload) => PlannedReminder(
  id: id,
  fireAtUtc: DateTime.utc(2026, 11, 18, 10),
  title: 'T',
  payload: payload,
);

class _FailingGateway extends FakeNotificationGateway {
  _FailingGateway({required this.failIds});
  final Set<int> failIds;
  @override
  Future<void> schedule(PlannedReminder r) async {
    if (failIds.contains(r.id)) throw StateError('zonedSchedule failed');
    return super.schedule(r);
  }
}

void main() {
  test(
    'reschedule replaces calendar entries and leaves others alone',
    () async {
      final gw = FakeNotificationGateway()
        ..addPending(1, 'other|x')
        ..addPending(2, 'calendar|old|2026-11-18T09:00');
      final s = LocalReminderScheduler(gw);

      await s.reschedule([_r(3, 'calendar|e|2026-11-18T10:00')]);

      expect(gw.pendingById.keys, unorderedEquals([1, 3]));
      expect(gw.pendingById[1]!.payload, 'other|x');
      expect(gw.cancelled, [2]);
      expect(gw.scheduled.map((r) => r.id), [3]);
    },
  );

  test('one failing schedule does not stop the rest', () async {
    final gw = _FailingGateway(failIds: {4});
    final s = LocalReminderScheduler(gw);
    await s.reschedule([
      _r(3, 'calendar|a|x'),
      _r(4, 'calendar|b|x'),
      _r(5, 'calendar|c|x'),
    ]);
    expect(gw.scheduled.map((r) => r.id), [3, 5]);
  });

  test('the gateway gets each reminder\'s priority and badge number', () async {
    final gw = FakeNotificationGateway();
    await LocalReminderScheduler(gw).reschedule([
      PlannedReminder(
        id: 3,
        fireAtUtc: DateTime.utc(2026, 11, 18, 10),
        title: 'T',
        payload: 'calendar|a|x',
        timeSensitive: true,
        badgeNumber: 4,
      ),
      _r(5, 'calendar|b|x'),
    ]);
    expect(gw.scheduled.map((r) => (r.timeSensitive, r.badgeNumber)), [
      (true, 4),
      (false, null),
    ]);
  });

  test('cancelAll removes only calendar entries', () async {
    final gw = FakeNotificationGateway()
      ..addPending(1, 'other|x')
      ..addPending(2, 'calendar|a|x')
      ..addPending(4, null);
    await LocalReminderScheduler(gw).cancelAll();
    expect(gw.pendingById.keys, unorderedEquals([1, 4]));
  });

  test('requestPermission delegates to the gateway', () async {
    final gw = FakeNotificationGateway(granted: false);
    expect(await LocalReminderScheduler(gw).requestPermission(), isFalse);
    gw.granted = true;
    expect(await LocalReminderScheduler(gw).requestPermission(), isTrue);
  });
}
