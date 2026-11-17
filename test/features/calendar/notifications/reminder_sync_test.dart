import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/contract/calendar_errors.dart';
import 'package:hmm_console/features/calendar/contract/i_calendar_repository.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/notifications/local_reminder_scheduler.dart';
import 'package:hmm_console/features/calendar/notifications/notification_gateway.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_notification_gateway.dart';

final _now = DateTime.utc(2026, 11, 17, 12, 0);

DateTime _utc(int y, int m, int d, int hh, int mm) =>
    DateTime.utc(y, m, d, hh, mm);

CalendarEvent _ev(String id) => CalendarEvent(
  id: id,
  title: 'T $id',
  start: const FloatingTime(2026, 11, 18, 10, 0),
  updatedAt: _now,
  reminders: const [Reminder(minutesBefore: 15)],
);

class _FakeRepo implements ICalendarRepository {
  _FakeRepo(this.events);
  List<CalendarEvent> events;
  final _changes = StreamController<void>.broadcast();
  int reads = 0;

  void emit() => _changes.add(null);

  @override
  Future<List<CalendarEvent>> eventsBetween(DateTime from, DateTime to) async {
    reads++;
    return events;
  }

  @override
  Stream<void> changes() => _changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness({bool remind = true, bool granted = true, bool cloudApi = false})
    : remindOnDevice = remind,
      gateway = FakeNotificationGateway(granted: granted) {
    gateway.addPending(1, 'other|x');
    gateway.addPending(2, 'calendar|old|2026-11-18T09:00');
    sync = ReminderSync(
      repository: () {
        if (cloudApi) throw CalendarCloudApiUnavailable();
        return repo;
      },
      scheduler: LocalReminderScheduler(gateway),
      permissionGranted: gateway.permissionGranted,
      remindOnDevice: () => remindOnDevice,
      onPermissionChecked: (denied) => deniedReports.add(denied),
      resolve: _utc,
      clock: () => _now,
      observeLifecycle: false,
    );
  }

  final repo = _FakeRepo([_ev('a')]);
  final FakeNotificationGateway gateway;
  bool remindOnDevice;
  final deniedReports = <bool>[];
  late final ReminderSync sync;
}

void main() {
  test('setting off cancels calendar reminders and schedules none', () {
    fakeAsync((fa) {
      final h = _Harness(remind: false);
      h.sync.start();
      fa.elapse(const Duration(seconds: 1));
      fa.flushMicrotasks();
      expect(h.gateway.scheduled, isEmpty);
      expect(h.gateway.pendingById.keys, [1]);
      h.sync.stop();
    });
  });

  test('start schedules the plan after the debounce', () {
    fakeAsync((fa) {
      final h = _Harness();
      h.sync.start();
      fa.elapse(const Duration(milliseconds: 999));
      expect(h.gateway.scheduled, isEmpty);
      fa.elapse(const Duration(milliseconds: 1));
      fa.flushMicrotasks();
      expect(h.gateway.scheduled, hasLength(1));
      expect(h.gateway.scheduled.single.title, 'T a');
      expect(
        h.gateway.scheduled.single.fireAtUtc,
        DateTime.utc(2026, 11, 18, 9, 45),
      );
      expect(
        h.gateway.pendingById.keys,
        unorderedEquals([1, h.gateway.scheduled.single.id]),
      );
      h.sync.stop();
    });
  });

  test('a changes() emission triggers exactly one reschedule after 1 s', () {
    fakeAsync((fa) {
      final h = _Harness();
      h.sync.start();
      fa.elapse(const Duration(seconds: 2));
      expect(h.repo.reads, 1);
      h.repo.emit();
      fa.elapse(const Duration(milliseconds: 999));
      expect(h.repo.reads, 1);
      fa.elapse(const Duration(milliseconds: 1));
      fa.flushMicrotasks();
      expect(h.repo.reads, 2);
      fa.elapse(const Duration(seconds: 5));
      expect(h.repo.reads, 2);
      h.sync.stop();
    });
  });

  test('two emissions within 1 s trigger one reschedule', () {
    fakeAsync((fa) {
      final h = _Harness();
      h.sync.start();
      fa.elapse(const Duration(seconds: 2));
      h.repo.emit();
      fa.elapse(const Duration(milliseconds: 500));
      h.repo.emit();
      fa.elapse(const Duration(milliseconds: 999));
      expect(h.repo.reads, 1);
      fa.elapse(const Duration(milliseconds: 1));
      fa.flushMicrotasks();
      expect(h.repo.reads, 2);
      fa.elapse(const Duration(seconds: 5));
      expect(h.repo.reads, 2);
      h.sync.stop();
    });
  });

  test('resume triggers a reschedule', () {
    fakeAsync((fa) {
      final h = _Harness();
      h.sync.start();
      fa.elapse(const Duration(seconds: 2));
      h.sync.didChangeAppLifecycleState(AppLifecycleState.paused);
      fa.elapse(const Duration(seconds: 2));
      expect(h.repo.reads, 1);
      h.sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      fa.elapse(const Duration(seconds: 1));
      fa.flushMicrotasks();
      expect(h.repo.reads, 2);
      h.sync.stop();
    });
  });

  test('permission not granted: nothing scheduled, denied reported', () {
    fakeAsync((fa) {
      final h = _Harness(granted: false);
      h.sync.start();
      fa.elapse(const Duration(seconds: 1));
      fa.flushMicrotasks();
      expect(h.gateway.scheduled, isEmpty);
      expect(h.deniedReports, [true]);
      h.gateway.granted = true;
      h.repo.emit();
      fa.elapse(const Duration(seconds: 1));
      fa.flushMicrotasks();
      expect(h.gateway.scheduled, hasLength(1));
      expect(h.deniedReports, [true, false]);
      h.sync.stop();
    });
  });

  test('cloud API mode cancels calendar reminders without throwing', () {
    fakeAsync((fa) {
      final h = _Harness(cloudApi: true);
      h.sync.start();
      fa.elapse(const Duration(seconds: 1));
      fa.flushMicrotasks();
      expect(h.gateway.scheduled, isEmpty);
      expect(h.gateway.pendingById.keys, [1]);
      h.sync.stop();
    });
  });

  test('calendarPermissionDeniedProvider defaults false and can be set', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(calendarPermissionDeniedProvider), isFalse);
    c.read(calendarPermissionDeniedProvider.notifier).set(true);
    expect(c.read(calendarPermissionDeniedProvider), isTrue);
  });

  test('provider wiring: denied permission sets the banner provider', () async {
    SharedPreferences.setMockInitialValues({});
    final soon = DateTime.now().toUtc().add(const Duration(days: 1));
    final repo = _FakeRepo([
      CalendarEvent(
        id: 'w',
        title: 'W',
        start: FixedTime(soon, Duration.zero),
        updatedAt: _now,
        reminders: const [Reminder(minutesBefore: 15)],
      ),
    ]);
    final gw = FakeNotificationGateway(granted: false);
    final c = ProviderContainer(
      overrides: [
        notificationGatewayProvider.overrideWithValue(gw),
        calendarRepositoryProvider.overrideWithValue(repo),
        deviceShortestSideProvider.overrideWithValue(390),
      ],
    );
    addTearDown(c.dispose);
    await c.read(remindOnDeviceProvider.notifier).loaded;
    await c.read(reminderSyncProvider).runNow();
    expect(gw.scheduled, isEmpty);
    expect(c.read(calendarPermissionDeniedProvider), isTrue);
  });
}
