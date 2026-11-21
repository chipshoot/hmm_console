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
import 'package:hmm_console/features/calendar/states/reminders_seen_provider.dart';
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
  void Function()? onRead;

  void emit() => _changes.add(null);
  void emitError(Object e) => _changes.addError(e);

  @override
  Future<List<CalendarEvent>> eventsBetween(DateTime from, DateTime to) async {
    reads++;
    onRead?.call();
    return events;
  }

  @override
  Future<CalendarEvent?> getEventIncludingDeleted(String id) async => [
    for (final e in events)
      if (e.id == id) e,
  ].firstOrNull;

  @override
  Future<List<CalendarEvent>> eventsOwnedBySubsystems(
    Set<String> subsystems,
  ) async => [
    for (final e in events)
      if (subsystems.contains(e.owner?.subsystem)) e,
  ];

  @override
  Stream<void> changes() => _changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness({
    bool remind = true,
    bool granted = true,
    this.cloudApi = false,
    this.asked = true,
    Future<void> Function()? refreshZone,
    void Function()? onRead,
    this.seenAt,
    bool seenAtFails = false,
    this.badgeFails = false,
    DateTime Function()? clock,
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
      askPermissionOnce: () async {
        if (asked) return null;
        asks++;
        asked = true;
        gateway.granted = answer;
        return answer;
      },
      onPermissionChecked: (denied) => deniedReports.add(denied),
      resolve: _utc,
      clock: clock ?? () => _now,
      refreshZone: refreshZone,
      readSeenAt: () async {
        seenAtReads++;
        if (seenAtFails) throw StateError('prefs');
        return seenAt;
      },
      writeSeenAt: (utc) async {
        seenAtWrites.add(utc);
        seenAt = utc;
      },
      setBadge: (count) async {
        if (badgeFails) throw StateError('badge');
        badgeSets.add(count);
      },
      observeLifecycle: false,
    );
    repo.onRead = onRead;
  }

  final repo = _FakeRepo([_ev('a')]);
  final FakeNotificationGateway gateway;
  bool remindOnDevice;
  bool asked;

  /// What the owner answers when the sync asks.
  bool answer = true;
  int asks = 0;
  final deniedReports = <bool>[];
  late final ReminderSync sync;

  /// Fake `calendar.remindersSeenAt` store.
  DateTime? seenAt;
  int seenAtReads = 0;
  final seenAtWrites = <DateTime>[];

  /// Cloud API mode: the repository throws [CalendarCloudApiUnavailable].
  bool cloudApi;

  /// Every count the app icon badge was set to.
  final badgeSets = <int>[];
  bool badgeFails;
}

/// An event at [start] (resolved as UTC) with one reminder [before] minutes
/// earlier.
CalendarEvent _at(
  String id,
  FloatingTime start,
  int before, {
  bool timeSensitive = false,
}) => CalendarEvent(
  id: id,
  title: 'T $id',
  start: start,
  updatedAt: _now,
  timeSensitive: timeSensitive,
  reminders: [Reminder(minutesBefore: before)],
);

void _settle(FakeAsync fa) {
  fa.elapse(const Duration(seconds: 1));
  fa.flushMicrotasks();
}

