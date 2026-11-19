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
  /// Bumped by every build; markSeen uses it to tell whether the state it
  /// read is still current.
  int _generation = 0;

  /// "Remind on this device" as the previous build saw it.
  bool? _lastRemindOn;

  @override
  Future<RemindersInbox> build() async {
    _generation++;
    final repo = ref.watch(calendarRepositoryProvider);
    final remindOn = ref.watch(remindOnDeviceProvider);
    final formatTitle = ref.watch(reminderTitleFormatProvider);
    final clock = ref.watch(remindersInboxClockProvider);
    // Just switched back on: what fired while off never showed, and
    // ReminderSync restarts the count from now on its next run (which may
    // not have stored the new seen instant yet).
    final justTurnedOn = _lastRemindOn == false && remindOn;
    _lastRemindOn = remindOn;

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

    final now = clock();
    final seenAt = await _readSeenAt();
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
    final unseen = !remindOn || justTurnedOn || seenAt == null
        ? 0
        : items.where((r) => r.fireAtUtc.isAfter(seenAt)).length;
    return RemindersInbox(items: items, unseen: unseen);
  }

  static Future<DateTime?> _readSeenAt() async {
    try {
      return await readRemindersSeenAt();
    } catch (e) {
      debugPrint('remindersInbox: seen state unavailable (${e.runtimeType})');
      return null;
    }
  }

  /// The owner looked at the inbox: seen = now, the icon badge is cleared
  /// and pending badge numbers restart from 1 (a ReminderSync run).
  Future<void> markSeen() async {
    // Everything is read before the first await.
    final gateway = ref.read(notificationGatewayProvider);
    final sync = ref.read(reminderSyncProvider);
    final now = ref.read(remindersInboxClockProvider)();
    final before = state.value;
    final generation = _generation;

    try {
      await writeRemindersSeenAt(now);
    } catch (e) {
      debugPrint('remindersInbox: seen state not stored (${e.runtimeType})');
    }
    await gateway.clearBadge();
    sync.trigger();

    if (!ref.mounted) return;
    if (before != null && generation == _generation) {
      state = AsyncData(RemindersInbox(items: before.items, unseen: 0));
    } else {
      // Still loading (it may have read the old seen instant): load again.
      ref.invalidateSelf();
    }
  }
}

final remindersInboxProvider =
    AsyncNotifierProvider.autoDispose<RemindersInboxNotifier, RemindersInbox>(
      RemindersInboxNotifier.new,
    );
