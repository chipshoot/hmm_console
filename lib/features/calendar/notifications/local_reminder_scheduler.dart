import 'package:flutter/foundation.dart' show debugPrint;
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
    var failed = 0;
    for (final r in upcoming) {
      // One bad entry (a plugin error for one date, say) must not leave
      // the rest unscheduled.
      try {
        await _gateway.schedule(r);
      } catch (e) {
        failed++;
        debugPrint(
          'Calendar reminder ${r.id} not scheduled (${e.runtimeType})',
        );
      }
    }
    if (failed > 0) {
      debugPrint('Calendar reminders: $failed of ${upcoming.length} failed');
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
