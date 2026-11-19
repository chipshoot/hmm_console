import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/data_mode.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../calendar/notifications/local_reminder_scheduler.dart';
import '../../../calendar/notifications/notification_gateway.dart';
import '../../../calendar/notifications/reminder_sync.dart';
import '../../../calendar/states/open_system_settings.dart';
import '../../../calendar/states/remind_on_device_provider.dart';
import '../../../calendar/states/show_lunar_provider.dart';

/// Calendar settings: the synced "Show lunar calendar" switch, and, where
/// reminders are supported, the per-device "Remind on this device" switch
/// and, when permission was declined, an "Open Settings" row.
///
/// Hidden in Cloud API mode (the calendar is unavailable there). The lunar
/// row shows on every platform; only the reminder rows need
/// [calendarRemindersSupported].
class CalendarSettingsSection extends ConsumerWidget {
  const CalendarSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dataModeProvider) == DataMode.cloudApi) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showLunar = ref.watch(showLunarProvider);
    final reminders = calendarRemindersSupported;
    final remind = reminders ? ref.watch(remindOnDeviceProvider) : false;
    final denied = reminders && ref.watch(calendarPermissionDeniedProvider);
    final open = reminders ? ref.watch(openSystemSettingsProvider) : null;
    final isApple =
        theme.platform == TargetPlatform.iOS ||
        theme.platform == TargetPlatform.macOS;
    void onLunarChanged(bool v) {
      unawaited(ref.read(showLunarProvider.notifier).set(v));
    }

    void onChanged(bool v) {
      // Everything used after an await is read now.
      final remindNotifier = ref.read(remindOnDeviceProvider.notifier);
      final scheduler = ref.read(reminderSchedulerProvider);
      final denied = ref.read(calendarPermissionDeniedProvider.notifier);
      final sync = ref.read(reminderSyncProvider);
      unawaited(() async {
        await remindNotifier.set(v);
        if (!v) return;
        // R-18: turning reminders on asks once if this device never was.
        try {
          final answer = await askPermissionOnceIfNeverAsked(
            request: scheduler.requestPermission,
            markAsked: (granted) =>
                denied.markPermissionAsked(granted: granted),
          );
          if (answer != null) sync.trigger();
        } catch (e) {
          debugPrint(
            'Notification permission request failed (${e.runtimeType})',
          );
        }
      }());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.settingsCalendarTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.settingsCalendarShowLunar),
          subtitle: Text(l.settingsCalendarShowLunarSubtitle),
          trailing: isApple
              ? CupertinoSwitch(value: showLunar, onChanged: onLunarChanged)
              : Switch(value: showLunar, onChanged: onLunarChanged),
          onTap: () => onLunarChanged(!showLunar),
        ),
        if (reminders)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.settingsCalendarRemindOnDevice),
            subtitle: Text(l.settingsCalendarRemindOnDeviceSubtitle),
            trailing: isApple
                ? CupertinoSwitch(value: remind, onChanged: onChanged)
                : Switch(value: remind, onChanged: onChanged),
            onTap: () => onChanged(!remind),
          ),
        if (reminders && denied && open != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(l.calendarOpenSettings),
            subtitle: Text(l.calendarPermissionBanner),
            onTap: () => open(),
          ),
      ],
    );
  }
}
