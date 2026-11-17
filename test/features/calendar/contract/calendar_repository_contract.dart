import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/contract/calendar_errors.dart';
import 'package:hmm_console/features/calendar/contract/i_calendar_repository.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';

CalendarEvent _event(
  String id, {
  EventTime? start,
  String? rrule,
  EventOwner? owner,
  List<OccurrenceOverride> occurrences = const [],
  Map<String, Object?> extraFields = const {},
}) => CalendarEvent(
  id: id,
  title: 'Title $id',
  notes: 'some notes',
  start: start ?? const FloatingTime(2027, 5, 10, 9, 0),
  end: const FloatingTime(2027, 5, 10, 10, 0),
  rrule: rrule,
  reminders: const [Reminder(minutesBefore: 15)],
  owner: owner,
  source: EventSource.assistant,
  occurrences: occurrences,
  updatedAt: DateTime.utc(2020),
  extraFields: extraFields,
);

/// Counts events on [changes]; [next] resolves when the count passes [seen].
class _Changes {
  _Changes(Stream<void> s) {
    _sub = s.listen((_) => count++);
  }
  late final StreamSubscription<void> _sub;
  int count = 0;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  Future<void> expectBump(int before, Future<void> Function() action) async {
    await settle();
    final start = count;
    expect(start, greaterThanOrEqualTo(before));
    await action();
    for (var i = 0; i < 40 && count <= start; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(count, greaterThan(start));
  }

  Future<void> cancel() => _sub.cancel();
}

/// The contract every [ICalendarRepository] must satisfy (local now, the
/// server API repository later). [create] must return a fresh, empty store.
void runCalendarRepositoryContract(
  Future<ICalendarRepository> Function() create,
) {
  group('ICalendarRepository contract', () {
    late ICalendarRepository repo;
    setUp(() async => repo = await create());

    test(
      'save then get round-trips every field including extraFields',
      () async {
        final e = _event(
          'e1',
          rrule: 'FREQ=WEEKLY;BYDAY=MO',
          owner: const EventOwner(subsystem: 'diabetes', noteUuid: 'n-1'),
          occurrences: const [
            OccurrenceOverride(
              originalStart: FloatingTime(2027, 5, 10, 9, 0),
              status: OccurrenceStatus.done,
              extraFields: {'title': 'Special'},
            ),
          ],
          extraFields: const {
            'futureKey': {'a': 1},
          },
        );
        final saved = await repo.saveEvent(e);
        final got = await repo.getEvent('e1');
        expect(got, isNotNull);
        expect(got, saved);
        expect(got!.extraFields, {
          'futureKey': {'a': 1},
        });
        expect(got.title, 'Title e1');
        expect(got.owner, e.owner);
        expect(got.occurrences.single.extraFields['title'], 'Special');
        expect(
          got.updatedAt.isAfter(DateTime.utc(2021)),
          isTrue,
          reason: 'saveEvent stamps updatedAt',
        );
      },
    );

    test('getEvent of an unknown id is null', () async {
      expect(await repo.getEvent('nope'), isNull);
    });

    test('saving the same id twice updates, never duplicates', () async {
      await repo.saveEvent(_event('e1'));
      await repo.saveEvent(_event('e1').copyWith(title: 'Renamed'));
      final all = await repo.eventsBetween(
        DateTime.utc(2027, 5, 1),
        DateTime.utc(2027, 6, 1),
      );
      expect(all, hasLength(1));
      expect(all.single.title, 'Renamed');
    });

    test(
      'eventsBetween returns a repeating event that began before the range',
      () async {
        await repo.saveEvent(
          _event(
            'daily',
            start: const FloatingTime(2027, 1, 1, 9, 0),
            rrule: 'FREQ=DAILY',
          ),
        );
        await repo.saveEvent(
          _event(
            'once',
            start: const FloatingTime(2027, 1, 1, 9, 0),
          ).copyWith(clearEnd: true),
        );
        final got = await repo.eventsBetween(
          DateTime(2027, 5, 10),
          DateTime(2027, 5, 12),
        );
        expect(got.map((e) => e.id), ['daily']);
      },
    );

    test(
      'delete removes the event from getEvent, eventsBetween, eventsOwnedBy',
      () async {
        const owner = EventOwner(subsystem: 'auto', noteUuid: 'car-1');
        await repo.saveEvent(_event('e1', owner: owner));
        expect(await repo.eventsOwnedBy(owner), hasLength(1));
        await repo.deleteEvent('e1');
        expect(await repo.getEvent('e1'), isNull);
        expect(
          await repo.eventsBetween(DateTime(2027, 5, 1), DateTime(2027, 6, 1)),
          isEmpty,
        );
        expect(await repo.eventsOwnedBy(owner), isEmpty);
      },
    );

    test('deleting a missing event is a no-op', () async {
      await repo.deleteEvent('ghost');
      await repo.saveEvent(_event('e1'));
      await repo.deleteEvent('e1');
      await repo.deleteEvent('e1');
    });

    test('eventsOwnedBy matches subsystem and noteUuid', () async {
      await repo.saveEvent(
        _event(
          'a',
          owner: const EventOwner(subsystem: 'auto', noteUuid: 'x'),
        ),
      );
      await repo.saveEvent(
        _event(
          'b',
          owner: const EventOwner(subsystem: 'auto', noteUuid: 'y'),
        ),
      );
      await repo.saveEvent(
        _event(
          'c',
          owner: const EventOwner(subsystem: 'health', noteUuid: 'x'),
        ),
      );
      await repo.saveEvent(_event('d'));
      final got = await repo.eventsOwnedBy(
        const EventOwner(subsystem: 'auto', noteUuid: 'x'),
      );
      expect(got.map((e) => e.id), ['a']);
    });

    test(
      'setOccurrence on a missing id throws CalendarEventNotFound',
      () async {
        await expectLater(
          repo.setOccurrence(
            'missing',
            const OccurrenceOverride(
              originalStart: FloatingTime(2027, 5, 10, 9, 0),
              status: OccurrenceStatus.done,
            ),
          ),
          throwsA(isA<CalendarEventNotFound>()),
        );
      },
    );

    test(
      'setOccurrence replaces an override with the same originalStart',
      () async {
        await repo.saveEvent(_event('e1', rrule: 'FREQ=DAILY'));
        const at = FloatingTime(2027, 5, 11, 9, 0);
        await repo.setOccurrence(
          'e1',
          const OccurrenceOverride(
            originalStart: at,
            status: OccurrenceStatus.done,
          ),
        );
        final updated = await repo.setOccurrence(
          'e1',
          const OccurrenceOverride(
            originalStart: at,
            status: OccurrenceStatus.skipped,
          ),
        );
        expect(updated.occurrences, hasLength(1));
        expect(updated.occurrences.single.status, OccurrenceStatus.skipped);

        await repo.setOccurrence(
          'e1',
          const OccurrenceOverride(
            originalStart: FloatingTime(2027, 5, 12, 9, 0),
            status: OccurrenceStatus.done,
          ),
        );
        final stored = (await repo.getEvent('e1'))!;
        expect(stored.occurrences, hasLength(2));
      },
    );

    test('changes() emits after save, delete and setOccurrence', () async {
      final ch = _Changes(repo.changes());
      try {
        await ch.expectBump(0, () => repo.saveEvent(_event('e1')));
        await ch.expectBump(
          0,
          () => repo.setOccurrence(
            'e1',
            const OccurrenceOverride(
              originalStart: FloatingTime(2027, 5, 10, 9, 0),
              status: OccurrenceStatus.done,
            ),
          ),
        );
        await ch.expectBump(0, () => repo.deleteEvent('e1'));
      } finally {
        await ch.cancel();
      }
    });
  });
}
