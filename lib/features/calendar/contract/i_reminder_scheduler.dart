import '../notifications/reminder_plan.dart';

/// Delivers planned reminders to this device. Planning is pure
/// (`planReminders`); scheduling is only delivery (ruling R-5).
abstract interface class IReminderScheduler {
  /// Cancels every pending calendar reminder (payload `calendar|…`) and
  /// schedules [upcoming]. Notifications from other features are untouched.
  Future<void> reschedule(List<PlannedReminder> upcoming);

  /// Cancels every pending calendar reminder and schedules none.
  Future<void> cancelAll();

  /// Asks the OS for notification permission; true when granted.
  Future<bool> requestPermission();
}
