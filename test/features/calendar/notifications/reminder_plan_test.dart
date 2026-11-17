import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/occurrence.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_plan.dart';

DateTime _utc(int y, int m, int d, int hh, int mm) =>
    DateTime.utc(y, m, d, hh, mm);

String _title(CalendarEvent e, Occurrence o) => o.titleOverride ?? e.title;

final _now = DateTime.utc(2026, 11, 17, 12, 0);

CalendarEvent _ev(
  String id,
  EventTime start, {
  List<Reminder> reminders = const [Reminder(minutesBefore: 15)],
  String? rrule,
  bool draft = false,
  EventStatus status = EventStatus.active,
  List<OccurrenceOverride> occurrences = const [],
  Map<String, Object?> extra = const {},
}) => CalendarEvent(
  id: id,
  title: 'T $id',
  start: start,
  updatedAt: _now,
  reminders: reminders,
  rrule: rrule,
  draft: draft,
  status: status,
  occurrences: occurrences,
  extraFields: extra,
);

List<PlannedReminder> _plan(List<CalendarEvent> evs, {int cap = 60}) =>
    planReminders(
      events: evs,
      nowUtc: _now,
      resolve: _utc,
      formatTitle: _title,
      cap: cap,
    );

void main() {
  test('cap keeps the nearest of 100 candidates', () {
    final e = _ev(
      'd',
      const FloatingTime(2026, 11, 17, 18, 0),
      rrule: 'FREQ=DAILY;COUNT=100',
    );
    // window 14 days yields ~14; use a wide event list instead
    final many = [
      for (var i = 0; i < 100; i++)
        _ev('e$i', FloatingTime(2026, 11, 18, 10, i % 60)),
    ];
    final out = _plan([e, ...many]);
    expect(out, hasLength(60));
    final sorted = [...out]
      ..sort((a, b) {
        final c = a.fireAtUtc.compareTo(b.fireAtUtc);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    expect(out.map((r) => r.id), sorted.map((r) => r.id));
    expect(out.last.fireAtUtc.isBefore(DateTime.utc(2026, 11, 19)), isTrue);
  });

  test('window is on fire time: day 14 in, day 15 out', () {
    final inside = _ev(
      'in',
      const FloatingTime(2026, 12, 1, 12, 0),
      reminders: const [Reminder(minutesBefore: 0)],
    );
    final outside = _ev(
      'out',
      const FloatingTime(2026, 12, 1, 12, 1),
      reminders: const [Reminder(minutesBefore: 0)],
    );
    final out = _plan([inside, outside]);
    expect(out.map((r) => r.payload), [
      'calendar|in|floating:2026-12-01T12:00',
    ]);
  });

  test('a long lead pulls an event past the window in by fire time', () {
    final e = _ev(
      'long',
      const FloatingTime(2026, 12, 1, 18, 0),
      reminders: const [Reminder(minutesBefore: 24 * 60)],
    );
    expect(_plan([e]), hasLength(1));
  });

  test('draft, cancelled series, done/skipped/cancelled skipped', () {
    const st = FloatingTime(2026, 11, 18, 10, 0);
    OccurrenceOverride ov(OccurrenceStatus s) =>
        OccurrenceOverride(originalStart: st, status: s);
    final evs = [
      _ev('draft', st, draft: true),
      _ev('cx', st, status: EventStatus.cancelled),
      _ev('done', st, occurrences: [ov(OccurrenceStatus.done)]),
      _ev('skip', st, occurrences: [ov(OccurrenceStatus.skipped)]),
      _ev('occx', st, occurrences: [ov(OccurrenceStatus.cancelled)]),
    ];
    expect(_plan(evs), isEmpty);
  });

  test('email reminders are ignored', () {
    final e = _ev(
      'm',
      const FloatingTime(2026, 11, 18, 10, 0),
      reminders: const [
        Reminder(minutesBefore: 5, channel: ReminderChannel.email),
      ],
    );
    expect(_plan([e]), isEmpty);
  });

  test('moved occurrence is planned at its moved start', () {
    const orig = FloatingTime(2026, 11, 18, 10, 0);
    final e = _ev(
      'mv',
      orig,
      occurrences: const [
        OccurrenceOverride(
          originalStart: orig,
          status: OccurrenceStatus.moved,
          movedTo: FloatingTime(2026, 11, 19, 8, 0),
        ),
      ],
    );
    final out = _plan([e]);
    expect(out.single.fireAtUtc, DateTime.utc(2026, 11, 19, 7, 45));
    expect(out.single.payload, 'calendar|mv|floating:2026-11-18T10:00');
  });

  test('past fire time is not scheduled (Review Focus 4)', () {
    final start = FloatingTime(2026, 11, 17, 12, 10);
    expect(_plan([_ev('p', start)]), isEmpty);
    final five = _ev('p', start, reminders: const [Reminder(minutesBefore: 5)]);
    expect(_plan([five]).single.fireAtUtc, DateTime.utc(2026, 11, 17, 12, 5));
  });

  test('all-day fires at 09:00 local on the day', () {
    final e = _ev(
      'ad',
      const AllDay(2026, 11, 20),
      reminders: const [Reminder(minutesBefore: 0)],
    );
    expect(_plan([e]).single.fireAtUtc, DateTime.utc(2026, 11, 20, 9, 0));
  });

  test('all-day minutesBefore subtracts from 09:00', () {
    final e = _ev(
      'ad',
      const AllDay(2026, 11, 20),
      reminders: const [Reminder(minutesBefore: 60)],
    );
    expect(_plan([e]).single.fireAtUtc, DateTime.utc(2026, 11, 20, 8, 0));
  });

  test('moved all-day occurrence uses the moved date', () {
    const orig = AllDay(2026, 11, 20);
    final e = _ev(
      'adm',
      orig,
      reminders: const [Reminder(minutesBefore: 0)],
      occurrences: const [
        OccurrenceOverride(
          originalStart: orig,
          status: OccurrenceStatus.moved,
          movedTo: AllDay(2026, 11, 22),
        ),
      ],
    );
    expect(_plan([e]).single.fireAtUtc, DateTime.utc(2026, 11, 22, 9, 0));
  });

  test('ids are stable and differ across occurrences and offsets', () {
    const a = FloatingTime(2026, 11, 18, 10, 0);
    const b = FloatingTime(2026, 11, 19, 10, 0);
    expect(
      reminderNotificationId('x', a, 15),
      reminderNotificationId('x', a, 15),
    );
    expect(
      reminderNotificationId('x', a, 15) == reminderNotificationId('x', b, 15),
      isFalse,
    );
    expect(
      reminderNotificationId('x', a, 15) == reminderNotificationId('x', a, 5),
      isFalse,
    );
    expect(reminderNotificationId('x', a, 15), lessThanOrEqualTo(0x7fffffff));
  });

  test('id hash is pinned', () {
    final t = FixedTime(DateTime.utc(2026, 11, 20, 15), Duration.zero);
    expect(reminderNotificationId('ev1', t, 15), 1508812905);
  });

  test('payload format and body', () {
    final e = _ev(
      'pl',
      const FloatingTime(2026, 11, 18, 19, 0),
      extra: const {'reminderBody': 'Bring the form'},
    );
    final r = _plan([e]).single;
    expect(r.payload, 'calendar|pl|floating:2026-11-18T19:00');
    expect(r.body, 'Bring the form');
    expect(r.title, 'T pl');
    expect(r.id, reminderNotificationId('pl', e.start, 15));
    expect(
      _plan([_ev('nb', const FloatingTime(2026, 11, 18, 19, 0))]).single.body,
      isNull,
    );
  });
}
