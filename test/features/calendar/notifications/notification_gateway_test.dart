import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/notifications/notification_gateway.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_plan.dart';

PlannedReminder _r({bool timeSensitive = false, int? badge}) => PlannedReminder(
  id: 1,
  fireAtUtc: DateTime.utc(2026, 11, 18, 10),
  title: 'T',
  payload: 'calendar|a|x',
  timeSensitive: timeSensitive,
  badgeNumber: badge,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reminderNotificationDetails', () {
    test('a Time Sensitive reminder uses the timeSensitive level', () {
      final d = reminderNotificationDetails(_r(timeSensitive: true, badge: 3));
      expect(d.iOS!.interruptionLevel, InterruptionLevel.timeSensitive);
      expect(d.iOS!.badgeNumber, 3);
    });

    test('an ordinary reminder uses the active level', () {
      final d = reminderNotificationDetails(_r(badge: 1));
      expect(d.iOS!.interruptionLevel, InterruptionLevel.active);
      expect(d.iOS!.badgeNumber, 1);
    });

    test('Android keeps the calendar channel', () {
      final d = reminderNotificationDetails(_r());
      expect(d.android!.channelId, 'calendar_reminders');
    });
  });

  group('setBadge / clearBadge', () {
    const channel = MethodChannel('hmm/badge');
    late List<String> calls;
    late List<Object?> args;

    setUp(() {
      calls = [];
      args = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            args.add(call.arguments);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('on iOS setBadge calls hmm/badge set with the count', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await FlutterNotificationGateway().setBadge(2);
      expect(calls, ['set']);
      expect(args, [
        {'count': 2},
      ]);
    });

    test('on iOS clearBadge sets the badge to 0', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await FlutterNotificationGateway().clearBadge();
      expect(calls, ['set']);
      expect(args, [
        {'count': 0},
      ]);
    });

    test('elsewhere it does nothing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await FlutterNotificationGateway().setBadge(3);
      await FlutterNotificationGateway().clearBadge();
      expect(calls, isEmpty);
    });

    test('a channel error is swallowed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => throw PlatformException(code: 'x'),
          );
      await expectLater(FlutterNotificationGateway().setBadge(1), completes);
      await expectLater(FlutterNotificationGateway().clearBadge(), completes);
    });
  });
}
