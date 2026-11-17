import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:hmm_console/core/data/data_mode.dart';
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

class _Mode extends DataModeNotifier {
  _Mode(this._initial);
  final DataMode _initial;
  @override
  DataMode build() => _initial;
  void set(DataMode m) => state = m;
}

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
  _Harness({
    bool remind = true,
    bool granted = true,
    bool cloudApi = false,
    this.asked = true,
  }) : remindOnDevice = remind,
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
      permissionAsked: () async => asked,
      onPermissionChecked: (denied) => deniedReports.add(denied),
      resolve: _utc,
      clock: () => _now,
      observeLifecycle: false,
    );
  }

  final repo = _FakeRepo([_ev('a')]);
  final FakeNotificationGateway gateway;
  bool remindOnDevice;
  bool asked;
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
    SharedPreferences.setMockInitialValues({'calendar.permissionAsked': true});
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
        deviceShortestSideProvider.overrideWith(
          () => DeviceShortestSideNotifier(390),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(remindOnDeviceProvider.notifier).loaded;
    await c.read(reminderSyncProvider).runNow();
    expect(gw.scheduled, isEmpty);
    expect(c.read(calendarPermissionDeniedProvider), isTrue);
  });

  group('banner only after the owner was asked (R-11)', () {
    test('never asked + not granted → not denied', () {
      fakeAsync((fa) {
        final h = _Harness(granted: false, asked: false);
        h.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.gateway.scheduled, isEmpty);
        expect(h.deniedReports, [false]);
        h.sync.stop();
      });
    });

    test('asked + not granted → denied; then setting off → cleared', () {
      fakeAsync((fa) {
        final h = _Harness(granted: false);
        h.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.deniedReports.last, isTrue);
        h.remindOnDevice = false;
        h.sync.trigger();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.deniedReports.last, isFalse);
        h.sync.stop();
      });
    });

    test('empty plan and cloud API clear the flag', () {
      fakeAsync((fa) {
        final h = _Harness(granted: false)..repo.events = [];
        h.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.deniedReports, [false]);
        h.sync.stop();
        final k = _Harness(granted: false, cloudApi: true);
        k.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(k.deniedReports, [false]);
        k.sync.stop();
      });
    });

    test('markPermissionAsked stores the key and sets the banner', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await calendarPermissionAsked(), isFalse);
      await c
          .read(calendarPermissionDeniedProvider.notifier)
          .markPermissionAsked(granted: false);
      expect(await calendarPermissionAsked(), isTrue);
      expect(c.read(calendarPermissionDeniedProvider), isTrue);
    });
  });

  group('real calendarRepositoryProvider in cloud API mode', () {
    ProviderContainer container(_Mode mode, FakeNotificationGateway gw) {
      final c = ProviderContainer(
        overrides: [
          dataModeProvider.overrideWith(() => mode),
          localCalendarRepositoryProvider.overrideWithValue(_FakeRepo([])),
          notificationGatewayProvider.overrideWithValue(gw),
          deviceShortestSideProvider.overrideWith(
            () => DeviceShortestSideNotifier(390),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('start() does not throw and calendar reminders are cancelled', () {
      SharedPreferences.setMockInitialValues({});
      TestWidgetsFlutterBinding.ensureInitialized();
      fakeAsync((fa) {
        final gw = FakeNotificationGateway()
          ..addPending(1, 'other|x')
          ..addPending(2, 'calendar|a|x');
        final c = container(_Mode(DataMode.cloudApi), gw);
        final sync = c.read(reminderSyncProvider);
        expect(sync.start, returnsNormally);
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(gw.pendingById.keys, [1]);
        expect(gw.scheduled, isEmpty);
        sync.stop();
      });
    });

    test('switching to cloud API at runtime cancels calendar reminders', () {
      SharedPreferences.setMockInitialValues({});
      TestWidgetsFlutterBinding.ensureInitialized();
      fakeAsync((fa) {
        final gw = FakeNotificationGateway()..addPending(1, 'other|x');
        final mode = _Mode(DataMode.local);
        final c = container(mode, gw);
        final sync = c.read(reminderSyncProvider);
        sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        gw.addPending(2, 'calendar|a|x');
        mode.set(DataMode.cloudApi);
        fa.flushMicrotasks();
        expect(gw.pendingById.keys, unorderedEquals([1, 2]));
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(gw.pendingById.keys, [1]);
        sync.stop();
      });
    });
  });
}