void main() {
  group('badge numbers and seen state', () {
    test('first run with seenAt unset stores now and numbers from 1', () {
      fakeAsync((fa) {
        final h = _Harness();
        h.repo.events = [
          _ev('a'),
          _at('b', const FloatingTime(2026, 11, 18, 11, 0), 15),
        ];
        h.sync.start();
        _settle(fa);
        expect(h.seenAtWrites, [_now]);
        expect(h.gateway.scheduled.map((r) => r.badgeNumber), [1, 2]);
        h.sync.stop();
      });
    });

    test('seenAt 1 h ago with two fired since → numbers start at 3', () {
      fakeAsync((fa) {
        final h = _Harness(seenAt: _now.subtract(const Duration(hours: 1)));
        h.repo.events = [
          _ev('a'),
          // Fired 11:50 and 11:40, after seenAt (11:00).
          _at('f1', const FloatingTime(2026, 11, 17, 12, 5), 15),
          _at('f2', const FloatingTime(2026, 11, 17, 12, 10), 30),
          // Fired 10:00, before seenAt: already seen.
          _at('old', const FloatingTime(2026, 11, 17, 10, 15), 15),
        ];
        h.sync.start();
        _settle(fa);
        expect(h.seenAtWrites, isEmpty);
        expect(h.gateway.scheduled.map((r) => r.payload), [
          startsWith('calendar|a|'),
        ]);
        expect(h.gateway.scheduled.single.badgeNumber, 3);
        h.sync.stop();
      });
    });

    test('unseen counts at most the last 7 days', () {
      fakeAsync((fa) {
        final h = _Harness(seenAt: _now.subtract(const Duration(days: 30)));
        h.repo.events = [
          _ev('a'),
          // Fired 2 days ago: counts.
          _at('in', const FloatingTime(2026, 11, 15, 12, 0), 0),
          // Fired 8 days ago: outside the window.
          _at('out', const FloatingTime(2026, 11, 9, 12, 0), 0),
        ];
        h.sync.start();
        _settle(fa);
        expect(h.gateway.scheduled.single.badgeNumber, 2);
        h.sync.stop();
      });
    });

    test('remind on device off: seen set to now, no unseen read, nothing '
        'scheduled', () {
      fakeAsync((fa) {
        final h = _Harness(remind: false);
        h.sync.start();
        _settle(fa);
        expect(h.seenAtReads, 0);
        expect(h.seenAtWrites, [_now]);
        expect(h.gateway.scheduled, isEmpty);
        expect(h.gateway.pendingById.keys, [1]);
        h.sync.stop();
      });
    });

    test('reminders that fired while off never count once back on', () {
      fakeAsync((fa) {
        var now = _now.subtract(const Duration(hours: 1));
        final h = _Harness(
          remind: false,
          seenAt: _now.subtract(const Duration(days: 2)),
          clock: () => now,
        );
        h.repo.events = [
          _ev('a'),
          // Fires 11:50, while reminders are off on this device.
          _at('f', const FloatingTime(2026, 11, 17, 12, 5), 15),
        ];
        h.sync.start();
        _settle(fa);
        expect(h.gateway.scheduled, isEmpty);
        now = _now;
        h.remindOnDevice = true;
        h.sync.trigger();
        _settle(fa);
        expect(h.gateway.scheduled.map((r) => r.badgeNumber), [1]);
        expect(h.seenAtWrites, [now.subtract(const Duration(hours: 1)), now]);
        h.sync.stop();
      });
    });

    test('off run sets the icon badge to 0', () {
      fakeAsync((fa) {
        final h = _Harness(remind: false);
        h.sync.start();
        _settle(fa);
        expect(h.badgeSets, [0]);
        h.sync.stop();
      });
    });

    test('a run with one unseen reminder sets the icon badge to 1', () {
      fakeAsync((fa) {
        final h = _Harness(seenAt: _now.subtract(const Duration(hours: 1)));
        h.repo.events = [
          _ev('a'),
          // Fired 11:50, after seenAt (11:00).
          _at('f1', const FloatingTime(2026, 11, 17, 12, 5), 15),
        ];
        h.sync.start();
        _settle(fa);
        expect(h.badgeSets, [1]);
        expect(h.gateway.scheduled.single.badgeNumber, 2);
        h.sync.stop();
      });
    });

    test('a run with nothing unseen sets the icon badge to 0, even with no '
        'plan', () {
      fakeAsync((fa) {
        final h = _Harness(seenAt: _now);
        h.repo.events = [];
        h.sync.start();
        _settle(fa);
        expect(h.badgeSets, [0]);
        h.sync.stop();
      });
    });

    test('a failing badge set is logged; reminders are still scheduled', () {
      fakeAsync((fa) {
        final h = _Harness(seenAt: _now, badgeFails: true);
        h.sync.start();
        _settle(fa);
        expect(h.gateway.scheduled, hasLength(1));
        h.sync.stop();
      });
    });

    test('cloud API run marks seen and sets the icon badge to 0', () {
      fakeAsync((fa) {
        final h = _Harness(
          cloudApi: true,
          seenAt: _now.subtract(const Duration(days: 2)),
        );
        h.sync.start();
        _settle(fa);
        expect(h.seenAtWrites, [_now]);
        expect(h.badgeSets, [0]);
        expect(h.seenAtReads, 0);
        h.sync.stop();
      });
    });

    test(
      'reminders that fired during Cloud API mode never count once back',
      () {
        fakeAsync((fa) {
          var now = _now.subtract(const Duration(hours: 1));
          final h = _Harness(
            cloudApi: true,
            seenAt: _now.subtract(const Duration(days: 2)),
            clock: () => now,
          );
          h.repo.events = [
            _ev('a'),
            // Fires 11:50, while in Cloud API mode.
            _at('f', const FloatingTime(2026, 11, 17, 12, 5), 15),
          ];
          h.sync.start();
          _settle(fa);
          now = _now;
          h.cloudApi = false;
          h.sync.trigger();
          _settle(fa);
          expect(h.gateway.scheduled.map((r) => r.badgeNumber), [1]);
          expect(h.seenAtWrites, [now.subtract(const Duration(hours: 1)), now]);
          expect(h.badgeSets, [0, 0]);
          h.sync.stop();
        });
      },
    );

    test('back on after off: seen is stored before the events load, so a '
        'failing load leaves no stale count', () {
      fakeAsync((fa) {
        var now = _now.subtract(const Duration(hours: 1));
        var failLoad = false;
        final h = _Harness(
          remind: false,
          seenAt: _now.subtract(const Duration(days: 2)),
          clock: () => now,
          onRead: () {
            if (failLoad) throw StateError('db');
          },
        );
        h.sync.start();
        _settle(fa);
        now = _now;
        h.remindOnDevice = true;
        failLoad = true;
        h.sync.trigger();
        _settle(fa);
        expect(h.seenAtWrites, [now.subtract(const Duration(hours: 1)), now]);
        expect(h.gateway.scheduled, isEmpty);
        // The next run that reaches planning still starts from 0.
        now = _now.add(const Duration(minutes: 10));
        failLoad = false;
        h.repo.events = [
          _ev('a'),
          // Fired 12:05, after the failed run's seen write (12:00).
          _at('f', const FloatingTime(2026, 11, 17, 12, 5), 0),
        ];
        h.sync.trigger();
        _settle(fa);
        expect(h.gateway.scheduled.map((r) => r.badgeNumber), [1]);
        h.sync.stop();
      });
    });

    test('a failing seenAt read still schedules, numbered from 1', () {
      fakeAsync((fa) {
        final h = _Harness(seenAtFails: true);
        h.sync.start();
        _settle(fa);
        expect(h.gateway.scheduled.single.badgeNumber, 1);
        h.sync.stop();
      });
    });

    test('the gateway receives timeSensitive per reminder', () {
      fakeAsync((fa) {
        final h = _Harness(seenAt: _now);
        h.repo.events = [
          _at(
            'ts',
            const FloatingTime(2026, 11, 18, 10, 0),
            15,
            timeSensitive: true,
          ),
          _at('plain', const FloatingTime(2026, 11, 18, 11, 0), 15),
        ];
        h.sync.start();
        _settle(fa);
        expect(
          {
            for (final r in h.gateway.scheduled)
              r.payload.split('|')[1]: r.timeSensitive,
          },
          {'ts': true, 'plain': false},
        );
        h.sync.stop();
      });
    });
  });

  test('reminders seenAt round-trips through prefs as ISO UTC', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await readRemindersSeenAt(), isNull);
    await writeRemindersSeenAt(DateTime.utc(2026, 11, 18, 9, 30));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kRemindersSeenAtKey), '2026-11-18T09:30:00.000Z');
    expect(await readRemindersSeenAt(), DateTime.utc(2026, 11, 18, 9, 30));
    await prefs.setString(kRemindersSeenAtKey, 'garbage');
    expect(await readRemindersSeenAt(), isNull);
  });

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
      expect(h.gateway.scheduled.single.title, endsWith(' · T a'));
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

  test('a changes() error is logged, not thrown; later changes still run', () {
    fakeAsync((fa) {
      final h = _Harness();
      h.sync.start();
      fa.elapse(const Duration(seconds: 2));
      h.repo.emitError(StateError('catalog'));
      fa.flushMicrotasks();
      h.repo.emit();
      fa.elapse(const Duration(seconds: 1));
      fa.flushMicrotasks();
      expect(h.repo.reads, 2);
      h.sync.stop();
    });
  });

  test('resume re-reads the zone before the run (R-19)', () {
    fakeAsync((fa) {
      final order = <String>[];
      final h = _Harness(
        refreshZone: () async => order.add('zone'),
        onRead: () => order.add('run'),
      );
      h.sync.start();
      fa.elapse(const Duration(seconds: 2));
      order.clear();
      h.sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      fa.elapse(const Duration(seconds: 1));
      fa.flushMicrotasks();
      expect(order, ['zone', 'run']);
      h.sync.stop();
    });
  });

  test('a failing zone refresh still runs', () {
    fakeAsync((fa) {
      final h = _Harness(refreshZone: () async => throw StateError('tz'));
      h.sync.start();
      fa.elapse(const Duration(seconds: 2));
      h.sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      fa.elapse(const Duration(seconds: 1));
      fa.flushMicrotasks();
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

  test(
    'reminderSyncProvider stores seenAt through remindersSeenAtProvider',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gw = FakeNotificationGateway();
      final c = ProviderContainer(
        overrides: [
          notificationGatewayProvider.overrideWithValue(gw),
          calendarRepositoryProvider.overrideWithValue(_FakeRepo([])),
          // A tablet: remind on this device is off by default.
          deviceShortestSideProvider.overrideWith(
            () => DeviceShortestSideNotifier(800),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(remindOnDeviceProvider.notifier).loaded;
      expect(await c.read(remindersSeenAtProvider.future), isNull);
      final before = DateTime.now().toUtc();
      // An off run marks everything seen; the app state must see it.
      await c.read(reminderSyncProvider).runNow();
      final seen = c.read(remindersSeenAtProvider).value;
      expect(seen, isNotNull);
      expect(seen!.isBefore(before), isFalse);
      expect(await readRemindersSeenAt(), seen);
    },
  );

  group('the sync asks for permission once itself (R-18)', () {
    test('never asked + a plan → asks once and schedules on a grant', () {
      fakeAsync((fa) {
        final h = _Harness(granted: false, asked: false);
        h.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.asks, 1);
        expect(h.gateway.scheduled, hasLength(1));
        expect(h.deniedReports, [false]);
        // A second run does not ask again.
        h.repo.emit();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.asks, 1);
        h.sync.stop();
      });
    });

    test('never asked + declined → asks once, nothing scheduled, banner', () {
      fakeAsync((fa) {
        final h = _Harness(granted: false, asked: false)..answer = false;
        h.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.asks, 1);
        expect(h.gateway.scheduled, isEmpty);
        expect(h.deniedReports, [true]);
        h.repo.emit();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.asks, 1);
        h.sync.stop();
      });
    });

    test('an empty plan does not ask', () {
      fakeAsync((fa) {
        final h = _Harness(granted: false, asked: false)..repo.events = [];
        h.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.asks, 0);
        h.sync.stop();
      });
    });

    test('setting off does not ask', () {
      fakeAsync((fa) {
        final h = _Harness(remind: false, granted: false, asked: false);
        h.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.asks, 0);
        h.sync.stop();
      });
    });

    test('already granted does not ask', () {
      fakeAsync((fa) {
        final h = _Harness(asked: false);
        h.sync.start();
        fa.elapse(const Duration(seconds: 1));
        fa.flushMicrotasks();
        expect(h.asks, 0);
        expect(h.gateway.scheduled, hasLength(1));
        h.sync.stop();
      });
    });
  });

  test('askPermissionOnceIfNeverAsked: one prompt for concurrent callers, '
      'none once asked', () async {
    SharedPreferences.setMockInitialValues({});
    var prompts = 0;
    final marks = <bool>[];
    final gate = Completer<bool>();
    Future<bool> request() {
      prompts++;
      return gate.future;
    }

    Future<void> mark(bool g) async {
      marks.add(g);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kCalendarPermissionAskedKey, true);
    }

    final a = askPermissionOnceIfNeverAsked(request: request, markAsked: mark);
    final b = askPermissionOnceIfNeverAsked(request: request, markAsked: mark);
    await pumpEventQueue();
    gate.complete(true);
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(prompts, 1);
    expect(marks, [true]);
    expect(
      await askPermissionOnceIfNeverAsked(request: request, markAsked: mark),
      isNull,
    );
    expect(prompts, 1);
  });

  group('banner only after the owner was asked (R-11)', () {
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
