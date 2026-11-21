import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/features/calendar/contract/i_reminder_scheduler.dart';
import 'package:hmm_console/features/calendar/contract/dated_note.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/linked_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/lunar.dart';
import 'package:hmm_console/features/calendar/domain/recurrence_rule.dart';
import 'package:hmm_console/features/calendar/notifications/local_reminder_scheduler.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_plan.dart';
import 'package:hmm_console/features/calendar/notifications/reminder_sync.dart';
import 'package:hmm_console/features/calendar/presentation/screens/event_edit_screen.dart';
import 'package:hmm_console/features/calendar/presentation/widgets/repeat_picker.dart';
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

/// Counts the runs the editor asks for.
class _SpySync extends ReminderSync {
  _SpySync()
    : super(
        repository: () => throw StateError('unused'),
        scheduler: _Scheduler(),
        permissionGranted: () async => true,
        remindOnDevice: () => false,
        permissionAsked: () async => true,
        askPermissionOnce: () async => null,
        onPermissionChecked: (_) {},
        observeLifecycle: false,
      );

  int triggers = 0;

  @override
  void trigger() => triggers++;
}

late _SpySync _spy;

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
          reminderSyncProvider.overrideWithValue(_spy = _SpySync()),
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
  bool timeSensitive = false,
}) => CalendarEvent(
  id: id,
  timeSensitive: timeSensitive,
  title: title,
  start: start,
  end: end,
  rrule: rrule,
  reminders: reminders,
  notes: 'keep me',
  updatedAt: DateTime.utc(2020),
);

