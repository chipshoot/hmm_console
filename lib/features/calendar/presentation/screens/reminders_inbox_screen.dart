import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../contract/calendar_errors.dart';
import '../../notifications/notification_tap.dart';
import '../../notifications/reminder_plan.dart';
import '../../notifications/reminder_sync.dart';
import '../../states/reminders_inbox_state.dart';
import '../widgets/calendar_cloud_api_message.dart';

/// Reminders that fired on this device in the last 7 days, newest first.
/// Opening it marks them seen (once per visit), which clears the dashboard
/// bell's count and the icon badge.
class RemindersInboxScreen extends ConsumerStatefulWidget {
  const RemindersInboxScreen({super.key});

  @override
  ConsumerState<RemindersInboxScreen> createState() =>
      _RemindersInboxScreenState();
}

class _RemindersInboxScreenState extends ConsumerState<RemindersInboxScreen> {
  @override
  void initState() {
    super.initState();
    // R-2: exactly once per open, after the first frame, never from build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(remindersInboxProvider.notifier).markSeen();
    });
  }

  void _open(FiredReminder r) {
    final route = calendarRouteForPayload(r.payload);
    if (route != null) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(remindersInboxProvider);

    Widget body;
    if (async.hasError) {
      final e = async.error!;
      if (isCalendarCloudApiUnavailable(e)) {
        body = const CalendarCloudApiMessage();
      } else {
        // Type only: the error text can quote stored event data.
        debugPrint('Reminders failed to load (${e.runtimeType})');
        body = _Message(l.calendarRemindersLoadFailed);
      }
    } else if (async.hasValue) {
      final items = async.requireValue.items;
      body = items.isEmpty
          ? _Message(l.calendarRemindersEmpty)
          : _list(items, l);
    } else {
      body = const Center(child: CircularProgressIndicator.adaptive());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.calendarRemindersTitle),
        actions: const [HelpButton(helpId: HelpId.calendarReminders)],
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _list(List<FiredReminder> items, AppLocalizations l) {
    // Same clock style as the row titles (the notification titles).
    final formatTime = shortTimeFormatter(l.localeName);
    final today = deviceLocalTimeOf(ref.read(remindersInboxClockProvider)());
    String firedAt(DateTime utc) {
      final wall = deviceLocalTimeOf(utc);
      final time = formatTime(wall);
      if (wall.year == today.year &&
          wall.month == today.month &&
          wall.day == today.day) {
        return time;
      }
      String date;
      try {
        date = DateFormat.MMMd(l.localeName).format(wall);
      } catch (_) {
        date = '${wall.month}/${wall.day}';
      }
      return '$date $time';
    }

    return ListView.separated(
      key: const Key('reminders-inbox-list'),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = items[i];
        return ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(r.title),
          subtitle: Text(l.calendarRemindersFiredAt(firedAt(r.fireAtUtc))),
          onTap: () => _open(r),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
