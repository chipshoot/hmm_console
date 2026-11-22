import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/states/planned_sessions.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/linked_event.dart';

import '../../calendar/support/fake_calendar_repository.dart';
import '../support/fake_activity_repository.dart';

class _Mode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.cloudApi;
}

final _now = DateTime(2026, 11, 21, 10, 0);

CalendarEvent _ev(
  String id,
  EventTime start, {
  String? rrule,
  EventOwner? owner,
  EventStatus status = EventStatus.active,
  List<OccurrenceOverride> occurrences = const [],
  Map<String, Object?> extraFields = const {},
}) => CalendarEvent(
  id: id,
  title: id,
  start: start,
  rrule: rrule,
  owner: owner,
  status: status,
  occurrences: occurrences,
  extraFields: extraFields,
  updatedAt: DateTime.utc(2026),
);

Activity _act(String id, String eventId, String occurrence, DateTime start) =>
    Activity(
      id: id,
      kind: 'health.walk',
      start: OffsetDateTime.fromLocal(start),
      durationMinutes: 30,
      plannedEvent: PlannedEventRef(eventId: eventId, occurrence: occurrence),
      updatedAt: DateTime.utc(2026, 11, 21),
    );

void main() {
  test('offers timed, open, unlinked occurrences from yesterday to now + 12 h, '
      'nearest first', () async {
    const doneStart = FloatingTime(2026, 11, 21, 8, 0);
    final repo = FakeCalendarRepository()
      ..seed(_ev('oneoff', const FloatingTime(2026, 11, 21, 18, 30)))
      ..seed(_ev('allday', const AllDay(2026, 11, 21)))
      ..seed(
        _ev(
          'done',
          doneStart,
          occurrences: const [
            OccurrenceOverride(
              originalStart: doneStart,
              status: OccurrenceStatus.done,
            ),
          ],
        ),
      )
      ..seed(
        _ev(
          'birthday',
          const FloatingTime(2026, 11, 21, 9, 0),
          owner: const EventOwner(subsystem: 'contacts', noteUuid: 'c1'),
          extraFields: {
            'linked': linkedToJson(LinkedKind.birthday, {'name': 'Ann'}),
          },
        ),
      )
      ..seed(
        _ev(
          'cancelled',
          const FloatingTime(2026, 11, 21, 11, 0),
          status: EventStatus.cancelled,
        ),
      )
      ..seed(
        _ev(
          'daily',
          const FloatingTime(2026, 11, 1, 7, 0),
          rrule: 'FREQ=DAILY',
        ),
      )
      // Outside the window: two days ago and tomorrow afternoon.
      ..seed(_ev('old', const FloatingTime(2026, 11, 19, 20, 0)))
      ..seed(_ev('later', const FloatingTime(2026, 11, 22, 9, 0)));

    final got = await plannedSessions(repo, now: _now);

    expect(
      [
        for (final p in got)
          '${p.event.id}@${p.occurrence.originalStart.wireKey}',
      ],
      [
        'daily@floating:2026-11-21T07:00',
        'oneoff@floating:2026-11-21T18:30',
        'daily@floating:2026-11-20T07:00',
      ],
    );
  });

  test('activitiesForOccurrence matches event id and occurrence key', () async {
    final around = DateTime(2026, 11, 21, 7);
    final repo = FakeActivityRepository([
      _act('a', 'e1', 'floating:2026-11-21T07:00', around),
      _act('b', 'e1', 'floating:2026-11-20T07:00', around),
      _act('c', 'e2', 'floating:2026-11-21T07:00', around),
      _act('far', 'e1', 'floating:2026-11-21T07:00', DateTime(2026, 11, 10)),
    ]);
    final got = await activitiesForOccurrence(
      repo,
      eventId: 'e1',
      wireKey: 'floating:2026-11-21T07:00',
      around: around.toUtc(),
    );
    expect([for (final a in got) a.id], ['a']);
  });

  test('the occurrence lookup is empty in Cloud API mode', () async {
    final c = ProviderContainer(
      overrides: [dataModeProvider.overrideWith(_Mode.new)],
    );
    addTearDown(c.dispose);
    final key = (
      eventId: 'e1',
      wireKey: 'floating:2026-11-21T07:00',
      around: DateTime.utc(2026, 11, 21, 12),
    );
    c.listen(activitiesForOccurrenceProvider(key), (_, _) {});
    expect(await c.read(activitiesForOccurrenceProvider(key).future), isEmpty);
  });
}
