import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/data/holiday_cache.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';
import 'package:hmm_console/features/calendar/presentation/screens/calendar_home_screen.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/calendar_view_state.dart';
import 'package:hmm_console/features/calendar/states/holiday_providers.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:hmm_console/features/launcher/domain/launcher_registry.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_calendar_repository.dart';

/// In-memory holiday cache: no files, no path_provider.
class _FakeHolidayCache extends HolidayCache {
  _FakeHolidayCache(this.days) : super(() => throw UnimplementedError());
  final List<HolidayDay> days;
  int reads = 0;
  @override
  Future<List<HolidayDay>> daysFor(Set<String> sourceIds, Set<int> years) {
    reads++;
    return Future.value([
      for (final d in days)
        if (sourceIds.contains(d.sourceId) && years.contains(d.date.year)) d,
    ]);
  }
}

/// Never touches the network; nothing is ever due.
class _NoopRefresher extends HolidayRefresher {
  _NoopRefresher(HolidayCache cache)
    : super(cache, (_) => throw UnimplementedError(), DateTime.now);
  int calls = 0;
  @override
  Future<bool> refresh(List<HolidayRegion> regions, Set<int> years) {
    calls++;
    return Future.value(false);
  }
}

HolidayDay _hol(String src, DateTime d, String name, {bool off = true}) =>
    HolidayDay(date: d, name: name, offDay: off, sourceId: src);

