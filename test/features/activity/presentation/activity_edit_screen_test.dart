import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/local_hmm_note_repository.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/features/activity/data/activity_codec.dart';
import 'package:hmm_console/features/activity/domain/activity.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/activity/presentation/screens/activity_edit_screen.dart';
import 'package:hmm_console/features/activity/states/activity_edit_state.dart';
import 'package:hmm_console/features/activity/states/activity_list_state.dart';
import 'package:hmm_console/features/activity/states/activity_providers.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/notes/data/models/hmm_note.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../calendar/support/fake_calendar_repository.dart';
import '../support/fake_activity_repository.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

/// Answers title lookups only.
class _Notes implements IHmmNoteRepository {
  _Notes(this.byUuid);
  final Map<String, HmmNote> byUuid;

  @override
  Future<HmmNote?> getNoteByUuid(String uuid) async => byUuid[uuid];

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

final _now = DateTime(2026, 11, 21, 10);

HmmNote _note(String uuid, String subject) => HmmNote(
  id: 1,
  uuid: uuid,
  subject: subject,
  authorId: 1,
  createDate: DateTime.utc(2026),
);

Activity _act(String id, String kind, {List<ActivityLink> links = const []}) =>
    Activity(
      id: id,
      kind: kind,
      start: OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 8)),
      durationMinutes: 30,
      links: links,
      updatedAt: DateTime.utc(2026, 11, 21),
    );

