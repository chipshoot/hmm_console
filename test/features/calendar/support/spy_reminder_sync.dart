import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';

import 'fake_calendar_repository.dart';
import 'fake_notification_gateway.dart';
import 'package:hmm_console/features/calendar/notifications/local_reminder_scheduler.dart';

/// A [ReminderSync] that only counts [trigger] calls (never runs).
class SpyReminderSync extends ReminderSync {
  SpyReminderSync()
    : super(
        repository: FakeCalendarRepository.new,
        scheduler: LocalReminderScheduler(FakeNotificationGateway()),
        permissionGranted: () async => true,
        remindOnDevice: () => true,
        permissionAsked: () async => true,
        askPermissionOnce: () async => null,
        onPermissionChecked: (_) {},
        observeLifecycle: false,
      );

  int triggers = 0;

  @override
  void trigger() => triggers++;
}
