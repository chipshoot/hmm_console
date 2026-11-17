import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/i_reminder_scheduler.dart';
import 'notification_gateway.dart';
import 'reminder_plan.dart';

/// Payload prefix of every notification the calendar schedules.
const String kCalendarPayloadPrefix = 'calendar|';

class LocalReminderScheduler implements IReminderScheduler {
  LocalReminderScheduler(this._gateway);

  final NotificationGateway _gateway;

  @override
  Future<void> reschedule(List<PlannedReminder> upcoming) async {
    await cancelAll();
    for (final r in upcoming) {
      await _gateway.schedule(r);
    }
  }

  @override
  Future<void> cancelAll() async {
    for (final p in await _gateway.pending()) {
      if (p.payload?.startsWith(kCalendarPayloadPrefix) ?? false) {
        await _gateway.cancel(p.id);
      }
    }
  }

  @override
  Future<bool> requestPermission() => _gateway.requestPermission();
}

final reminderSchedulerProvider = Provider<IReminderScheduler>(
  (ref) => LocalReminderScheduler(ref.watch(notificationGatewayProvider)),
);