class _Mode extends DataModeNotifier {
  _Mode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

CalendarEvent _ev(
  String id,
  EventTime start, {
  String? rrule,
  List<OccurrenceOverride> occ = const [],
}) => CalendarEvent(
  id: id,
  title: 'Title $id',
  start: start,
  rrule: rrule,
  occurrences: occ,
  updatedAt: DateTime.utc(2020),
);

final _day = DateTime(2026, 11, 18);

Future<ProviderContainer> _mount(
  WidgetTester tester,
  FakeCalendarRepository repo, {
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.android,
  DataMode mode = DataMode.local,
  Locale locale = const Locale('en'),
  DateTime? day,
  _FakeHolidayCache? holidays,
  bool withRouter = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cache = holidays ?? _FakeHolidayCache(const []);
  final container = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _Mode(mode)),
      localCalendarRepositoryProvider.overrideWithValue(repo),
      holidayCacheProvider.overrideWithValue(cache),
      holidayRefresherProvider.overrideWithValue(_NoopRefresher(cache)),
    ],
  );
  addTearDown(container.dispose);
  container.read(selectedDayProvider.notifier).select(day ?? _day);
  final theme = ThemeData(platform: platform);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: withRouter
          ? MaterialApp.router(
              theme: theme,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const CalendarHomeScreen(),
                  ),
                  // Stub (R-1): the real Holidays screen arrives in Task 6.
                  GoRoute(
                    path: '/calendar/holidays',
                    builder: (_, _) =>
                        const Scaffold(body: Text('holidays-stub')),
                  ),
                ],
              ),
            )
          : MaterialApp(
              theme: theme,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CalendarHomeScreen(),
            ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeCalendarRepository seeded() => FakeCalendarRepository()
    ..seed(_ev('a', const FloatingTime(2026, 11, 18, 7, 0)))
    ..seed(_ev('b', const FloatingTime(2026, 11, 18, 19, 0)));

  group('lunar labels', () {
    String lunar(WidgetTester t, int d) =>
        (t.widget(find.byKey(Key('calendar-lunar-$d'))) as Text).data!;

    testWidgets('off: no lunar labels', (tester) async {
      await _mount(tester, seeded());
      expect(find.byKey(const Key('calendar-lunar-17')), findsNothing);
    });

    testWidgets('on: Feb 2026 festivals and plain days', (tester) async {
      SharedPreferences.setMockInitialValues({'calendar.show_lunar': true});
      await _mount(tester, seeded(), day: DateTime(2026, 2, 17));
      expect(lunar(tester, 17), '春节');
      expect(lunar(tester, 16), '除夕');
      // 2/18 is 雨水: a solar term outranks the plain day name.
      expect(lunar(tester, 18), '雨水');
      expect(lunar(tester, 19), '初三');
    });

    testWidgets('on: Apr 2026 solar term', (tester) async {
      SharedPreferences.setMockInitialValues({'calendar.show_lunar': true});
      await _mount(tester, seeded(), day: DateTime(2026, 4, 5));
      expect(lunar(tester, 5), '清明');
    });

    testWidgets('on: agenda header carries the full lunar text', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'calendar.show_lunar': true});
      await _mount(tester, seeded(), day: DateTime(2024, 2, 10));
      expect(find.textContaining('甲辰年正月初一 · 春节'), findsOneWidget);
    });

    testWidgets('on: 6-row month does not overflow on a phone', (tester) async {
      SharedPreferences.setMockInitialValues({'calendar.show_lunar': true});
      await _mount(
        tester,
        seeded(),
        size: const Size(360, 640),
        day: DateTime(2026, 8, 15),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('on: large text does not clip the label; 6-row month still '
        'fits a phone', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({'calendar.show_lunar': true});
      await _mount(
        tester,
        seeded(),
        size: const Size(360, 640),
        day: DateTime(2026, 8, 15),
      );
      expect(tester.takeException(), isNull);
      for (final d in [1, 15, 31]) {
        final p = tester.renderObject<RenderParagraph>(
          find.byKey(Key('calendar-lunar-$d')),
        );
        expect(
          p.getMaxIntrinsicHeight(double.infinity),
          lessThanOrEqualTo(p.size.height),
          reason: 'label of day $d is cut',
        );
      }
    });

    testWidgets('off: large text leaves the 44 pt row unchanged', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _mount(tester, seeded(), size: const Size(360, 640));
      expect(
        tester.getSize(find.byKey(const Key('calendar-day-18'))).height,
        44,
      );
    });
  });

  testWidgets('phone: month grid sits above the agenda', (tester) async {
    await _mount(tester, seeded());
    final grid = tester.getRect(find.byKey(const Key('calendar-month-grid')));
    final agenda = tester.getRect(find.byKey(const Key('calendar-agenda')));
    expect(grid.bottom, lessThanOrEqualTo(agenda.top));
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('wide: grid and agenda are side by side', (tester) async {
    await _mount(tester, seeded(), size: const Size(1200, 800));
    final grid = tester.getRect(find.byKey(const Key('calendar-month-grid')));
    final agenda = tester.getRect(find.byKey(const Key('calendar-agenda')));
    expect(grid.right, lessThanOrEqualTo(agenda.left));
  });

  testWidgets('swipe right marks done; undo restores the snapshot', (
    tester,
  ) async {
    final repo = seeded();
    await _mount(tester, repo);
    await tester.fling(find.text('Title a'), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(repo.log, contains('occ:a:done'));
    expect(find.text('Marked done'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.log.last, 'save:a');
    expect(repo.events['a']!.occurrences, isEmpty);
    expect(find.text('Done mark removed'), findsOneWidget);
  });

  testWidgets('swipe left marks skipped', (tester) async {
    final repo = seeded();
    await _mount(tester, repo);
    await tester.fling(find.text('Title a'), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(repo.log, contains('occ:a:skipped'));
    expect(find.text('Skipped'), findsWidgets);
  });

  testWidgets('long press offers Edit, Delete this one, Delete series', (
    tester,
  ) async {
    final repo = seeded();
    await _mount(tester, repo);
    await tester.longPress(find.text('Title a'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete this one'), findsOneWidget);
    expect(find.text('Delete series'), findsOneWidget);
    await tester.tap(find.text('Delete series'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('delete:a'));
    expect(find.text('Event deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.events.containsKey('a'), isTrue);
  });

  testWidgets('delete this one cancels the occurrence with undo', (
    tester,
  ) async {
    final repo = seeded();
    await _mount(tester, repo);
    await tester.longPress(find.text('Title a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete this one'));
    await tester.pumpAndSettle();
    expect(repo.log, contains('occ:a:cancelled'));
    expect(find.text('Occurrence deleted'), findsOneWidget);
    expect(find.text('Title a'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('cloud API shows the friendly message, not an error', (
    tester,
  ) async {
    await _mount(tester, seeded(), mode: DataMode.cloudApi);
    expect(
      find.textContaining('available in Local and Cloud storage'),
      findsOneWidget,
    );
    expect(find.text('Could not load the calendar.'), findsNothing);
  });

  testWidgets('an empty day says so; it is not an error', (tester) async {
    await _mount(tester, FakeCalendarRepository());
    expect(find.text('Nothing planned for this day.'), findsOneWidget);
    expect(find.text('Could not load the calendar.'), findsNothing);
  });

  testWidgets('an unreadable event does not hide the others', (tester) async {
    final repo = FakeCalendarRepository(unreadable: ['bad'])
      ..seed(_ev('a', const FloatingTime(2026, 11, 18, 7, 0)));
    await _mount(tester, repo);
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('An event could not be read'), findsOneWidget);
  });

  testWidgets('help button present; HelpId.calendar resolves in en and zh', (
    tester,
  ) async {
    await _mount(tester, seeded());
    expect(find.byTooltip('Help'), findsOneWidget);
    for (final code in ['en', 'zh']) {
      final h = helpFor(HelpId.calendar, lookupAppLocalizations(Locale(code)));
      expect(h.title, isNotEmpty);
      expect(h.entries, isNotEmpty);
    }
  });

  testWidgets('iOS has + in the top bar and no FAB', (tester) async {
    await _mount(tester, seeded(), platform: TargetPlatform.iOS);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add event'), findsOneWidget);
  });

  testWidgets('Android has a FAB', (tester) async {
    await _mount(tester, seeded());
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('permission banner shows only when denied after asking', (
    tester,
  ) async {
    final c = await _mount(tester, seeded());
    expect(find.textContaining('notification permission'), findsNothing);
    c.read(calendarPermissionDeniedProvider.notifier).set(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('notification permission'), findsOneWidget);
    c.read(calendarPermissionDeniedProvider.notifier).set(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('notification permission'), findsNothing);
  });

  group('holidays', () {
    final oct1 = DateTime(2025, 10, 1);
    List<HolidayDay> nationalDay() => [
      for (var d = 1; d <= 8; d++) _hol('CN', DateTime(2025, 10, d), '国庆节、中秋节'),
      _hol('CN', DateTime(2025, 10, 11), '国庆节、中秋节', off: false),
    ];

    testWidgets('grid: one source shows 休 in its colour', (tester) async {
      await _mount(
        tester,
        FakeCalendarRepository(),
        day: oct1,
        holidays: _FakeHolidayCache(nationalDay()),
      );
      final xiu = find.descendant(
        of: find.byKey(const Key('calendar-holiday-1')),
        matching: find.text('休'),
      );
      expect(xiu, findsOneWidget);
      expect(tester.widget<Text>(xiu).style!.color, kHolidayPalette[0]);
      final ban = find.descendant(
        of: find.byKey(const Key('calendar-holiday-11')),
        matching: find.text('班'),
      );
      expect(ban, findsOneWidget);
      expect(find.byKey(const Key('calendar-holiday-9')), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('calendar-day-1'))).height,
        44,
      );
    });

    testWidgets('grid: two sources show two dots, no text', (tester) async {
      await _mount(
        tester,
        FakeCalendarRepository(),
        day: oct1,
        holidays: _FakeHolidayCache([
          _hol('CN', DateTime(2025, 10, 13), '补班', off: false),
          _hol('CA-ON', DateTime(2025, 10, 13), 'Thanksgiving'),
        ]),
      );
      final mark = find.byKey(const Key('calendar-holiday-13'));
      expect(mark, findsOneWidget);
      expect(
        find.descendant(of: mark, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: mark,
          matching: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'calendar-holiday-dot-',
                ),
          ),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('grid: more than three sources show three dots; a workday '
        'dot is hollow', (tester) async {
      SharedPreferences.setMockInitialValues({
        'calendar.holiday_regions':
            '[{"country":"CN","color":0},'
            '{"country":"CA","region":"CA-ON","color":1},'
            '{"country":"JP","color":2}]',
        'calendar.my_holidays':
            '{"entries":[{"id":"1","name":"Trip","kind":"once",'
            '"start":"2025-10-13","offDay":true}],"hidden":[]}',
      });
      await _mount(
        tester,
        FakeCalendarRepository(),
        day: oct1,
        holidays: _FakeHolidayCache([
          _hol('CN', DateTime(2025, 10, 13), '补班', off: false),
          _hol('CA-ON', DateTime(2025, 10, 13), 'Thanksgiving'),
          _hol('JP', DateTime(2025, 10, 13), 'Sports Day'),
        ]),
      );
      final mark = find.byKey(const Key('calendar-holiday-13'));
      Container dot(int i) => tester.widget<Container>(
        find.descendant(
          of: mark,
          matching: find.byKey(Key('calendar-holiday-dot-$i')),
        ),
      );
      expect(
        find.descendant(
          of: mark,
          matching: find.byKey(const Key('calendar-holiday-dot-3')),
        ),
        findsNothing,
      );
      final cn = dot(0).decoration! as BoxDecoration;
      expect(cn.color, isNull);
      expect(cn.border, isNotNull);
      final ca = dot(1).decoration! as BoxDecoration;
      expect(ca.color, kHolidayPalette[1]);
    });

    testWidgets('grid: no holidays → no calendar-holiday keys, cell height '
        '44 / 56 as before', (tester) async {
      await _mount(tester, FakeCalendarRepository(), day: oct1);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('calendar-holiday'),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const Key('calendar-day-1'))).height,
        44,
      );
    });

    testWidgets('grid: lunar on keeps the 56 pt cell with holidays', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'calendar.show_lunar': true});
      await _mount(
        tester,
        FakeCalendarRepository(),
        day: oct1,
        holidays: _FakeHolidayCache(nationalDay()),
      );
      expect(find.byKey(const Key('calendar-holiday-1')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('calendar-day-1'))).height,
        56,
      );
      expect(
        tester.getSize(find.byKey(const Key('calendar-day-9'))).height,
        56,
      );
    });

    testWidgets('day detail lists 国庆节、中秋节 · Day off (Oct 1 – Oct 8)', (
      tester,
    ) async {
      await _mount(
        tester,
        FakeCalendarRepository(),
        day: DateTime(2025, 10, 3),
        holidays: _FakeHolidayCache(nationalDay()),
      );
      expect(find.text('国庆节、中秋节 · Day off (Oct 1 – Oct 8)'), findsOneWidget);
      expect(find.text(flagEmoji('CN')), findsOneWidget);
    });

    testWidgets('day detail: a day outside the shown year still lists', (
      tester,
    ) async {
      final c = await _mount(
        tester,
        FakeCalendarRepository(),
        day: DateTime(2024, 12, 31),
        holidays: _FakeHolidayCache([
          _hol('CA-ON', DateTime(2024, 12, 31), 'Old Year'),
        ]),
      );
      expect(find.text('Old Year · Day off'), findsOneWidget);
      // Show January 2025: the agenda keeps Dec 31, 2024.
      c.read(visibleMonthProvider.notifier).shift(1);
      await tester.pumpAndSettle();
      expect(find.text('Old Year · Day off'), findsOneWidget);
    });

    testWidgets('day detail: single-day workday, no range', (tester) async {
      await _mount(
        tester,
        FakeCalendarRepository(),
        day: DateTime(2025, 10, 11),
        holidays: _FakeHolidayCache(nationalDay()),
      );
      expect(find.text('国庆节、中秋节 · Workday'), findsOneWidget);
    });

    testWidgets('day detail: my holiday shows a person icon', (tester) async {
      SharedPreferences.setMockInitialValues({
        'calendar.my_holidays':
            '{"entries":[{"id":"1","name":"Trip","kind":"once",'
            '"start":"2025-10-20","offDay":true}],"hidden":[]}',
      });
      await _mount(
        tester,
        FakeCalendarRepository(),
        day: DateTime(2025, 10, 20),
      );
      expect(find.text('Trip · Day off'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      // My holidays are not hidden from here: tapping offers nothing.
      await tester.tap(find.text('Trip · Day off'));
      await tester.pumpAndSettle();
      expect(find.text('Not a day off for me'), findsNothing);
    });

    testWidgets('Hide removes the line; Undo brings it back', (tester) async {
      await _mount(
        tester,
        FakeCalendarRepository(),
        day: DateTime(2025, 10, 3),
        holidays: _FakeHolidayCache(nationalDay()),
      );
      const line = '国庆节、中秋节 · Day off (Oct 1 – Oct 8)';
      await tester.tap(find.text(line));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not a day off for me'));
      await tester.pumpAndSettle();
      expect(find.text(line), findsNothing);
      expect(find.byKey(const Key('calendar-holiday-1')), findsNothing);
      // The 班 day of the same holiday goes too.
      expect(find.byKey(const Key('calendar-holiday-11')), findsNothing);
      expect(find.text('国庆节、中秋节 hidden'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text(line), findsOneWidget);
      expect(find.text('国庆节、中秋节 shown again'), findsOneWidget);
    });

    testWidgets('Hide on iOS uses an action sheet', (tester) async {
      await _mount(
        tester,
        FakeCalendarRepository(),
        platform: TargetPlatform.iOS,
        day: DateTime(2025, 10, 3),
        holidays: _FakeHolidayCache(nationalDay()),
      );
      await tester.tap(find.text('国庆节、中秋节 · Day off (Oct 1 – Oct 8)'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Not a day off for me'), findsOneWidget);
    });

    testWidgets('Holidays button with tooltip opens /calendar/holidays', (
      tester,
    ) async {
      await _mount(tester, seeded(), withRouter: true);
      expect(find.byTooltip('Holidays'), findsOneWidget);
      await tester.tap(find.byTooltip('Holidays'));
      await tester.pumpAndSettle();
      expect(find.text('holidays-stub'), findsOneWidget);
    });

    testWidgets('Cloud API mode: no Holidays button', (tester) async {
      final cache = _FakeHolidayCache(nationalDay());
      await _mount(tester, seeded(), mode: DataMode.cloudApi, holidays: cache);
      expect(find.byTooltip('Holidays'), findsNothing);
      expect(cache.reads, 0);
    });
  });

  test('the launcher registry contains calendar', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final ids = launcherDestinations(l).map((d) => d.id);
    expect(ids, contains('calendar'));
  });
}
