import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/core/navigation/calendar_routes.dart';
import 'package:hmm_console/features/calendar/data/local_calendar_repository.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/notifications/notification_gateway.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';
import 'package:hmm_console/features/calendar/presentation/screens/event_detail_screen.dart';
import 'package:hmm_console/features/calendar/presentation/screens/reminders_inbox_screen.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:hmm_console/features/calendar/states/reminders_inbox_state.dart';
import 'package:hmm_console/features/calendar/states/reminders_seen_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_calendar_repository.dart';
import '../support/fake_notification_gateway.dart';
import '../support/spy_reminder_sync.dart';

final _now = DateTime.utc(2026, 11, 18, 12, 0);
final _seenAt = DateTime.utc(2026, 11, 18, 10, 0);

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

class _Remind extends RemindOnDeviceNotifier {
  @override
  bool build() {
    loaded = Future.value();
    return true;
  }
}

/// readAll waits for [gate] (loading state) or throws (error state).
class _SlowRepo extends FakeCalendarRepository {
  _SlowRepo({this.fail = false});
  final bool fail;
  final gate = Completer<void>();
  @override
  Future<List<CalendarEventReadResult>> readAll() async {
    if (fail) throw StateError('db broken');
    await gate.future;
    return super.readAll();
  }
}

/// Short time of [utc] on this host, as the screen and the notification
/// titles format it (the device zone is unknown in tests, so the platform
/// zone applies; the clock style is the host's).
String _hm(DateTime utc) => shortTimeFormatter('en')(utc.toLocal());

/// A timed event at [start] (UTC) with one reminder 5 minutes before.
CalendarEvent _ev(String id, DateTime start) => CalendarEvent(
  id: id,
  title: 'Title $id',
  start: FixedTime(start, Duration.zero),
  reminders: const [Reminder(minutesBefore: 5)],
  updatedAt: DateTime.utc(2026),
);

final _aStart = DateTime.utc(2026, 11, 18, 11, 0);
final _bStart = DateTime.utc(2026, 11, 18, 11, 30);

FakeCalendarRepository _seeded() => FakeCalendarRepository()
  ..seed(_ev('a', _aStart))
  ..seed(_ev('b', _bStart));

Future<({GoRouter router, FakeNotificationGateway gateway})> _mount(
  WidgetTester tester,
  FakeCalendarRepository repo, {
  DataMode mode = DataMode.local,
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final gateway = FakeNotificationGateway();
  final router = GoRouter(
    initialLocation: '/calendar/reminders',
    routes: calendarRoutes,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(() => _Mode(mode)),
        localCalendarRepositoryProvider.overrideWithValue(repo),
        remindOnDeviceProvider.overrideWith(_Remind.new),
        remindersInboxClockProvider.overrideWithValue(() => _now),
        notificationGatewayProvider.overrideWithValue(gateway),
        reminderSyncProvider.overrideWithValue(SpyReminderSync()),
        reminderTitleFormatProvider.overrideWithValue(
          (e, o) => reminderTitle(
            e,
            o,
            allDayLabel: 'All day',
            formatTime: shortTimeFormatter('en'),
          ),
        ),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (router: router, gateway: gateway);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      kRemindersSeenAtKey: _seenAt.toIso8601String(),
    });
  });

  testWidgets('rows newest first: "<time> · Title" and the fired time', (
    tester,
  ) async {
    await _mount(tester, _seeded());
    expect(find.byType(RemindersInboxScreen), findsOneWidget);
    final b = find.text('${_hm(_bStart)} · Title b');
    final a = find.text('${_hm(_aStart)} · Title a');
    expect(b, findsOneWidget);
    expect(a, findsOneWidget);
    expect(tester.getTopLeft(b).dy, lessThan(tester.getTopLeft(a).dy));
    final bFired = _bStart.subtract(const Duration(minutes: 5));
    expect(find.text('Fired ${_hm(bFired)}'), findsOneWidget);
  });

  testWidgets('tapping a row opens the occurrence', (tester) async {
    await _mount(tester, _seeded());
    await tester.tap(find.text('${_hm(_bStart)} · Title b'));
    await tester.pumpAndSettle();
    // Pushed via /calendar/event/b?at=<wireKey>.
    final detail = tester.widget<EventDetailScreen>(
      find.byType(EventDetailScreen),
    );
    expect(detail.eventId, 'b');
    expect(detail.at, FixedTime(_bStart, Duration.zero).wireKey);
  });

  testWidgets('opening marks seen once, even after a reload', (tester) async {
    final repo = _seeded();
    final (router: _, :gateway) = await _mount(tester, repo);
    expect(gateway.badgeClears, 1);
    expect(await readRemindersSeenAt(), _now);
    await repo.saveEvent(_ev('c', DateTime.utc(2026, 11, 18, 11, 45)));
    await tester.pumpAndSettle();
    expect(
      find.text('${_hm(DateTime.utc(2026, 11, 18, 11, 45))} · Title c'),
      findsOneWidget,
    );
    expect(gateway.badgeClears, 1);
  });

  testWidgets('an occurrence marked done disappears after the change', (
    tester,
  ) async {
    final repo = _seeded();
    await _mount(tester, repo);
    await repo.setOccurrence(
      'b',
      OccurrenceOverride(
        originalStart: FixedTime(_bStart, Duration.zero),
        status: OccurrenceStatus.done,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('${_hm(_bStart)} · Title b'), findsNothing);
    expect(find.text('${_hm(_aStart)} · Title a'), findsOneWidget);
  });

  testWidgets('a deleted event disappears after the change', (tester) async {
    final repo = _seeded();
    await _mount(tester, repo);
    await repo.deleteEvent('b');
    await tester.pumpAndSettle();
    expect(find.text('${_hm(_bStart)} · Title b'), findsNothing);
    expect(find.text('${_hm(_aStart)} · Title a'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _mount(tester, FakeCalendarRepository());
    expect(find.text('No reminders in the last 7 days'), findsOneWidget);
  });

  testWidgets('loading, then content', (tester) async {
    final repo = _SlowRepo()..seed(_ev('a', _aStart));
    await _mount(tester, repo, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No reminders in the last 7 days'), findsNothing);
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('${_hm(_aStart)} · Title a'), findsOneWidget);
  });

  testWidgets('error state is distinct from empty', (tester) async {
    await _mount(tester, _SlowRepo(fail: true));
    expect(find.text("Could not load reminders."), findsOneWidget);
    expect(find.text('No reminders in the last 7 days'), findsNothing);
  });

  testWidgets('cloud API mode shows the calendar unavailable message', (
    tester,
  ) async {
    await _mount(tester, _seeded(), mode: DataMode.cloudApi);
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.calendarCloudApiUnavailable), findsOneWidget);
    expect(find.text("Could not load reminders."), findsNothing);
  });

  testWidgets('help button present; zh title', (tester) async {
    await _mount(tester, FakeCalendarRepository(), locale: const Locale('zh'));
    final help = tester.widget<HelpButton>(find.byType(HelpButton));
    expect(help.helpId, HelpId.calendarReminders);
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(find.text(zh.calendarRemindersTitle), findsWidgets);
  });

  test('HelpId.calendarReminders resolves in en and zh', () {
    for (final code in ['en', 'zh']) {
      final h = helpFor(
        HelpId.calendarReminders,
        lookupAppLocalizations(Locale(code)),
      );
      expect(h.title, isNotEmpty);
      expect(h.entries, isNotEmpty);
    }
  });
}
