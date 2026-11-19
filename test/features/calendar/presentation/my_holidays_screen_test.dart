import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/navigation/calendar_routes.dart';
import 'package:hmm_console/features/calendar/data/holiday_cache.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';
import 'package:hmm_console/features/calendar/presentation/screens/holidays_screen.dart';
import 'package:hmm_console/features/calendar/presentation/screens/my_holidays_screen.dart';
import 'package:hmm_console/features/calendar/states/holiday_providers.dart';
import 'package:hmm_console/features/calendar/states/holiday_settings_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCache extends HolidayCache {
  _FakeCache() : super(() => throw UnimplementedError());
  @override
  Future<CachedYear?> read(String sourceId, int year) async => null;
  @override
  Future<List<({String code, String name})>> readCountries() async => const [];
}

class _Refresher extends HolidayRefresher {
  _Refresher(HolidayCache cache)
    : super(cache, (_) => throw UnimplementedError(), DateTime.now);
  @override
  Future<bool> refresh(List<HolidayRegion> regions, Set<int> years) =>
      Future.value(false);
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  MyHolidaysData seed = MyHolidaysData.empty,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cache = _FakeCache();
  final container = ProviderContainer(
    overrides: [
      holidayCacheProvider.overrideWithValue(cache),
      holidayRefresherProvider.overrideWithValue(_Refresher(cache)),
    ],
  );
  addTearDown(container.dispose);
  container.read(myHolidaysProvider);
  await container.read(myHolidaysProvider.notifier).restore(seed);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MyHolidaysScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

MyHoliday _yearly() => MyHoliday(
  id: 'y1',
  name: 'Anniversary',
  kind: MyHolidayKind.yearly,
  start: DateTime(2020, 5, 6),
  offDay: false,
);

Future<void> _tapDate(WidgetTester tester, Key key, int day) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

class _FailingNotifier extends MyHolidaysNotifier {
  @override
  Future<void> upsert(MyHoliday holiday) => Future.error(StateError('x'));
}

void main() {
  testWidgets('a failed save shows a message and keeps the page open', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [myHolidaysProvider.overrideWith(_FailingNotifier.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyHolidaysScreen(),
        ),
      ),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('my-holiday-name')), 'Trip');
    await tester.pump();
    await tester.tap(find.byKey(const Key('my-holiday-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("Couldn't save the holiday"), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('my-holiday-name')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('my-holiday-save')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('add a one-time range; the index has it on each day', (
    tester,
  ) async {
    final c = await _mount(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('my-holiday-name')),
      '  Trip  ',
    );
    await _tapDate(tester, const Key('my-holiday-start'), 10);
    await _tapDate(tester, const Key('my-holiday-end'), 12);
    await tester.tap(find.byKey(const Key('my-holiday-save')));
    await tester.pumpAndSettle();

    final entries = c.read(myHolidaysProvider).entries;
    expect(entries, hasLength(1));
    final e = entries.single;
    expect(e.name, 'Trip');
    expect(e.id, isNotEmpty);
    expect(e.offDay, isTrue);
    expect(e.end!.day, 12);
    expect(find.text('Trip'), findsOneWidget);

    final month = DateTime(e.start.year, e.start.month);
    final index = await c.read(holidaysForMonthProvider(month).future);
    for (final d in [10, 11, 12]) {
      final on = index.on(DateTime(month.year, month.month, d));
      expect(on.map((x) => x.name), ['Trip'], reason: 'day $d');
    }
    expect(index.on(DateTime(month.year, month.month, 13)), isEmpty);
  });

  testWidgets('end before start disables Save', (tester) async {
    await _mount(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('my-holiday-name')), 'Trip');
    await _tapDate(tester, const Key('my-holiday-start'), 20);
    TextButton save() =>
        tester.widget<TextButton>(find.byKey(const Key('my-holiday-save')));
    expect(save().onPressed, isNotNull);
    await _tapDate(tester, const Key('my-holiday-end'), 5);
    expect(save().onPressed, isNull);
  });

  testWidgets('empty name disables Save', (tester) async {
    await _mount(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('my-holiday-name')), '   ');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('my-holiday-save')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('edit a yearly entry keeps its id', (tester) async {
    final c = await _mount(
      tester,
      seed: MyHolidaysData(entries: [_yearly()], hidden: const []),
    );
    expect(find.textContaining('Every year'), findsOneWidget);
    expect(find.textContaining('Workday'), findsOneWidget);
    await tester.tap(find.text('Anniversary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('my-holiday-name')),
      'Anniversary 2',
    );
    await tester.tap(find.byKey(const Key('my-holiday-dayoff')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my-holiday-save')));
    await tester.pumpAndSettle();
    final entries = c.read(myHolidaysProvider).entries;
    expect(entries, hasLength(1));
    expect(entries.single.id, 'y1');
    expect(entries.single.name, 'Anniversary 2');
    expect(entries.single.kind, MyHolidayKind.yearly);
    expect(entries.single.offDay, isTrue);
  });

  testWidgets('swipe delete with undo', (tester) async {
    final c = await _mount(
      tester,
      seed: MyHolidaysData(entries: [_yearly()], hidden: const []),
    );
    await tester.drag(
      find.byKey(const Key('my-holiday-y1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(c.read(myHolidaysProvider).entries, isEmpty);
    expect(find.text('Anniversary deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.read(myHolidaysProvider).entries.map((e) => e.id), ['y1']);
    expect(find.text('Anniversary'), findsOneWidget);
  });

  testWidgets('hidden section lists a hidden holiday; Show again removes it', (
    tester,
  ) async {
    final c = await _mount(
      tester,
      seed: const MyHolidaysData(
        entries: [],
        hidden: [HiddenHoliday(source: 'CA-ON', name: 'Family Day')],
      ),
    );
    expect(find.text('Hidden holidays'), findsOneWidget);
    expect(find.text('${flagEmoji('CA')}  Family Day'), findsOneWidget);
    await tester.tap(find.text('Show again'));
    await tester.pumpAndSettle();
    expect(c.read(myHolidaysProvider).hidden, isEmpty);
    expect(find.text('Hidden holidays'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.read(myHolidaysProvider).hidden, hasLength(1));
  });

  testWidgets('hidden section is absent when nothing is hidden', (
    tester,
  ) async {
    await _mount(tester);
    expect(find.text('Hidden holidays'), findsNothing);
  });

  testWidgets('iOS has a top-bar add button and no FAB', (tester) async {
    await _mount(tester, platform: TargetPlatform.iOS);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add holiday'), findsOneWidget);
  });

  testWidgets('tapping My holidays on the Holidays screen opens it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cache = _FakeCache();
    final container = ProviderContainer(
      overrides: [
        holidayCacheProvider.overrideWithValue(cache),
        holidayRefresherProvider.overrideWithValue(_Refresher(cache)),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/calendar/holidays',
      routes: calendarRoutes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HolidaysScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('holiday-mine')));
    await tester.pumpAndSettle();
    expect(find.byType(MyHolidaysScreen), findsOneWidget);
  });
}
