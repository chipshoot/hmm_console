import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/calendar/contract/calendar_errors.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/notifications/notification_gateway.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:hmm_console/features/calendar/states/reminders_inbox_state.dart';
import 'package:hmm_console/features/calendar/states/reminders_seen_provider.dart';
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

/// A timed event at [start] (UTC) with one reminder at its start.
CalendarEvent _ev(String id, DateTime start) => CalendarEvent(
  id: id,
  title: 'Title $id',
  start: FixedTime(start, Duration.zero),
  reminders: const [Reminder(minutesBefore: 0)],
  updatedAt: DateTime.utc(2026),
);

FakeCalendarRepository _seeded() => FakeCalendarRepository()
  ..seed(_ev('a', DateTime.utc(2026, 11, 18, 11, 0))) // after seenAt
  ..seed(_ev('b', DateTime.utc(2026, 11, 18, 11, 30))) // after seenAt
  ..seed(_ev('c', DateTime.utc(2026, 11, 18, 9, 0))) // before seenAt
  ..seed(_ev('old', DateTime.utc(2026, 11, 10, 9, 0))) // outside 7 days
  ..seed(_ev('future', DateTime.utc(2026, 11, 18, 13, 0))); // not fired

({ProviderContainer c, FakeNotificationGateway gateway, SpyReminderSync sync})
_container(
  FakeCalendarRepository repo, {
  bool remind = true,
  DataMode mode = DataMode.local,
}) {
  final gateway = FakeNotificationGateway();
  final sync = SpyReminderSync();
  final c = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _Mode(mode)),
      localCalendarRepositoryProvider.overrideWithValue(repo),
      remindOnDeviceProvider.overrideWith(() => _Remind(remind)),
      remindersInboxClockProvider.overrideWithValue(() => _now),
      notificationGatewayProvider.overrideWithValue(gateway),
      reminderSyncProvider.overrideWithValue(sync),
      reminderTitleFormatProvider.overrideWithValue((e, o) => e.title),
    ],
  );
  addTearDown(c.dispose);
  // autoDispose: keep it alive for the test.
  c.listen(remindersInboxProvider, (_, _) {});
  return (c: c, gateway: gateway, sync: sync);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      kRemindersSeenAtKey: _seenAt.toIso8601String(),
    });
  });

  test(
    'lists the last 7 days newest first; counts those after seenAt',
    () async {
      final (:c, gateway: _, sync: _) = _container(_seeded());
      final inbox = await c.read(remindersInboxProvider.future);
      expect(inbox.items.map((r) => r.eventId), ['b', 'a', 'c']);
      expect(inbox.items.first.title, 'Title b');
      expect(inbox.unseen, 2);
    },
  );

  test('remind on this device off: nothing counts as unseen', () async {
    final (:c, gateway: _, sync: _) = _container(_seeded(), remind: false);
    final inbox = await c.read(remindersInboxProvider.future);
    expect(inbox.unseen, 0);
  });

  test('a seenAt stored by ReminderSync rebuilds the count', () async {
    final (:c, gateway: _, sync: _) = _container(_seeded());
    expect((await c.read(remindersInboxProvider.future)).unseen, 2);
    // What reminderSyncProvider's writeSeenAt does (e.g. first run back on).
    await c.read(remindersSeenAtProvider.notifier).write(_now);
    expect((await c.read(remindersInboxProvider.future)).unseen, 0);
  });

  test('seenAt unset: unseen 0 and nothing is written (R-1)', () async {
    SharedPreferences.setMockInitialValues({});
    final (:c, gateway: _, sync: _) = _container(_seeded());
    final inbox = await c.read(remindersInboxProvider.future);
    expect(inbox.items, hasLength(3));
    expect(inbox.unseen, 0);
    expect(await readRemindersSeenAt(), isNull);
  });

  test(
    'markSeen: unseen 0, seenAt written, badge cleared, sync triggered',
    () async {
      final (:c, :gateway, :sync) = _container(_seeded());
      await c.read(remindersInboxProvider.future);
      await c.read(remindersInboxProvider.notifier).markSeen();
      final inbox = await c.read(remindersInboxProvider.future);
      expect(inbox.unseen, 0);
      expect(inbox.items, hasLength(3));
      expect(await readRemindersSeenAt(), _now);
      expect(gateway.badgeClears, 1);
      expect(sync.triggers, 1);
    },
  );

  test(
    're-reads after a repository change (done occurrence drops out)',
    () async {
      final repo = _seeded();
      final (:c, gateway: _, sync: _) = _container(repo);
      final before = await c.read(remindersInboxProvider.future);
      final b = before.items.first;
      await repo.setOccurrence(
        'b',
        OccurrenceOverride(
          originalStart: b.originalStart,
          status: OccurrenceStatus.done,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final after = await c.read(remindersInboxProvider.future);
      expect(after.items.map((r) => r.eventId), ['a', 'c']);
      expect(after.unseen, 1);
    },
  );

  test('cloud API mode surfaces CalendarCloudApiUnavailable', () async {
    final (:c, gateway: _, sync: _) = _container(
      _seeded(),
      mode: DataMode.cloudApi,
    );
    Object? error;
    try {
      await c.read(remindersInboxProvider.future);
    } catch (e) {
      error = e;
    }
    expect(isCalendarCloudApiUnavailable(error!), isTrue);
  });
}
