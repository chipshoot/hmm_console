import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/features/activity/data/activity_codec.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/presentation/distance_unit.dart';
import 'package:hmm_console/features/activity/states/activity_edit_state.dart';
import 'package:hmm_console/features/activity/states/activity_list_state.dart';
import 'package:hmm_console/features/activity/states/activity_providers.dart';
import 'package:hmm_console/features/activity/states/planned_sessions.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/occurrence.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../calendar/support/fake_calendar_repository.dart';
import '../support/fake_activity_repository.dart';

class _Mode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.local;
}

class _Notes implements IHmmNoteRepository {
  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => null;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

final _now = DateTime(2026, 11, 21, 10, 0);

/// A calendar whose `setOccurrence` always fails.
class _FailingCalendar extends FakeCalendarRepository {
  @override
  Future<CalendarEvent> setOccurrence(String eventId, OccurrenceOverride o) {
    log.add('occ-failed:$eventId');
    throw StateError('disk full');
  }
}

Future<(ProviderContainer, FakeActivityRepository)> _setUp({
  List<Activity> seed = const [],
  FakeCalendarRepository? calendar,
}) async {
  final repo = FakeActivityRepository(seed);
  final container = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(_Mode.new),
      localActivityRepositoryProvider.overrideWithValue(repo),
      if (calendar != null)
        localCalendarRepositoryProvider.overrideWithValue(calendar),
      localHmmNoteRepositoryProvider.overrideWithValue(_Notes()),
      activityClockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  return (container, repo);
}

Future<ActivityEditState> _load(ProviderContainer c, String? id) async {
  c.listen(activityEditProvider(id), (_, _) {});
  return c.read(activityEditProvider(id).future);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaultDistanceUnit picks miles only where miles are used', () {
    expect(defaultDistanceUnit(const Locale('en', 'US')), 'mi');
    expect(defaultDistanceUnit(const Locale('en', 'GB')), 'mi');
    expect(defaultDistanceUnit(const Locale('zh', 'CN')), 'km');
    expect(defaultDistanceUnit(const Locale('en')), 'km');
  });

  test('a new entry defaults to walk, ended now, no duration', () async {
    final (c, _) = await _setUp();
    final s = await _load(c, null);
    expect(s.isNew, isTrue);
    expect(s.kindId, 'health.walk');
    expect(s.durationMinutes, isNull);
    expect(s.ended, _now);
    expect(s.intensity, ActivityIntensity.moderate);
    expect(s.canSave, isFalse);
  });

  test('kind + 30 min enables save; start = ended - 30 min', () async {
    final (c, _) = await _setUp();
    await _load(c, null);
    final n = c.read(activityEditProvider(null).notifier);
    n.setKind('health.gym');
    n.setDuration(30);
    final s = c.read(activityEditProvider(null)).requireValue;
    expect(s.canSave, isTrue);
    expect(
      s.start,
      OffsetDateTime.fromLocal(_now.subtract(const Duration(minutes: 30))),
    );
  });

  test('ended in the future disables save with the future flag', () async {
    final (c, _) = await _setUp();
    await _load(c, null);
    final n = c.read(activityEditProvider(null).notifier);
    n.setDuration(30);
    n.setEnded(_now.add(const Duration(minutes: 1)));
    final s = c.read(activityEditProvider(null)).requireValue;
    expect(s.endedInFuture, isTrue);
    expect(s.canSave, isFalse);
  });

  test('duration outside 1..1440 disables save', () async {
    final (c, _) = await _setUp();
    await _load(c, null);
    final n = c.read(activityEditProvider(null).notifier);
    n.setDuration(1441);
    expect(c.read(activityEditProvider(null)).requireValue.canSave, isFalse);
    n.setDuration(0);
    expect(c.read(activityEditProvider(null)).requireValue.canSave, isFalse);
    n.setDuration(1440);
    expect(c.read(activityEditProvider(null)).requireValue.canSave, isTrue);
  });

  test('save records the kind first in recent kinds, at most 5', () async {
    SharedPreferences.setMockInitialValues({
      kActivityRecentKindsKey: [
        'health.run',
        'health.gym',
        'health.yoga',
        'reading.reading',
        'development.coding',
      ],
    });
    final (c, repo) = await _setUp();
    final s0 = await _load(c, null);
    // Most recently used kind is the default.
    expect(s0.kindId, 'health.run');
    final n = c.read(activityEditProvider(null).notifier);
    n.setKind('health.swim');
    n.setDuration(30);
    final saved = await n.save();
    expect(await repo.getActivity(saved.id), isNotNull);
    expect(saved.source, ActivitySource.manual);
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(kActivityRecentKindsKey)!;
    expect(recent.first, 'health.swim');
    expect(recent.length, lessThanOrEqualTo(5));
    expect(recent, [
      'health.swim',
      'health.run',
      'health.gym',
      'health.yoga',
      'reading.reading',
    ]);
  });

  test('a user-picked intensity is kept when the kind changes', () async {
    final (c, _) = await _setUp();
    await _load(c, null);
    final n = c.read(activityEditProvider(null).notifier);
    n.setKind('health.run');
    expect(
      c.read(activityEditProvider(null)).requireValue.intensity,
      ActivityIntensity.vigorous,
    );
    n.setIntensity(ActivityIntensity.light);
    n.setKind('health.gym');
    expect(
      c.read(activityEditProvider(null)).requireValue.intensity,
      ActivityIntensity.light,
    );
  });

  test('editing an unknown-kind entry changes only the edited field '
      '(older build meets newer data)', () async {
    final original = ActivityCodec.decode('p1', {
      'schemaVersion': 1,
      'id': 'p1',
      'kind': 'health.parkour',
      'start': '2026-11-20T18:00:00-05:00',
      'durationMinutes': 30,
      'intensity': 'vigorous',
      'measurements': [
        {'name': 'flips', 'value': 3, 'unit': 'count', 'extra': true},
      ],
      'links': [
        {'noteUuid': 'n1', 'role': 'spot', 'x': 1},
      ],
      'notes': 'Rooftops',
      'details': {
        'health': {'hr': 120},
      },
      'source': 'assistant',
      'draft': true,
      'updatedAt': '2026-11-20T23:31:00Z',
      'future': 1,
    });
    final (c, repo) = await _setUp(seed: [original]);
    final s = await _load(c, 'p1');
    expect(s.kindId, 'health.parkour');
    expect(s.isUnknownKind, isTrue);
    final n = c.read(activityEditProvider('p1').notifier);
    n.setDuration(45);
    await n.save();

    final saved = ActivityCodec.encode((await repo.getActivity('p1'))!);
    final expected = ActivityCodec.encode(original);
    expect(saved['durationMinutes'], 45);
    expect(saved['updatedAt'], isNot(expected['updatedAt']));
    expect(
      {...saved}
        ..remove('durationMinutes')
        ..remove('updatedAt'),
      {...expected}
        ..remove('durationMinutes')
        ..remove('updatedAt'),
    );
  });

  test('a walk with distance switched to gym saves no measurements', () async {
    final walk = Activity(
      id: 'w1',
      kind: 'health.walk',
      start: OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 8)),
      durationMinutes: 30,
      measurements: const [
        ActivityMeasurement(name: 'distance', value: 2.4, unit: 'km'),
      ],
      updatedAt: DateTime.utc(2026, 11, 21),
    );
    final (c, repo) = await _setUp(seed: [walk]);
    final s = await _load(c, 'w1');
    expect(s.distance, 2.4);
    expect(s.distanceUnit, 'km');
    c.read(activityEditProvider('w1').notifier).setKind('health.gym');
    await c.read(activityEditProvider('w1').notifier).save();
    final saved = (await repo.getActivity('w1'))!;
    expect(saved.kind, 'health.gym');
    expect(saved.measurements, isEmpty);
  });

  test('distance on a new walk saves one distance measurement', () async {
    final (c, repo) = await _setUp();
    await _load(c, null);
    final n = c.read(activityEditProvider(null).notifier);
    n.setDuration(30);
    n.setDistance(2.4, 'mi');
    final saved = await n.save();
    expect((await repo.getActivity(saved.id))!.measurements, const [
      ActivityMeasurement(name: 'distance', value: 2.4, unit: 'mi'),
    ]);
  });

  test('the planned event can be set and is saved', () async {
    final (c, repo) = await _setUp(calendar: FakeCalendarRepository());
    await _load(c, null);
    final n = c.read(activityEditProvider(null).notifier);
    n.setDuration(30);
    const ref = PlannedEventRef(eventId: 'e1', occurrence: '20261121');
    n.setPlanned(ref);
    expect(c.read(activityEditProvider(null)).requireValue.planned, ref);
    final saved = await n.save();
    expect((await repo.getActivity(saved.id))!.plannedEvent, ref);
  });

  group('planned session', () {
    const seven = FloatingTime(2026, 11, 21, 7, 0);
    final daily = CalendarEvent(
      id: 'daily',
      title: 'Morning walk',
      start: const FloatingTime(2026, 11, 1, 7, 0),
      rrule: 'FREQ=DAILY',
      updatedAt: DateTime.utc(2026),
    );
    final session = PlannedSession(
      event: daily,
      occurrence: Occurrence(
        eventId: 'daily',
        originalStart: seven,
        start: DateTime(2026, 11, 21, 7).toUtc(),
      ),
    );

    int occCalls(FakeCalendarRepository cal) =>
        cal.log.where((e) => e.startsWith('occ')).length;

    test('picking keeps the duration and starts at the occurrence', () async {
      final (c, _) = await _setUp();
      await _load(c, null);
      final n = c.read(activityEditProvider(null).notifier);
      n.setDuration(30);
      n.pickPlannedSession(session);
      final s = c.read(activityEditProvider(null)).requireValue;
      expect(s.planned!.occurrence, 'floating:2026-11-21T07:00');
      expect(s.planned!.eventId, 'daily');
      expect(
        s.planned!.at,
        OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 7)),
      );
      expect(s.start, OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 7)));
      expect(s.ended, DateTime(2026, 11, 21, 7, 30));
      expect(s.durationMinutes, 30);
    });

    test('picking without a duration ends at the occurrence start', () async {
      final (c, _) = await _setUp();
      await _load(c, null);
      final n = c.read(activityEditProvider(null).notifier);
      n.pickPlannedSession(session);
      final s = c.read(activityEditProvider(null)).requireValue;
      expect(s.ended, DateTime(2026, 11, 21, 7));
      expect(s.durationMinutes, isNull);
    });

    test('picking on an existing entry moves its start', () async {
      final a = Activity(
        id: 'x',
        kind: 'health.walk',
        start: OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 8)),
        durationMinutes: 45,
        updatedAt: DateTime.utc(2026, 11, 21),
      );
      final cal = FakeCalendarRepository()..seed(daily);
      final (c, repo) = await _setUp(seed: [a], calendar: cal);
      await _load(c, 'x');
      final n = c.read(activityEditProvider('x').notifier);
      n.pickPlannedSession(session);
      await n.save();
      final saved = (await repo.getActivity('x'))!;
      expect(saved.start, OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 7)));
      expect(saved.durationMinutes, 45);
      expect(occCalls(cal), 1);
    });

    test('save marks the occurrence done once', () async {
      final cal = FakeCalendarRepository()..seed(daily);
      final (c, repo) = await _setUp(calendar: cal);
      await _load(c, null);
      final n = c.read(activityEditProvider(null).notifier);
      n.setDuration(30);
      n.pickPlannedSession(session);
      final saved = await n.save();
      expect(await repo.getActivity(saved.id), isNotNull);
      expect(occCalls(cal), 1);
      final o = cal.events['daily']!.occurrences.single;
      expect(o.status, OccurrenceStatus.done);
      expect(o.originalStart, seven);
      expect(
        c.read(activityEditProvider(null)).requireValue.plannedMarkFailed,
        isFalse,
      );
    });

    test('a failed mark keeps the activity saved and sets the flag', () async {
      final cal = _FailingCalendar()..seed(daily);
      final (c, repo) = await _setUp(calendar: cal);
      await _load(c, null);
      final n = c.read(activityEditProvider(null).notifier);
      n.setDuration(30);
      n.pickPlannedSession(session);
      final saved = await n.save();
      expect((await repo.getActivity(saved.id))!.plannedEvent, isNotNull);
      expect(cal.log, ['occ-failed:daily']);
      expect(
        c.read(activityEditProvider(null)).requireValue.plannedMarkFailed,
        isTrue,
      );
    });

    test('an unchanged or cleared link never marks the calendar', () async {
      final a = Activity(
        id: 'x',
        kind: 'health.walk',
        start: OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 7)),
        durationMinutes: 30,
        plannedEvent: const PlannedEventRef(
          eventId: 'daily',
          occurrence: 'floating:2026-11-21T07:00',
        ),
        updatedAt: DateTime.utc(2026, 11, 21),
      );
      final cal = FakeCalendarRepository()..seed(daily);
      final (c, repo) = await _setUp(seed: [a], calendar: cal);
      await _load(c, 'x');
      final n = c.read(activityEditProvider('x').notifier);
      n.setDuration(40);
      await n.save();
      expect(occCalls(cal), 0);
      n.setPlanned(null);
      await n.save();
      expect(occCalls(cal), 0);
      expect((await repo.getActivity('x'))!.plannedEvent, isNull);
    });
  });
}