/// Mounts a home page that pushes the form, so the form can pop.
Future<void> _mount(
  WidgetTester tester, {
  required String? id,
  FakeActivityRepository? repo,
  DataMode mode = DataMode.local,
  Map<String, HmmNote> notes = const {},
  HmmNote? pick,
  TargetPlatform platform = TargetPlatform.android,
  FakeCalendarRepository? calendar,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (calendar != null)
        localCalendarRepositoryProvider.overrideWithValue(calendar),
      dataModeProvider.overrideWith(() => _Mode(mode)),
      if (repo != null) localActivityRepositoryProvider.overrideWithValue(repo),
      localHmmNoteRepositoryProvider.overrideWithValue(_Notes(notes)),
      activityClockProvider.overrideWithValue(() => _now),
      activityNotePickerProvider.overrideWithValue((_) async => pick),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityEditScreen(activityId: id),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester t) async {
  await t.tap(find.byKey(const Key('activity-save')));
  await t.pumpAndSettle();
}

/// A calendar whose `setOccurrence` always fails.
class _FailingCalendar extends FakeCalendarRepository {
  @override
  Future<CalendarEvent> setOccurrence(String eventId, OccurrenceOverride o) =>
      throw StateError('disk full');
}

CalendarEvent _session(String id, String title, EventTime start) =>
    CalendarEvent(
      id: id,
      title: title,
      start: start,
      updatedAt: DateTime.utc(2026),
    );

Future<void> _openPlanned(WidgetTester t) async {
  final row = find.byKey(const Key('activity-planned'));
  await t.ensureVisible(row);
  await t.pumpAndSettle();
  await t.tap(row);
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an unknown kind shows the stored id; the picker is disabled', (
    t,
  ) async {
    final original = ActivityCodec.decode('p1', {
      'schemaVersion': 1,
      'id': 'p1',
      'kind': 'health.parkour',
      'start': '2026-11-21T08:00:00Z',
      'durationMinutes': 30,
      'source': 'manual',
      'updatedAt': '2026-11-21T08:30:00Z',
    });
    await _mount(t, id: 'p1', repo: FakeActivityRepository([original]));
    expect(find.text('Unknown kind'), findsOneWidget);
    expect(find.text('health.parkour'), findsOneWidget);
    final tile = t.widget<ListTile>(find.byKey(const Key('activity-kind')));
    expect(tile.enabled, isFalse);
  });

  testWidgets('a link to a missing note shows removed; saving keeps it', (
    t,
  ) async {
    const link = ActivityLink(noteUuid: 'gone', role: 'book');
    final repo = FakeActivityRepository([
      _act('r1', 'reading.reading', links: const [link]),
    ]);
    await _mount(t, id: 'r1', repo: repo);
    expect(find.text('Note removed'), findsOneWidget);

    await _tapSave(t);
    expect((await repo.getActivity('r1'))!.links, const [link]);
    expect(find.byType(ActivityEditScreen), findsNothing);
  });

  testWidgets('a link to a deleted note shows removed; saving keeps it', (
    t,
  ) async {
    const link = ActivityLink(noteUuid: 'trashed', role: 'book');
    final repo = FakeActivityRepository([
      _act('r1', 'reading.reading', links: const [link]),
    ]);
    final deleted = HmmNote(
      id: 2,
      uuid: 'trashed',
      subject: 'Dune',
      authorId: 1,
      createDate: DateTime.utc(2026),
      deletedAt: DateTime.utc(2026, 11, 20),
    );
    await _mount(t, id: 'r1', repo: repo, notes: {'trashed': deleted});
    expect(find.text('Note removed'), findsOneWidget);
    expect(find.text('Dune'), findsNothing);

    await _tapSave(t);
    expect((await repo.getActivity('r1'))!.links, const [link]);
    expect(find.byType(ActivityEditScreen), findsNothing);
  });

  testWidgets('a linked note shows its title', (t) async {
    await _mount(
      t,
      id: 'r1',
      repo: FakeActivityRepository([
        _act(
          'r1',
          'reading.reading',
          links: const [ActivityLink(noteUuid: 'book')],
        ),
      ]),
      notes: {'book': _note('book', 'Dune')},
    );
    expect(find.text('Dune'), findsOneWidget);
  });

  testWidgets('a note picked on reading saves a book link', (t) async {
    SharedPreferences.setMockInitialValues({
      kActivityRecentKindsKey: ['reading.reading'],
    });
    final repo = FakeActivityRepository();
    await _mount(t, id: null, repo: repo, pick: _note('n-dune', 'Dune'));
    expect(find.text('Reading'), findsOneWidget);

    await t.tap(find.text('30 min'));
    await t.pump();
    await t.tap(find.byKey(const Key('activity-link')));
    await t.pumpAndSettle();
    expect(find.text('Dune'), findsOneWidget);

    await _tapSave(t);
    final saved = await repo.activitiesBetween(
      DateTime.utc(2000),
      DateTime.utc(9999),
    );
    expect(saved, hasLength(1));
    expect(saved.single.kind, 'reading.reading');
    expect(saved.single.durationMinutes, 30);
    expect(saved.single.links, const [
      ActivityLink(noteUuid: 'n-dune', role: 'book'),
    ]);
  });

  testWidgets('save stays disabled until a duration is set', (t) async {
    await _mount(t, id: null, repo: FakeActivityRepository());
    TextButton save() =>
        t.widget<TextButton>(find.byKey(const Key('activity-save')));
    expect(save().onPressed, isNull);
    await t.tap(find.text('45 min'));
    await t.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('delete leaves the form; Undo restores the same id', (t) async {
    final repo = FakeActivityRepository([_act('w1', 'health.walk')]);
    await _mount(t, id: 'w1', repo: repo);

    await t.tap(find.byTooltip('Delete activity'));
    await t.pumpAndSettle();
    expect(find.byType(ActivityEditScreen), findsNothing);
    expect(await repo.getActivity('w1'), isNull);
    expect(find.text('Activity deleted'), findsOneWidget);

    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    final back = await repo.getActivity('w1');
    expect(back, isNotNull);
    expect(back!.kind, 'health.walk');
    expect(find.text('Activity restored'), findsOneWidget);
  });

  testWidgets('distance shows for a walk and is saved', (t) async {
    final repo = FakeActivityRepository([_act('w1', 'health.walk')]);
    await _mount(t, id: 'w1', repo: repo);
    await t.enterText(find.byKey(const Key('activity-distance')), '2,5');
    await _tapSave(t);
    final m = (await repo.getActivity('w1'))!.measurements.single;
    expect(m.name, 'distance');
    expect(m.value, 2.5);
  });

  testWidgets('picking Gym in the kind sheet hides distance', (t) async {
    await _mount(t, id: null, repo: FakeActivityRepository());
    expect(find.byKey(const Key('activity-distance')), findsOneWidget);
    await t.tap(find.byKey(const Key('activity-kind')));
    await t.pumpAndSettle();
    await t.tap(find.text('Gym'));
    await t.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
    expect(find.byKey(const Key('activity-distance')), findsNothing);
  });

  testWidgets('iOS uses the Cupertino intensity control and kind sheet', (
    t,
  ) async {
    await _mount(
      t,
      id: null,
      repo: FakeActivityRepository(),
      platform: TargetPlatform.iOS,
    );
    expect(
      find.byType(CupertinoSlidingSegmentedControl<ActivityIntensity>),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('activity-kind')));
    await t.pumpAndSettle();
    expect(find.byType(CupertinoListTile), findsWidgets);
    await t.tap(find.text('Yoga'));
    await t.pumpAndSettle();
    expect(find.text('Yoga'), findsOneWidget);
  });

  testWidgets('iOS: changing the ended date keeps the time of day', (t) async {
    // Ended 18:40 on 20 Nov (start 18:10, 30 min).
    final repo = FakeActivityRepository([
      Activity(
        id: 'w1',
        kind: 'health.walk',
        start: OffsetDateTime.fromLocal(DateTime(2026, 11, 20, 18, 10)),
        durationMinutes: 30,
        updatedAt: DateTime.utc(2026, 11, 20),
      ),
    ]);
    await _mount(t, id: 'w1', repo: repo, platform: TargetPlatform.iOS);
    await t.tap(find.byKey(const Key('activity-ended-date')));
    await t.pumpAndSettle();
    // The wheel in date mode emits midnight of the picked day.
    t
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2026, 11, 19));
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    await _tapSave(t);
    final saved = (await repo.getActivity('w1'))!;
    expect(
      saved.start,
      OffsetDateTime.fromLocal(DateTime(2026, 11, 19, 18, 10)),
    );
  });

  testWidgets('Cloud API mode shows the unavailable message', (t) async {
    await _mount(t, id: null, mode: DataMode.cloudApi);
    expect(
      find.textContaining("isn't available in Cloud API mode"),
      findsOneWidget,
    );
  });

  testWidgets('app bar has the activity edit help button', (t) async {
    await _mount(t, id: null, repo: FakeActivityRepository());
    final help = t.widget<HelpButton>(find.byType(HelpButton));
    expect(help.helpId, HelpId.activityEdit);
  });

  group('planned session', () {
    const nine = FloatingTime(2026, 11, 21, 9, 0);

    testWidgets('the row is hidden when the calendar is unavailable', (
      t,
    ) async {
      await _mount(t, id: null, repo: FakeActivityRepository());
      expect(find.byKey(const Key('activity-planned')), findsNothing);
    });

    testWidgets('picking a session links it and save marks it done', (t) async {
      final cal = FakeCalendarRepository()
        ..seed(_session('w', 'Morning walk', nine));
      final repo = FakeActivityRepository();
      await _mount(t, id: null, repo: repo, calendar: cal);
      await t.tap(find.text('30 min'));
      await t.pump();
      await _openPlanned(t);
      expect(find.text('None'), findsWidgets);
      await t.tap(find.textContaining('Morning walk').last);
      await t.pumpAndSettle();
      expect(find.textContaining('Morning walk'), findsOneWidget);

      await _tapSave(t);
      final saved = (await repo.activitiesBetween(
        DateTime.utc(2000),
        DateTime.utc(9999),
      )).single;
      expect(saved.plannedEvent!.occurrence, nine.wireKey);
      expect(saved.start, OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 9)));
      expect(cal.log, ['occ:w:done']);
    });

    testWidgets('iOS: the sessions come in a Cupertino action sheet', (
      t,
    ) async {
      final cal = FakeCalendarRepository()
        ..seed(_session('w', 'Morning walk', nine));
      await _mount(
        t,
        id: null,
        repo: FakeActivityRepository(),
        calendar: cal,
        platform: TargetPlatform.iOS,
      );
      await _openPlanned(t);
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
    });

    testWidgets('a failed mark keeps the save and says so', (t) async {
      final cal = _FailingCalendar()..seed(_session('w', 'Morning walk', nine));
      final repo = FakeActivityRepository();
      await _mount(t, id: null, repo: repo, calendar: cal);
      await t.tap(find.text('30 min'));
      await t.pump();
      await _openPlanned(t);
      await t.tap(find.textContaining('Morning walk').last);
      await t.pumpAndSettle();
      await _tapSave(t);
      expect(
        await repo.activitiesBetween(DateTime.utc(2000), DateTime.utc(9999)),
        hasLength(1),
      );
      expect(
        find.text("Saved, but the calendar session couldn't be marked done"),
        findsOneWidget,
      );
    });

    testWidgets('deleting a linked activity leaves the calendar alone', (
      t,
    ) async {
      final cal = FakeCalendarRepository()
        ..seed(_session('w', 'Morning walk', nine));
      final a = Activity(
        id: 'x',
        kind: 'health.walk',
        start: OffsetDateTime.fromLocal(DateTime(2026, 11, 21, 9)),
        durationMinutes: 30,
        plannedEvent: PlannedEventRef(eventId: 'w', occurrence: nine.wireKey),
        updatedAt: DateTime.utc(2026, 11, 21),
      );
      final repo = FakeActivityRepository([a]);
      await _mount(t, id: 'x', repo: repo, calendar: cal);
      await t.tap(find.byTooltip('Delete activity'));
      await t.pumpAndSettle();
      expect(await repo.getActivity('x'), isNull);
      expect(cal.log, isEmpty);
    });
  });
}
