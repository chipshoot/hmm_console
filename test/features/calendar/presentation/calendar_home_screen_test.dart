import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/help/help_registry.dart';
import 'package:hmm_console/features/calendar/domain/calendar_event.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';
import 'package:hmm_console/features/calendar/presentation/screens/calendar_home_screen.dart';
import 'package:hmm_console/features/calendar/states/calendar_providers.dart';
import 'package:hmm_console/features/calendar/states/calendar_view_state.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:hmm_console/features/launcher/domain/launcher_registry.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_calendar_repository.dart';

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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      dataModeProvider.overrideWith(() => _Mode(mode)),
      localCalendarRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  container.read(selectedDayProvider.notifier).select(_day);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
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
  });

  test('the launcher registry contains calendar', () {
    final l = lookupAppLocalizations(const Locale('en'));
    final ids = launcherDestinations(l).map((d) => d.id);
    expect(ids, contains('calendar'));
  });
}
