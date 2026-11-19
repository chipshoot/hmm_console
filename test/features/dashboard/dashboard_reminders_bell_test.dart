import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/core/navigation/calendar_routes.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/notifications/notification_gateway.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';
import 'package:hmm_console/features/calendar/presentation/screens/reminders_inbox_screen.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/reminders_seen_provider.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:hmm_console/features/calendar/states/reminders_inbox_state.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calendar/support/fake_calendar_repository.dart';
import '../calendar/support/fake_notification_gateway.dart';

class _SignedIn extends CurrentUserNotifier {
  @override
  CurrentUserDataModel? build() => CurrentUserDataModel(
    uid: 'u1',
    email: 'tester@example.com',
    displayName: 'Tester',
    photoUrl: null,
  );
}

class _IntroSeen extends IntroCardSeenNotifier {
  @override
  bool build() => true;
}

class _IdleSync extends SyncController {
  _IdleSync() : super(syncAction: () async => throw UnimplementedError());
}

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

class _Remind extends RemindOnDeviceNotifier {
  _Remind(this._on);
  final bool _on;
  @override
  bool build() {
    loaded = Future.value();
    return _on;
  }

  @override
  Future<void> set(bool value) async => state = value;
}

class _Inbox extends RemindersInboxNotifier {
  _Inbox(this._unseen);
  final int _unseen;
  @override
  Future<RemindersInbox> build() async =>
      RemindersInbox(items: const [], unseen: _unseen);
  @override
  Future<void> markSeen() async {}
}

const _tooltip = 'Reminders';

Future<void> _mount(
  WidgetTester tester, {
  int unseen = 3,
  bool remind = true,
  DataMode mode = DataMode.local,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      ...calendarRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(_SignedIn.new),
        introCardSeenProvider.overrideWith(_IntroSeen.new),
        syncControllerProvider.overrideWithValue(_IdleSync()),
        dataModeProvider.overrideWith(() => _Mode(mode)),
        remindOnDeviceProvider.overrideWith(() => _Remind(remind)),
        if (mode != DataMode.cloudApi)
          remindersInboxProvider.overrideWith(() => _Inbox(unseen)),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the bell shows the unseen count', (tester) async {
    await _mount(tester, unseen: 3);
    expect(find.byTooltip(_tooltip), findsOneWidget);
    expect(find.widgetWithText(Badge, '3'), findsOneWidget);
  });

  testWidgets('more than 99 shows 99+', (tester) async {
    await _mount(tester, unseen: 120);
    expect(find.widgetWithText(Badge, '99+'), findsOneWidget);
  });

  testWidgets('no badge at 0', (tester) async {
    await _mount(tester, unseen: 0);
    expect(find.byTooltip(_tooltip), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('hidden when remind on this device is off', (tester) async {
    await _mount(tester, remind: false);
    expect(find.byTooltip(_tooltip), findsNothing);
  });

  testWidgets('hidden in cloud API mode', (tester) async {
    await _mount(tester, mode: DataMode.cloudApi);
    expect(find.byTooltip(_tooltip), findsNothing);
  });

  testWidgets('hidden where device reminders are unsupported (desktop)', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await _mount(tester);
      expect(find.byTooltip(_tooltip), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tapping the bell opens the reminders list', (tester) async {
    await _mount(tester);
    await tester.tap(find.byTooltip(_tooltip));
    await tester.pumpAndSettle();
    expect(find.byType(RemindersInboxScreen), findsOneWidget);
  });

  testWidgets(
    'switched back on: reminders that fired while off never show on the bell',
    (tester) async {
      final now = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        kCalendarPermissionAskedKey: true,
      });
      // Fired 30 minutes ago, while this device's reminders were off.
      final repo = FakeCalendarRepository()
        ..seed(
          CalendarEvent(
            id: 'walk',
            title: 'Walk',
            start: FixedTime(
              now.subtract(const Duration(minutes: 25)),
              Duration.zero,
            ),
            reminders: const [Reminder(minutesBefore: 5)],
            updatedAt: DateTime.utc(2026),
          ),
        );
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith(_SignedIn.new),
          introCardSeenProvider.overrideWith(_IntroSeen.new),
          syncControllerProvider.overrideWithValue(_IdleSync()),
          dataModeProvider.overrideWith(() => _Mode(DataMode.local)),
          remindOnDeviceProvider.overrideWith(() => _Remind(false)),
          localCalendarRepositoryProvider.overrideWithValue(repo),
          notificationGatewayProvider.overrideWithValue(
            FakeNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          ...calendarRoutes,
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip(_tooltip), findsNothing);

      // The app starts ReminderSync; its off run marks everything seen.
      container.read(reminderSyncProvider).start();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      // The reminder fired after that off run: seenAt is older than it.
      await container
          .read(remindersSeenAtProvider.notifier)
          .write(now.subtract(const Duration(hours: 2)));

      // Back on: the inbox is built afresh (it was disposed while hidden).
      await container.read(remindOnDeviceProvider.notifier).set(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byTooltip(_tooltip), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
    },
  );
}
