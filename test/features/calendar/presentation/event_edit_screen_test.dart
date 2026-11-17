import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/features/calendar/contract/i_reminder_scheduler.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/notifications/local_reminder_scheduler.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_plan.dart';
import 'package:hmm_console/features/calendar/presentation/screens/event_edit_screen.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/calendar_view_state.dart';
import 'package:hmm_console/features/calendar/states/event_edit_state.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_calendar_repository.dart';

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

class _Scheduler implements IReminderScheduler {
  _Scheduler({this.granted = true});
  final bool granted;
  int requests = 0;
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> reschedule(List<PlannedReminder> upcoming) async {}
  @override
  Future<bool> requestPermission() async {
    requests++;
    return granted;
  }
}

/// A fixed time at local wall-clock [y]-[m]-[d] [h]:[min].
FixedTime _fixed(int y, int m, int d, int h, [int min = 0]) {
  final local = DateTime(y, m, d, h, min);
  return FixedTime(local.toUtc(), local.timeZoneOffset);
}

final _day = DateTime(2030, 1, 15);

Future<ProviderContainer> _mount(
  WidgetTester tester,
  FakeCalendarRepository repo, {
  String? eventId,
  String? at,
  DateTime? day,
  _Scheduler? scheduler,
  DataMode mode = DataMode.local,
  ProviderContainer? container,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c =
      container ??
      ProviderContainer(
        overrides: [
          dataModeProvider.overrideWith(() => _Mode(mode)),
          localCalendarRepositoryProvider.overrideWithValue(repo),
          deviceShortestSideProvider.overrideWith(
            () => DeviceShortestSideNotifier(390),
          ),
          reminderSchedulerProvider.overrideWithValue(
            scheduler ?? _Scheduler(),
          ),
        ],
      );
  if (container == null) addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventEditScreen(
          key: UniqueKey(),
          eventId: eventId,
          at: at,
          day: day ?? (eventId == null ? _day : null),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Future<void> _typeTitle(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('calendar-edit-title')), text);
  await tester.pump();
}

CalendarEvent _ev(
  String id,
  EventTime start, {
  EventTime? end,
  String? rrule,
  String title = 'Walk',
  List<Reminder> reminders = const [Reminder(minutesBefore: 15)],
}) => CalendarEvent(
  id: id,
  title: title,
  start: start,
  end: end,
  rrule: rrule,
  reminders: reminders,
  notes: 'keep me',
  updatedAt: DateTime.utc(2020),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a new event defaults to one 15-minute reminder', (tester) async {
    await _mount(tester, FakeCalendarRepository());
    expect(find.text('15 minutes before'), findsOneWidget);
    expect(find.text('Starts'), findsOneWidget);
  });

  testWidgets('an end before the start blocks saving and says why', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..seed(
        _ev(
          'x',
          _fixed(2030, 1, 15, 10),
          end: _fixed(2030, 1, 15, 9),
          reminders: const [],
        ),
      );
    await _mount(tester, repo, eventId: 'x');
    expect(find.text('The end is before the start.'), findsOneWidget);
    await _save(tester);
    expect(repo.log, isEmpty);
    expect(find.byType(EventEditScreen), findsOneWidget);
  });

  testWidgets('a new one-off timed event is stored as fixed', (tester) async {
    final repo = FakeCalendarRepository();
    await _mount(tester, repo);
    await _typeTitle(tester, 'Dentist');
    await _save(tester);
    final e = repo.events.values.single;
    expect(e.title, 'Dentist');
    expect(e.start, isA<FixedTime>());
    final wall = localTimeOf((e.start as FixedTime).instant);
    expect([wall.year, wall.month, wall.day, wall.hour], [2030, 1, 15, 9]);
    expect(e.start.toWire().keys.single, 'fixed');
    expect(e.end, isA<FixedTime>());
    expect(e.reminders, const [Reminder(minutesBefore: 15)]);
    expect(e.rrule, isNull);
  });

  testWidgets('an all-day event is stored as allDay', (tester) async {
    final repo = FakeCalendarRepository();
    await _mount(tester, repo);
    await _typeTitle(tester, 'Holiday');
    await tester.tap(find.byKey(const Key('calendar-edit-allday')));
    await tester.pumpAndSettle();
    await _save(tester);
    final e = repo.events.values.single;
    expect(e.start.toWire(), {'allDay': '2030-01-15'});
  });

  testWidgets('making a one-off 19:00 event repeat stores it floating', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..seed(_ev('w', _fixed(2030, 1, 15, 19), end: _fixed(2030, 1, 15, 20)));
    await _mount(tester, repo, eventId: 'w');
    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    await _save(tester);
    final e = repo.events['w']!;
    expect(e.start.toWire(), {'floating': '2030-01-15T19:00'});
    expect(e.end!.toWire(), {'floating': '2030-01-15T20:00'});
    expect(e.rrule, 'FREQ=DAILY');
    expect(e.notes, 'keep me');
  });

  testWidgets('a custom rule keeps its text and is read-only until Clear', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..seed(
        _ev(
          'c',
          const FloatingTime(2030, 1, 15, 19, 0),
          rrule: 'FREQ=MONTHLY;BYDAY=1MO',
        ),
      );
    await _mount(tester, repo, eventId: 'c', at: 'floating:2030-01-15T19:00');
    expect(find.text('Custom repeat'), findsOneWidget);
    expect(find.text('Daily'), findsNothing);
    await _typeTitle(tester, 'Walk 2');
    await _save(tester);
    await tester.tap(find.text('All occurrences'));
    await tester.pumpAndSettle();
    expect(repo.events['c']!.rrule, 'FREQ=MONTHLY;BYDAY=1MO');
    expect(repo.events['c']!.title, 'Walk 2');

    await _mount(tester, repo, eventId: 'c');
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Custom repeat'), findsNothing);
    expect(find.text('Daily'), findsOneWidget);
  });

  testWidgets('first save with a reminder asks permission once; a denial '
      'sets the banner; later saves do not ask', (tester) async {
    final repo = FakeCalendarRepository();
    final scheduler = _Scheduler(granted: false);
    final c = await _mount(tester, repo, scheduler: scheduler);
    expect(c.read(remindOnDeviceProvider), isTrue);
    await _typeTitle(tester, 'One');
    await _save(tester);
    expect(scheduler.requests, 1);
    expect(c.read(calendarPermissionDeniedProvider), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kCalendarPermissionAskedKey), isTrue);

    await _mount(tester, repo, container: c);
    await _typeTitle(tester, 'Two');
    await _save(tester);
    expect(repo.events.length, 2);
    expect(scheduler.requests, 1);
  });

  testWidgets('a save without reminders does not ask permission', (
    tester,
  ) async {
    final repo = FakeCalendarRepository();
    final scheduler = _Scheduler(granted: false);
    final c = await _mount(tester, repo, scheduler: scheduler);
    await _typeTitle(tester, 'Quiet');
    await tester.tap(find.byTooltip('Remove reminder'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(repo.events.values.single.reminders, isEmpty);
    expect(scheduler.requests, 0);
    expect(c.read(calendarPermissionDeniedProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kCalendarPermissionAskedKey), isNull);
  });

  group('editing a repeating event', () {
    FakeCalendarRepository seeded() => FakeCalendarRepository()
      ..seed(
        _ev(
          'r',
          const FloatingTime(2030, 1, 13, 19, 0),
          end: const FloatingTime(2030, 1, 13, 20, 0),
          rrule: 'FREQ=DAILY',
        ),
      );
    const at = 'floating:2030-01-15T19:00';

    testWidgets('asks This occurrence or All occurrences', (tester) async {
      final repo = seeded();
      await _mount(tester, repo, eventId: 'r', at: at);
      await _typeTitle(tester, 'Run');
      await _save(tester);
      expect(find.text('This occurrence'), findsOneWidget);
      expect(find.text('All occurrences'), findsOneWidget);
    });

    testWidgets('This occurrence with a new title stores it on the override', (
      tester,
    ) async {
      final repo = seeded();
      await _mount(tester, repo, eventId: 'r', at: at);
      await _typeTitle(tester, 'Run');
      await _save(tester);
      await tester.tap(find.text('This occurrence'));
      await tester.pumpAndSettle();
      final e = repo.events['r']!;
      expect(e.title, 'Walk');
      final o = e.occurrences.single;
      expect(o.originalStart, const FloatingTime(2030, 1, 15, 19, 0));
      expect(o.extraFields['title'], 'Run');
      expect(e.notes, 'keep me');
      expect(e.reminders, const [Reminder(minutesBefore: 15)]);
    });

    testWidgets('This occurrence with a new date writes a moved override', (
      tester,
    ) async {
      final repo = seeded();
      await _mount(tester, repo, eventId: 'r', at: at);
      await tester.tap(find.byKey(const Key('calendar-edit-start-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('16'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _save(tester);
      await tester.tap(find.text('This occurrence'));
      await tester.pumpAndSettle();
      final e = repo.events['r']!;
      expect(e.start, const FloatingTime(2030, 1, 13, 19, 0));
      final o = e.occurrences.single;
      expect(o.status, OccurrenceStatus.moved);
      expect(o.originalStart, const FloatingTime(2030, 1, 15, 19, 0));
      expect(o.movedTo, const FloatingTime(2030, 1, 16, 19, 0));
      expect(o.extraFields.containsKey('title'), isFalse);
    });

    testWidgets('All occurrences from an occurrence with its own title '
        'keeps the series title', (tester) async {
      final repo = seeded();
      repo.events['r'] = repo.events['r']!.copyWith(
        occurrences: const [
          OccurrenceOverride(
            originalStart: FloatingTime(2030, 1, 15, 19, 0),
            status: OccurrenceStatus.moved,
            movedTo: FloatingTime(2030, 1, 15, 19, 0),
            extraFields: {'title': 'Special'},
          ),
        ],
      );
      await _mount(tester, repo, eventId: 'r', at: at);
      expect(find.text('Special'), findsOneWidget);
      await tester.tap(find.text('Daily'));
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await _save(tester);
      final e = repo.events['r']!;
      expect(e.title, 'Walk');
      expect(e.rrule, 'FREQ=WEEKLY;BYDAY=TU');
    });

    testWidgets('All occurrences updates the series', (tester) async {
      final repo = seeded();
      await _mount(tester, repo, eventId: 'r', at: at);
      await _typeTitle(tester, 'Run');
      await _save(tester);
      await tester.tap(find.text('All occurrences'));
      await tester.pumpAndSettle();
      final e = repo.events['r']!;
      expect(e.title, 'Run');
      expect(e.occurrences, isEmpty);
      // The series keeps its own first day, not the occurrence opened.
      expect(e.start, const FloatingTime(2030, 1, 13, 19, 0));
      expect(e.end, const FloatingTime(2030, 1, 13, 20, 0));
      expect(e.rrule, 'FREQ=DAILY');
    });
  });

  testWidgets('iOS: segmented repeat control and an action-sheet scope', (
    tester,
  ) async {
    final repo = FakeCalendarRepository()
      ..seed(
        _ev(
          'r',
          const FloatingTime(2030, 1, 13, 19, 0),
          end: const FloatingTime(2030, 1, 13, 20, 0),
          rrule: 'FREQ=DAILY',
        ),
      );
    await _mount(
      tester,
      repo,
      eventId: 'r',
      at: 'floating:2030-01-15T19:00',
      platform: TargetPlatform.iOS,
    );
    expect(
      find.byType(CupertinoSlidingSegmentedControl<RepeatFreq>),
      findsOneWidget,
    );
    expect(find.byType(ChoiceChip), findsNothing);
    await _typeTitle(tester, 'Run');
    await _save(tester);
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('This occurrence'));
    await tester.pumpAndSettle();
    expect(repo.events['r']!.occurrences.single.extraFields['title'], 'Run');
  });

  testWidgets('a deleted event shows not found, not a blank form', (
    tester,
  ) async {
    await _mount(tester, FakeCalendarRepository(), eventId: 'gone');
    expect(find.text('This event no longer exists.'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('cloud API mode shows the friendly message', (tester) async {
    await _mount(tester, FakeCalendarRepository(), mode: DataMode.cloudApi);
    expect(
      find.textContaining('available in Local and Cloud storage'),
      findsOneWidget,
    );
  });

  test('help for the editor resolves in en and zh', () {
    for (final code in ['en', 'zh']) {
      final h = helpFor(
        HelpId.calendarEventEdit,
        lookupAppLocalizations(Locale(code)),
      );
      expect(h.title, isNotEmpty);
      expect(h.entries, isNotEmpty);
    }
  });
}
