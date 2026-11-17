import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/occurrence.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_expander.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

CalendarEvent ev(
  EventTime start, {
  EventTime? end,
  String? rrule,
  EventStatus status = EventStatus.active,
  List<OccurrenceOverride> overrides = const [],
}) => CalendarEvent(
  id: 'e1',
  title: 'T',
  start: start,
  end: end,
  rrule: rrule,
  status: status,
  occurrences: overrides,
  updatedAt: DateTime.utc(2026, 1, 1),
);

DateTime utc(int y, int m, int d, [int hh = 0, int mm = 0]) =>
    DateTime.utc(y, m, d, hh, mm);

// Identity resolver: wall-clock == UTC, so expectations are easy to read.
DateTime _id(int y, int m, int d, int hh, int mm) => utc(y, m, d, hh, mm);

List<DateTime> starts(List<Occurrence> o) => [for (final x in o) x.start];

List<Occurrence> run(
  CalendarEvent e,
  DateTime from,
  DateTime to, {
  LocalResolver resolve = _id,
}) => expandOccurrences(e, from, to, resolve: resolve);

LocalResolver torontoResolver() {
  tzdata.initializeTimeZones();
  final loc = tz.getLocation('America/Toronto');
  return (y, m, d, hh, mm) => DateTime.fromMicrosecondsSinceEpoch(
    tz.TZDateTime(loc, y, m, d, hh, mm).toUtc().microsecondsSinceEpoch,
    isUtc: true,
  );
}