CalendarEvent _linkedEv() => CalendarEvent(
  id: 'l',
  title: 'stored title',
  start: const AllDay(2030, 3, 5),
  rrule: 'RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD',
  owner: const EventOwner(subsystem: 'contacts', noteUuid: 'c1'),
  source: EventSource.subsystem,
  extraFields: {
    'linked': linkedToJson(LinkedKind.birthday, {'name': 'Ann'}),
  },
  reminders: const [Reminder(minutesBefore: 0)],
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
    // R-18: the answer is acted on at once (a grant schedules now).
    expect(_spy.triggers, 1);

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

    testWidgets('changing only the end of an occurrence changes the series '
        'length (no scope dialog, nothing lost)', (tester) async {
      final repo = seeded();
      await _mount(tester, repo, eventId: 'r', at: at);
      await tester.tap(find.byKey(const Key('calendar-edit-end-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('16'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _save(tester);
      expect(find.text('This occurrence'), findsNothing);
      final e = repo.events['r']!;
      expect(repo.log, ['save:r']);
      expect(e.occurrences, isEmpty);
      expect(e.start, const FloatingTime(2030, 1, 13, 19, 0));
      // One day plus one hour long now.
      expect(e.end, const FloatingTime(2030, 1, 14, 20, 0));
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

  group('Time Sensitive switch', () {
    const sw = Key('calendar-edit-time-sensitive');

    testWidgets('a new event saves timeSensitive false', (tester) async {
      final repo = FakeCalendarRepository();
      await _mount(tester, repo);
      expect(find.text('Time Sensitive'), findsOneWidget);
      expect(find.text('Breaks through Focus'), findsOneWidget);
      await _typeTitle(tester, 'Plain');
      await _save(tester);
      expect(repo.events.values.single.timeSensitive, isFalse);
    });

    testWidgets('toggling it on saves true', (tester) async {
      final repo = FakeCalendarRepository();
      await _mount(tester, repo);
      await _typeTitle(tester, 'Urgent');
      await tester.tap(find.byKey(sw));
      await tester.pump();
      await _save(tester);
      expect(repo.events.values.single.timeSensitive, isTrue);
    });

    testWidgets('editing a Time Sensitive event shows the switch on', (
      tester,
    ) async {
      final repo = FakeCalendarRepository()
        ..seed(_ev('t', _fixed(2030, 1, 15, 9), timeSensitive: true));
      await _mount(tester, repo, eventId: 't');
      expect(tester.widget<SwitchListTile>(find.byKey(sw)).value, isTrue);
    });

    testWidgets('disabled when there is no device reminder', (tester) async {
      final repo = FakeCalendarRepository();
      await _mount(tester, repo);
      expect(
        tester.widget<SwitchListTile>(find.byKey(sw)).onChanged,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Remove reminder'));
      await tester.pumpAndSettle();
      expect(find.byKey(sw), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(sw)).onChanged, isNull);
    });

    testWidgets('on, then the last device reminder removed: saves false', (
      tester,
    ) async {
      final repo = FakeCalendarRepository();
      await _mount(tester, repo);
      await _typeTitle(tester, 'No reminder');
      await tester.tap(find.byKey(sw));
      await tester.pump();
      await tester.tap(find.byTooltip('Remove reminder'));
      await tester.pumpAndSettle();
      await _save(tester);
      final e = repo.events.values.single;
      expect(e.reminders, isEmpty);
      expect(e.timeSensitive, isFalse);
    });

    testWidgets('changing only the switch on a repeating event saves to the '
        'series without the scope dialog', (tester) async {
      final repo = FakeCalendarRepository()
        ..seed(
          _ev(
            'r',
            const FloatingTime(2030, 1, 13, 19, 0),
            end: const FloatingTime(2030, 1, 13, 20, 0),
            rrule: 'FREQ=DAILY',
          ),
        );
      await _mount(tester, repo, eventId: 'r', at: 'floating:2030-01-15T19:00');
      await tester.tap(find.byKey(sw));
      await tester.pump();
      await _save(tester);
      expect(find.text('This occurrence'), findsNothing);
      expect(repo.log, ['save:r']);
      final e = repo.events['r']!;
      expect(e.timeSensitive, isTrue);
      expect(e.occurrences, isEmpty);
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

  group('lunar yearly repeat', () {
    CalendarEvent lunarEv(EventTime start, String rule) => CalendarEvent(
      id: 'l',
      title: 'Lunar',
      start: start,
      rrule: rule,
      updatedAt: DateTime.utc(2020),
    );

    Future<ValueNotifier<EventForm>> pumpPicker(
      WidgetTester tester,
      EventForm initial,
    ) async {
      final form = ValueNotifier(initial);
      addTearDown(form.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<EventForm>(
              valueListenable: form,
              builder: (_, f, _) =>
                  RepeatPicker(form: f, onChanged: (n) => form.value = n),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return form;
    }

    testWidgets('yearly shows date and lunar-date choices; lunar builds the '
        'lunar rule', (tester) async {
      final d = DateTime(2025, 11, 18, 9);
      final form = await pumpPicker(
        tester,
        EventForm(
          title: 'B',
          start: d,
          end: d.add(const Duration(hours: 1)),
          freq: RepeatFreq.yearly,
        ),
      );
      final lunar = toLunar(d)!;
      final text = lunarMonthDayText(
        lunar.month,
        lunar.day,
        leap: lunar.isLeap,
      );
      expect(
        find.byKey(const Key('calendar-repeat-calendar-false')),
        findsOneWidget,
      );
      expect(find.text('On Nov 18'), findsOneWidget);
      expect(find.text('On 农历$text'), findsOneWidget);
      expect(form.value.rrule, 'FREQ=YEARLY');

      await tester.tap(find.byKey(const Key('calendar-repeat-calendar-true')));
      await tester.pumpAndSettle();
      expect(form.value.lunar, isTrue);
      expect(
        form.value.rrule,
        RecurrenceRule.lunarYearly(
          month: lunar.month,
          day: lunar.day,
          leap: lunar.isLeap,
        ).format(),
      );
      expect(
        describeRuleText(
          form.value.rrule!,
          lookupAppLocalizations(const Locale('en')),
        ),
        'Every year on 农历$text',
      );
    });

    testWidgets('a start outside the lunar range shows no calendar choice', (
      tester,
    ) async {
      final d = DateTime(2150, 3, 1, 9);
      final form = await pumpPicker(
        tester,
        EventForm(
          title: 'B',
          start: d,
          end: d.add(const Duration(hours: 1)),
          freq: RepeatFreq.yearly,
          lunar: true,
        ),
      );
      expect(
        find.byKey(const Key('calendar-repeat-calendar-false')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('calendar-repeat-calendar-true')),
        findsNothing,
      );
      expect(form.value.rrule, 'FREQ=YEARLY');
    });

    test('a new start date re-derives the lunar date (Review Focus 4)', () {
      final d = DateTime(2025, 11, 18, 9);
      final form = EventForm(
        title: 'B',
        start: d,
        end: d.add(const Duration(hours: 1)),
        freq: RepeatFreq.yearly,
        lunar: true,
      );
      final moved = form.copyWith(start: DateTime(2026, 2, 17, 9));
      expect(moved.rrule, contains('BYMONTH=1;BYMONTHDAY=1'));
    });

    test('day 30 on a 29-day month keeps day 30 (Review Focus 5)', () {
      const rule =
          'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=30;SKIP=BACKWARD';
      final form = EventForm.fromEvent(
        lunarEv(const AllDay(2025, 1, 28), rule),
      );
      expect(form.customRule, isNull);
      expect(form.freq, RepeatFreq.yearly);
      expect(form.lunar, isTrue);
      expect(form.lunarAnchor!.day, 30);
      expect(form.rrule, contains('BYMONTHDAY=30'));
      // Editing an unrelated field keeps the anchor.
      final retitled = form.copyWith(title: 'New');
      expect(retitled.rrule, contains('BYMONTH=12;BYMONTHDAY=30'));
      final retimed = form.copyWith(start: DateTime(2025, 1, 28, 0));
      expect(retimed.rrule, contains('BYMONTH=12;BYMONTHDAY=30'));
    });

    test('day 30 survives a title-only save (buildEvent)', () {
      const rule =
          'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=30;SKIP=BACKWARD';
      final base = lunarEv(const AllDay(2025, 1, 28), rule);
      final initial = EventForm.fromEvent(base);
      final saved = buildEvent(
        initial.copyWith(title: 'New'),
        base: base,
        initial: initial,
        now: DateTime.utc(2025),
      );
      expect(saved.rrule, contains('BYMONTH=12;BYMONTHDAY=30'));
    });

    test('a supported lunar rule matching its start opens as editable', () {
      final start = DateTime(2026, 5, 21);
      final lunar = toLunar(start)!;
      final rule = RecurrenceRule.lunarYearly(
        month: lunar.month,
        day: lunar.day,
        leap: lunar.isLeap,
        interval: 2,
        count: 3,
      ).format();
      final form = EventForm.fromEvent(
        lunarEv(const AllDay(2026, 5, 21), rule),
      );
      expect(form.customRule, isNull);
      expect(form.freq, RepeatFreq.yearly);
      expect(form.lunar, isTrue);
      expect(form.interval, 2);
      expect(form.repeatEnd, RepeatEnd.afterCount);
      expect(form.count, 3);
      expect(form.rrule, rule);
    });

    const day30 =
        'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=30;SKIP=BACKWARD';

    String savedRule(EventForm f, CalendarEvent base, EventForm initial) =>
        buildEvent(
          f,
          base: base,
          initial: initial,
          now: DateTime.utc(2025),
        ).rrule!;

    String ruleFor(LunarDate d) => RecurrenceRule.lunarYearly(
      month: d.month,
      day: d.day,
      leap: d.isLeap,
    ).format();

    test('a date round trip keeps day 30 (fix round 1)', () {
      final base = lunarEv(const AllDay(2025, 1, 28), day30);
      final initial = EventForm.fromEvent(base);
      final back = initial
          .copyWith(start: DateTime(2025, 2, 3))
          .copyWith(start: DateTime(2025, 1, 28));
      expect(back.rrule, contains('BYMONTH=12;BYMONTHDAY=30'));
      expect(back.lunarDate!.day, 30);
      expect(savedRule(back, base, initial), contains('BYMONTHDAY=30'));
    });

    test('at an occurrence, a date move shifts the series lunar date and the '
        'label equals the saved rule (day-30 fallback)', () {
      final base = lunarEv(const AllDay(2025, 1, 28), day30);
      // Next year's 腊月三十 (falls back to 廿九 when 腊月 is short).
      final occ = fromLunarBackward(2025, 12, 30)!;
      final at = resolveOccurrence(
        base,
        AllDay(occ.year, occ.month, occ.day).wireKey,
      )!;
      final initial = EventForm.fromEvent(base, at: at);
      expect(initial.lunarDate, const LunarDate(2024, 12, 30));
      final moved = initial.copyWith(
        start: DateTime(occ.year, occ.month, occ.day - 1),
      );
      // Series start moves 2025-01-28 → 2025-01-27 (腊月廿八).
      expect(moved.lunarDate, toLunar(DateTime(2025, 1, 27)));
      expect(moved.lunarDate!.day, 28);
      expect(savedRule(moved, base, initial), ruleFor(moved.lunarDate!));
    });

    test('a Gregorian yearly series opened at a later occurrence: the lunar '
        'label is the series start lunar date, which is what is saved', () {
      final base = lunarEv(const AllDay(2020, 11, 18), 'FREQ=YEARLY');
      final at = resolveOccurrence(base, const AllDay(2025, 11, 18).wireKey)!;
      final initial = EventForm.fromEvent(base, at: at);
      final on = initial.copyWith(lunar: true);
      expect(on.lunarDate, toLunar(DateTime(2020, 11, 18)));
      expect(savedRule(on, base, initial), ruleFor(on.lunarDate!));
      final moved = on.copyWith(start: DateTime(2025, 11, 19));
      expect(moved.lunarDate, toLunar(DateTime(2020, 11, 19)));
      expect(savedRule(moved, base, initial), ruleFor(moved.lunarDate!));
    });

    test('moving one occurrence of a lunar series is not a repeat change', () {
      final base = lunarEv(
        const AllDay(2025, 1, 29),
        'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1;SKIP=BACKWARD',
      );
      final at = resolveOccurrence(base, const AllDay(2026, 2, 17).wireKey)!;
      final initial = EventForm.fromEvent(base, at: at);
      final moved = initial.copyWith(start: DateTime(2026, 2, 18));
      expect(moved.repeatChangedFrom(initial), isFalse);
      expect(moved.copyWith(interval: 2).repeatChangedFrom(initial), isTrue);
    });

    testWidgets('a lunar series opened at a later occurrence: the Gregorian '
        'choice names the series start month/day, which is what is saved', (
      tester,
    ) async {
      const rule =
          'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1;SKIP=BACKWARD';
      // 2024-02-10 is 正月初一 2024; the 2026 occurrence is Feb 17.
      final base = lunarEv(const AllDay(2024, 2, 10), rule);
      final at = resolveOccurrence(base, const AllDay(2026, 2, 17).wireKey)!;
      final initial = EventForm.fromEvent(base, at: at);
      expect(initial.start, DateTime(2026, 2, 17));
      final form = await pumpPicker(tester, initial);
      expect(find.text('On Feb 10'), findsOneWidget);
      expect(find.text('On Feb 17'), findsNothing);

      await tester.tap(find.byKey(const Key('calendar-repeat-calendar-false')));
      await tester.pumpAndSettle();
      final saved = buildEvent(
        form.value,
        base: base,
        initial: initial,
        now: DateTime.utc(2026),
      );
      expect(saved.rrule, 'FREQ=YEARLY');
      expect(saved.start, const AllDay(2024, 2, 10));
    });

    testWidgets('a lunar series: a new date at an occurrence offers the scope '
        'dialog and This occurrence keeps the rule', (tester) async {
      const rule =
          'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1;SKIP=BACKWARD';
      final repo = FakeCalendarRepository()
        ..seed(_ev('n', const AllDay(2025, 1, 29), rrule: rule));
      await _mount(tester, repo, eventId: 'n', at: 'allDay:2026-02-17');
      await tester.tap(find.byKey(const Key('calendar-edit-start-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _save(tester);
      expect(find.text('This occurrence'), findsOneWidget);
      await tester.tap(find.text('This occurrence'));
      await tester.pumpAndSettle();
      final e = repo.events['n']!;
      expect(e.rrule, rule);
      expect(e.start, const AllDay(2025, 1, 29));
      final o = e.occurrences.single;
      expect(o.originalStart, const AllDay(2026, 2, 17));
      expect(o.movedTo, const AllDay(2026, 2, 18));
    });

    testWidgets('a lunar rule that does not match its start stays clear-only', (
      tester,
    ) async {
      const text =
          'RSCALE=CHINESE;FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1;SKIP=BACKWARD';
      final form = EventForm.fromEvent(lunarEv(const AllDay(2024, 3, 1), text));
      expect(form.customRule, text);
      expect(form.lunar, isFalse);
      await pumpPicker(tester, form);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Yearly'), findsNothing);
    });
  });

  testWidgets('linked event: title, date and repeat are read-only; reminders '
      'and notes editable; save keeps start and rrule', (tester) async {
    final repo = FakeCalendarRepository()..seed(_linkedEv());
    await _mount(tester, repo, eventId: 'l');
    expect(find.text('Change it in Contacts'), findsOneWidget);
    expect(find.text("Ann's birthday"), findsOneWidget);
    expect(find.byKey(const Key('calendar-edit-title')), findsNothing);

    // The date buttons ignore taps: no picker opens.
    await tester.tap(
      find.byKey(const Key('calendar-edit-start-date')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await tester.enterText(
      find.byKey(const Key('calendar-edit-notes')),
      'new note',
    );
    await tester.tap(find.byTooltip('Remove reminder'));
    await tester.pump();
    await _save(tester);
    final e = repo.events['l']!;
    expect(e.title, 'stored title');
    expect(e.start, const AllDay(2030, 3, 5));
    expect(e.rrule, 'RSCALE=GREGORIAN;FREQ=YEARLY;SKIP=BACKWARD');
    expect(e.notes, 'new note');
    expect(e.reminders, isEmpty);
    expect(e.extraFields['linked'], isNotNull);
    expect(e.owner?.noteUuid, 'c1');
  });

  testWidgets('a hand-made event keeps editable fields', (tester) async {
    final repo = FakeCalendarRepository()
      ..seed(_ev('h', _fixed(2030, 1, 15, 10), end: _fixed(2030, 1, 15, 11)));
    await _mount(tester, repo, eventId: 'h');
    expect(find.text('Change it in Contacts'), findsNothing);
    expect(find.byKey(const Key('calendar-edit-title')), findsOneWidget);
  });

  test('buildEvent on a linked base keeps title, start, end and rrule', () {
    final base = _linkedEv();
    final initial = EventForm.fromEvent(base);
    final edited = initial.copyWith(
      title: 'Hacked',
      start: DateTime(2031, 6, 7),
      end: DateTime(2031, 6, 7),
      notes: 'new notes',
      reminders: const [Reminder(minutesBefore: 60)],
      timeSensitive: false,
    );
    final e = buildEvent(
      edited,
      base: base,
      initial: initial,
      now: DateTime.utc(2030),
    );
    expect(e.title, base.title);
    expect(e.start, base.start);
    expect(e.end, base.end);
    expect(e.rrule, base.rrule);
    expect(e.notes, 'new notes');
    expect(e.reminders, const [Reminder(minutesBefore: 60)]);
    expect(e.extraFields['linked'], base.extraFields['linked']);
    expect(e.owner, base.owner);
  });
}
