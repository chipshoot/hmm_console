import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_gateway.dart';
import '../notifications/reminder_plan.dart';
import '../notifications/reminder_sync.dart';
import 'calendar_providers.dart';
import 'remind_on_device_provider.dart';
import 'reminders_seen_provider.dart';

/// Reminders fired in the last [kRemindersInboxWindow], newest first, and
/// how many of them fired after the inbox was last seen on this device.
class RemindersInbox {
  const RemindersInbox({required this.items, required this.unseen});

  final List<FiredReminder> items;
  final int unseen;
}

/// The inbox's clock (UTC). Tests pin it.
final remindersInboxClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// Re-reads on every repository change, on return to the foreground and
/// when the next reminder fires, so the dashboard bell keeps up. In cloud
/// API mode the build fails with the repository's error, which callers
/// recognise with `isCalendarCloudApiUnavailable`.
class RemindersInboxNotifier extends AsyncNotifier<RemindersInbox> {
  @override
  Future<RemindersInbox> build() async {
    final repo = ref.watch(calendarRepositoryProvider);
    final remindOn = ref.watch(remindOnDeviceProvider);
    final formatTitle = ref.watch(reminderTitleFormatProvider);
    final clock = ref.watch(remindersInboxClockProvider);

    // changes() never emits its current snapshot, so this cannot loop.
    final sub = repo.changes().listen(
      (_) => ref.invalidateSelf(),
      onError: (Object e) =>
          debugPrint('remindersInbox: changes failed (${e.runtimeType})'),
    );
    final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
    Timer? nextFire;
    ref.onDispose(() {
      unawaited(sub.cancel());
      lifecycle.dispose();
      nextFire?.cancel();
    });

    // Watched: ReminderSync's writes (first run, remind-off runs, the first
    // run back on) and markSeen's rebuild the count.
    final seenAt = await _seenAt();
    final now = clock();
    final events = await loadReminderEvents(repo, now);
    final items = firedReminders(
      events: events,
      fromUtc: now.subtract(kRemindersInboxWindow),
      toUtc: now,
      resolve: deviceLocalResolver,
      formatTitle: formatTitle,
    );

    // The next reminder within a week: refresh when it fires.
    final upcoming = firedReminders(
      events: events,
      fromUtc: now,
      toUtc: now.add(kRemindersInboxWindow),
      resolve: deviceLocalResolver,
      formatTitle: formatTitle,
    );
    // A superseded build has already run its onDispose: no timer then.
    if (ref.mounted && upcoming.isNotEmpty) {
      final wait = upcoming.last.fireAtUtc.difference(now);
      nextFire = Timer(wait + const Duration(seconds: 1), ref.invalidateSelf);
    }

    // R-1: unset means "now" (ReminderSync owns the first write). Nothing
    // shows on this device while its reminders are off, so nothing counts.
    final unseen = !remindOn || seenAt == null
        ? 0
        : items.where((r) => r.fireAtUtc.isAfter(seenAt)).length;
    return RemindersInbox(items: items, unseen: unseen);
  }

  Future<DateTime?> _seenAt() async {
    try {
      return await ref.watch(remindersSeenAtProvider.future);
    } catch (e) {
      debugPrint('remindersInbox: seen state unavailable (${e.runtimeType})');
      return null;
    }
  }

  /// The owner looked at the inbox: seen = now (which rebuilds the count),
  /// the icon badge is cleared and pending badge numbers restart from 1 (a
  /// ReminderSync run).
  Future<void> markSeen() async {
    // Everything is read before the first await.
    final seen = ref.read(remindersSeenAtProvider.notifier);
    final gateway = ref.read(notificationGatewayProvider);
    final sync = ref.read(reminderSyncProvider);
    final now = ref.read(remindersInboxClockProvider)();

    try {
      await seen.write(now);
    } catch (e) {
      debugPrint('remindersInbox: seen state not stored (${e.runtimeType})');
    }
    try {
      await gateway.clearBadge();
    } catch (e) {
      debugPrint('remindersInbox: badge not cleared (${e.runtimeType})');
    }
    sync.trigger();
  }
}

final remindersInboxProvider =
    AsyncNotifierProvider.autoDispose<RemindersInboxNotifier, RemindersInbox>(
      RemindersInboxNotifier.new,
    );
