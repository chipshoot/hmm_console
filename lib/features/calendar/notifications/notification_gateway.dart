import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// A notification already pending on the device.
class PendingReminder {
  const PendingReminder({required this.id, this.payload});

  final int id;
  final String? payload;
}

/// Thin wrapper over the platform notification plugin so the scheduler and
/// the sync can be tested with a fake.
abstract interface class NotificationGateway {
  /// [onTap] receives the payload of a tapped notification.
  Future<void> initialize(void Function(String payload) onTap);
  Future<List<PendingReminder>> pending();
  Future<void> cancel(int id);
  Future<void> schedule(PlannedReminder r);
  Future<bool> requestPermission();
  Future<bool> permissionGranted();
}

/// Device reminders are delivered on iOS (primary) and Android only.
bool get calendarRemindersSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

const _androidChannelId = 'calendar_reminders';
// The Android system shows these in the app's notification settings. There
// is no BuildContext here, so they are not localized yet.
const _androidChannelName = 'Calendar reminders';
const _androidChannelDescription = 'Reminders for calendar events';

/// [NotificationGateway] over `flutter_local_notifications`.
///
/// Android uses [AndroidScheduleMode.inexactAllowWhileIdle]: it needs neither
/// `SCHEDULE_EXACT_ALARM` (user-granted since Android 14) nor
/// `USE_EXACT_ALARM` (store-audited), at the cost of the OS possibly
/// delivering a reminder a few minutes late in Doze.
class FlutterNotificationGateway implements NotificationGateway {
  FlutterNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize(void Function(String payload) onTap) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked on the first save with a reminder, never here.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap(payload);
      },
    );
  }

  /// Payload of the notification that launched the app, if any. Routing it
  /// is the caller's job.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<List<PendingReminder>> pending() async => [
    for (final p in await _plugin.pendingNotificationRequests())
      PendingReminder(id: p.id, payload: p.payload),
  ];

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> schedule(PlannedReminder r) => _plugin.zonedSchedule(
    id: r.id,
    scheduledDate: tz.TZDateTime.from(r.fireAtUtc, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    title: r.title,
    body: r.body,
    payload: r.payload,
  );

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> permissionGranted() async {
    final ios = _ios;
    if (ios != null) {
      final o = await ios.checkPermissions();
      return o != null && (o.isEnabled || o.isProvisionalEnabled);
    }
    return await _android?.areNotificationsEnabled() ?? false;
  }
}

final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => FlutterNotificationGateway(),
);