void main() {
  const f = FloatingTime(2026, 1, 5, 9, 0); // a Monday

  group('basic rules', () {
    test('daily', () {
      final o = run(
        ev(f, rrule: 'FREQ=DAILY'),
        utc(2026, 1, 5),
        utc(2026, 1, 8),
      );
      expect(starts(o), [
        utc(2026, 1, 5, 9),
        utc(2026, 1, 6, 9),
        utc(2026, 1, 7, 9),
      ]);
    });

    test('weekly BYDAY=MO,WE,FR', () {
      final o = run(
        ev(f, rrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR'),
        utc(2026, 1, 5),
        utc(2026, 1, 13),
      );
      expect(starts(o), [
        utc(2026, 1, 5, 9),
        utc(2026, 1, 7, 9),
        utc(2026, 1, 9, 9),
        utc(2026, 1, 12, 9),
      ]);
    });

    test('weekly defaults to the start weekday and honours INTERVAL=2', () {
      final o = run(
        ev(f, rrule: 'FREQ=WEEKLY;INTERVAL=2'),
        utc(2026, 1, 1),
        utc(2026, 2, 10),
      );
      expect(starts(o), [
        utc(2026, 1, 5, 9),
        utc(2026, 1, 19, 9),
        utc(2026, 2, 2, 9),
      ]);
    });

    test('monthly BYMONTHDAY=31 skips short months', () {
      final e = ev(
        const FloatingTime(2026, 1, 31, 9, 0),
        rrule: 'FREQ=MONTHLY;BYMONTHDAY=31',
      );
      final o = run(e, utc(2026, 1, 1), utc(2026, 7, 1));
      expect(starts(o), [
        utc(2026, 1, 31, 9),
        utc(2026, 3, 31, 9),
        utc(2026, 5, 31, 9),
      ]);
    });

    test('yearly', () {
      final o = run(
        ev(f, rrule: 'FREQ=YEARLY'),
        utc(2026, 1, 1),
        utc(2029, 1, 1),
      );
      expect(starts(o), [
        utc(2026, 1, 5, 9),
        utc(2027, 1, 5, 9),
        utc(2028, 1, 5, 9),
      ]);
    });

    test('COUNT=3 gives exactly 3 and counts from the series start', () {
      final e = ev(f, rrule: 'FREQ=DAILY;COUNT=3');
      expect(run(e, utc(2026, 1, 1), utc(2027, 1, 1)).length, 3);
      expect(starts(run(e, utc(2026, 1, 6), utc(2027, 1, 1))), [
        utc(2026, 1, 6, 9),
        utc(2026, 1, 7, 9),
      ]);
    });

    test('UNTIL date is inclusive of its last day', () {
      final e = ev(f, rrule: 'FREQ=DAILY;UNTIL=20260107');
      expect(starts(run(e, utc(2026, 1, 1), utc(2026, 2, 1))), [
        utc(2026, 1, 5, 9),
        utc(2026, 1, 6, 9),
        utc(2026, 1, 7, 9),
      ]);
    });

    test('UNTIL with a UTC time compares instants', () {
      final e = ev(f, rrule: 'FREQ=DAILY;UNTIL=20260106T085959Z');
      expect(starts(run(e, utc(2026, 1, 1), utc(2026, 2, 1))), [
        utc(2026, 1, 5, 9),
      ]);
    });

    test('local-form UNTIL is wall-clock in the series zone', () {
      // Floating 09:00 series, device at UTC+8: UNTIL 09:00 local on the 6th
      // keeps the 6th; read as UTC it would wrongly keep the 7th too.
      DateTime plus8(int y, int m, int d, int hh, int mm) =>
          utc(y, m, d, hh, mm).subtract(const Duration(hours: 8));
      final e = ev(f, rrule: 'FREQ=DAILY;UNTIL=20260106T090000');
      expect(starts(run(e, utc(2026, 1, 1), utc(2026, 2, 1), resolve: plus8)), [
        utc(2026, 1, 5, 1),
        utc(2026, 1, 6, 1),
      ]);
      final before = ev(f, rrule: 'FREQ=DAILY;UNTIL=20260106T085959');
      expect(
        starts(run(before, utc(2026, 1, 1), utc(2026, 2, 1), resolve: plus8)),
        [utc(2026, 1, 5, 1)],
      );
    });

    test('local-form UNTIL on a fixed series uses the series offset', () {
      // 09:00 at -05:00 (14:00Z) daily; UNTIL 09:00 wall on the 6th.
      final fixed = FixedTime(utc(2026, 1, 5, 14), const Duration(hours: -5));
      final e = ev(fixed, rrule: 'FREQ=DAILY;UNTIL=20260106T090000');
      expect(starts(run(e, utc(2026, 1, 1), utc(2026, 2, 1))), [
        utc(2026, 1, 5, 14),
        utc(2026, 1, 6, 14),
      ]);
    });

    test('RSCALE=GREGORIAN expands as an ordinary daily rule', () {
      final e = ev(f, rrule: 'RSCALE=GREGORIAN;FREQ=DAILY');
      expect(run(e, utc(2026, 1, 5), utc(2026, 1, 8)).length, 3);
    });

    test('unsupported parts are ignored for expansion', () {
      final e = ev(f, rrule: 'FREQ=DAILY;BYSETPOS=-1');
      expect(run(e, utc(2026, 1, 5), utc(2026, 1, 8)).length, 3);
    });
  });

  group('lunar reserve', () {
    const lunar = 'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=15';

    test('yields only the first occurrence over three years', () {
      final e = ev(const FloatingTime(2026, 5, 20, 8, 0), rrule: lunar);
      final o = run(e, utc(2026, 1, 1), utc(2029, 1, 1));
      expect(starts(o), [utc(2026, 5, 20, 8)]);
    });

    test('overrides still apply to the first occurrence', () {
      final e = ev(
        const FloatingTime(2026, 5, 20, 8, 0),
        rrule: lunar,
        overrides: [
          const OccurrenceOverride(
            originalStart: FloatingTime(2026, 5, 20, 8, 0),
            status: OccurrenceStatus.done,
          ),
        ],
      );
      final o = run(e, utc(2026, 1, 1), utc(2029, 1, 1));
      expect(o.single.status, OccurrenceStatus.done);
    });
  });

  group('overrides', () {
    final base = ev(f, rrule: 'FREQ=DAILY');
    OccurrenceOverride ov(
      int d,
      OccurrenceStatus s, {
      EventTime? movedTo,
      Map<String, Object?> extra = const {},
    }) => OccurrenceOverride(
      originalStart: FloatingTime(2026, 1, d, 9, 0),
      status: s,
      movedTo: movedTo,
      extraFields: extra,
    );

    test('done sets status', () {
      final e = base.copyWith(occurrences: [ov(6, OccurrenceStatus.done)]);
      final o = run(e, utc(2026, 1, 5), utc(2026, 1, 8));
      expect(o.map((x) => x.status), [null, OccurrenceStatus.done, null]);
    });

    test('skipped sets status', () {
      final e = base.copyWith(occurrences: [ov(6, OccurrenceStatus.skipped)]);
      final o = run(e, utc(2026, 1, 5), utc(2026, 1, 8));
      expect(o[1].status, OccurrenceStatus.skipped);
    });

    test('cancelled removes the occurrence', () {
      final e = base.copyWith(occurrences: [ov(6, OccurrenceStatus.cancelled)]);
      final o = run(e, utc(2026, 1, 5), utc(2026, 1, 8));
      expect(starts(o), [utc(2026, 1, 5, 9), utc(2026, 1, 7, 9)]);
    });

    test('moved changes the start and keeps the original', () {
      final e = base.copyWith(
        occurrences: [
          ov(
            6,
            OccurrenceStatus.moved,
            movedTo: const FloatingTime(2026, 1, 6, 15, 30),
          ),
        ],
      );
      final o = run(e, utc(2026, 1, 5), utc(2026, 1, 8));
      expect(starts(o), [
        utc(2026, 1, 5, 9),
        utc(2026, 1, 6, 15, 30),
        utc(2026, 1, 7, 9),
      ]);
      expect(o[1].originalStart, const FloatingTime(2026, 1, 6, 9, 0));
      expect(o[1].status, OccurrenceStatus.moved);
    });

    test('R-15: movedTo applies whatever the status (done keeps the move)', () {
      final e = base.copyWith(
        occurrences: [
          ov(
            6,
            OccurrenceStatus.done,
            movedTo: const FloatingTime(2026, 1, 6, 15, 30),
          ),
        ],
      );
      final o = run(e, utc(2026, 1, 5), utc(2026, 1, 8));
      expect(starts(o), [
        utc(2026, 1, 5, 9),
        utc(2026, 1, 6, 15, 30),
        utc(2026, 1, 7, 9),
      ]);
      expect(o[1].status, OccurrenceStatus.done);
      expect(o[1].originalStart, const FloatingTime(2026, 1, 6, 9, 0));
    });

    test('R-15: a skipped occurrence moved into the range is found', () {
      final e = base.copyWith(
        occurrences: [
          ov(
            9,
            OccurrenceStatus.skipped,
            movedTo: const FloatingTime(2026, 1, 6, 12, 0),
          ),
        ],
      );
      final o = run(e, utc(2026, 1, 6), utc(2026, 1, 7));
      expect(starts(o), [utc(2026, 1, 6, 9), utc(2026, 1, 6, 12)]);
      expect(o[1].status, OccurrenceStatus.skipped);
    });

    test('R-15: cancelled still removes a moved occurrence', () {
      final e = base.copyWith(
        occurrences: [
          ov(
            6,
            OccurrenceStatus.cancelled,
            movedTo: const FloatingTime(2026, 1, 6, 15, 30),
          ),
        ],
      );
      final o = run(e, utc(2026, 1, 5), utc(2026, 1, 8));
      expect(starts(o), [utc(2026, 1, 5, 9), utc(2026, 1, 7, 9)]);
    });

    test('moved into the range from outside it is still found', () {
      final e = base.copyWith(
        occurrences: [
          ov(
            20,
            OccurrenceStatus.moved,
            movedTo: const FloatingTime(2026, 1, 6, 12, 0),
          ),
        ],
      );
      final o = run(e, utc(2026, 1, 6, 10), utc(2026, 1, 7));
      expect(starts(o), [utc(2026, 1, 6, 12)]);
    });

    test('title override maps to titleOverride', () {
      final e = base.copyWith(
        occurrences: [
          ov(6, OccurrenceStatus.done, extra: {'title': 'Special'}),
        ],
      );
      final o = run(e, utc(2026, 1, 5), utc(2026, 1, 8));
      expect(o.map((x) => x.titleOverride), [null, 'Special', null]);
    });

    test('an override matching nothing is ignored', () {
      final e = base.copyWith(
        occurrences: [
          const OccurrenceOverride(
            originalStart: FloatingTime(2026, 1, 6, 10, 0),
            status: OccurrenceStatus.cancelled,
          ),
        ],
      );
      expect(run(e, utc(2026, 1, 5), utc(2026, 1, 8)).length, 3);
    });
  });

  group('one-off and kinds', () {
    final fixed = FixedTime(
      DateTime.utc(2026, 11, 20, 15),
      const Duration(hours: -5),
    );

    test('fixed one-off inside the range gives 1, outside gives 0', () {
      final e = ev(fixed);
      expect(run(e, utc(2026, 11, 20), utc(2026, 11, 21)).length, 1);
      expect(run(e, utc(2026, 11, 21), utc(2026, 11, 22)).length, 0);
      expect(run(e, utc(2026, 11, 19), utc(2026, 11, 20, 15)).length, 0);
    });

    test('fixed one-off carries its end and ids', () {
      final e = ev(
        fixed,
        end: FixedTime(
          DateTime.utc(2026, 11, 20, 16, 30),
          const Duration(hours: -5),
        ),
      );
      final o = run(e, utc(2026, 11, 20), utc(2026, 11, 21)).single;
      expect(o.eventId, 'e1');
      expect(o.originalStart, fixed);
      expect(o.end, utc(2026, 11, 20, 16, 30));
      expect(o.allDay, isFalse);
    });

    test('fixed series keeps its own offset wall clock', () {
      final e = ev(fixed, rrule: 'FREQ=DAILY;COUNT=2');
      final o = run(e, utc(2026, 11, 1), utc(2026, 12, 1));
      expect(starts(o), [utc(2026, 11, 20, 15), utc(2026, 11, 21, 15)]);
    });

    test('floating end follows each occurrence', () {
      final e = ev(
        f,
        end: const FloatingTime(2026, 1, 5, 10, 30),
        rrule: 'FREQ=DAILY',
      );
      final o = run(e, utc(2026, 1, 6), utc(2026, 1, 7));
      expect(o.single.start, utc(2026, 1, 6, 9));
      expect(o.single.end, utc(2026, 1, 6, 10, 30));
    });

    test('no end means a null end', () {
      expect(run(ev(f), utc(2026, 1, 5), utc(2026, 1, 6)).single.end, isNull);
    });

    test('all-day occurrences span local midnight to midnight', () {
      final e = ev(const AllDay(2026, 11, 20), rrule: 'FREQ=DAILY;COUNT=2');
      final o = run(e, utc(2026, 11, 1), utc(2026, 12, 1));
      expect(o.map((x) => x.allDay), [true, true]);
      expect(o[0].start, utc(2026, 11, 20));
      expect(o[0].end, utc(2026, 11, 21));
      expect(o[1].start, utc(2026, 11, 21));
    });

    test('multi-day all-day runs to end date plus one', () {
      final e = ev(const AllDay(2026, 11, 20), end: const AllDay(2026, 11, 22));
      final o = run(e, utc(2026, 11, 1), utc(2026, 12, 1)).single;
      expect(o.end, utc(2026, 11, 23));
    });

    test('occurrences still running at from are included', () {
      final e = ev(
        const FloatingTime(2026, 1, 5, 9, 0),
        end: const FloatingTime(2026, 1, 5, 12, 0),
      );
      expect(run(e, utc(2026, 1, 5, 10), utc(2026, 1, 6)).length, 1);
      expect(run(e, utc(2026, 1, 5, 12), utc(2026, 1, 6)).length, 0);
    });

    test('a cancelled series yields nothing', () {
      final e = ev(f, rrule: 'FREQ=DAILY', status: EventStatus.cancelled);
      expect(run(e, utc(2026, 1, 1), utc(2026, 2, 1)), isEmpty);
    });
  });

  group('never occurs', () {
    test('UNTIL before the start gives nothing', () {
      final e = ev(f, rrule: 'FREQ=DAILY;UNTIL=20260104');
      expect(run(e, utc(2025, 1, 1), utc(2027, 1, 1)), isEmpty);
    });

    test('COUNT=0 gives nothing', () {
      final e = ev(f, rrule: 'FREQ=DAILY;COUNT=0');
      expect(run(e, utc(2025, 1, 1), utc(2027, 1, 1)), isEmpty);
    });

    test('a rule that can never match terminates', () {
      final e = ev(
        const FloatingTime(2026, 1, 31, 9, 0),
        rrule: 'FREQ=MONTHLY;BYMONTHDAY=32',
      );
      expect(run(e, utc(2026, 1, 1), utc(2036, 1, 1)), isEmpty);
    });

    test('an unparseable rule falls back to the single start', () {
      final e = ev(f, rrule: 'nonsense');
      expect(run(e, utc(2026, 1, 1), utc(2027, 1, 1)).length, 1);
    });
  });

  group('DST (America/Toronto)', () {
    test('floating 07:00 daily keeps the wall-clock across both changes', () {
      final r = torontoResolver();
      final e = ev(const FloatingTime(2027, 3, 1, 7, 0), rrule: 'FREQ=DAILY');
      DateTime at(CalendarEvent e, int y, int m, int d) =>
          run(e, utc(y, m, d), utc(y, m, d + 1), resolve: r).single.start;
      expect(at(e, 2027, 3, 13), utc(2027, 3, 13, 12));
      expect(at(e, 2027, 3, 14), utc(2027, 3, 14, 11));

      final e2 = ev(const FloatingTime(2027, 11, 1, 7, 0), rrule: 'FREQ=DAILY');
      expect(at(e2, 2027, 11, 6), utc(2027, 11, 6, 11));
      expect(at(e2, 2027, 11, 7), utc(2027, 11, 7, 12));
    });

    test(
      '02:30 on spring-forward day occurs once, as the package resolves it',
      () {
        final r = torontoResolver();
        final e = ev(
          const FloatingTime(2027, 3, 10, 2, 30),
          rrule: 'FREQ=DAILY',
        );
        final o = run(e, utc(2027, 3, 14), utc(2027, 3, 15), resolve: r);
        // Nonexistent 02:30 is resolved by package:timezone to 03:30 EDT.
        expect(starts(o), [utc(2027, 3, 14, 7, 30)]);
      },
    );

    test('01:30 on fall-back day occurs once, as the package resolves it', () {
      final r = torontoResolver();
      final e = ev(const FloatingTime(2027, 11, 3, 1, 30), rrule: 'FREQ=DAILY');
      final o = run(e, utc(2027, 11, 7), utc(2027, 11, 8), resolve: r);
      // Ambiguous 01:30 is resolved to the first one (EDT, UTC-4).
      expect(starts(o), [utc(2027, 11, 7, 5, 30)]);
    });
  });
}
