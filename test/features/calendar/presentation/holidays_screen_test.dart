import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/data/holiday_cache.dart';
import 'package:hmm_console/features/calendar/data/holiday_sources.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';
import 'package:hmm_console/features/calendar/domain/region_names.dart';
import 'package:hmm_console/features/calendar/presentation/screens/holidays_screen.dart';
import 'package:hmm_console/features/calendar/states/holiday_providers.dart';
import 'package:hmm_console/features/calendar/states/holiday_settings_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fx = 'test/features/calendar/data/fixtures';
String _fixture(String n) => File('$_fx/$n').readAsStringSync();

class _Adapter implements HttpClientAdapter {
  _Adapter();
  bool offline = false;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final s = options.uri.toString();
    requests.add(s);
    String body;
    var status = 200;
    if (offline) {
      body = '';
      status = 500;
    } else if (s.contains('AvailableCountries')) {
      body = _fixture('nager_countries.json');
    } else if (s.contains('PublicHolidays')) {
      body = _fixture('nager_ca_2025.json');
    } else {
      body = _fixture('holiday_cn_2025.json');
    }
    return ResponseBody.fromString(body, status);
  }

  @override
  void close({bool force = false}) {}
}

/// In-memory: no files, no path_provider.
class _FakeCache extends HolidayCache {
  _FakeCache() : super(() => throw UnimplementedError());
  final years = <String, CachedYear>{};
  List<({String code, String name})> countries = const [];

  @override
  Future<CachedYear?> read(String sourceId, int year) async =>
      years['${sourceId}_$year'];

  @override
  Future<List<({String code, String name})>> readCountries() async => countries;

  @override
  Future<void> writeCountries(List<({String code, String name})> list) async {
    countries = list;
  }
}

class _Refresher extends HolidayRefresher {
  _Refresher(HolidayCache cache)
    : super(cache, (_) => throw UnimplementedError(), DateTime.now);
  final calls = <List<HolidayRegion>>[];
  @override
  Future<bool> refresh(List<HolidayRegion> regions, Set<int> years) {
    calls.add(regions);
    return Future.value(false);
  }
}

late _Adapter _adapter;
late _FakeCache _cache;
late _Refresher _refresher;

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _adapter = _Adapter();
  _cache = _FakeCache()
    ..countries = [(code: 'CN', name: 'China'), (code: 'CA', name: 'Canada')];
  _refresher = _Refresher(_cache);
  final container = ProviderContainer(
    overrides: [
      holidayDioProvider.overrideWithValue(
        holidayDio()..httpClientAdapter = _adapter,
      ),
      holidayCacheProvider.overrideWithValue(_cache),
      holidayRefresherProvider.overrideWithValue(_refresher),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HolidaysScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openAddAndSearch(WidgetTester tester, String query) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('holiday-picker-search')), query);
  await tester.pumpAndSettle();
}

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

void main() {
  testWidgets('default list shows China and Canada · Ontario', (tester) async {
    await _mount(tester);
    expect(find.text('${flagEmoji('CN')}  China'), findsOneWidget);
    expect(find.text('${flagEmoji('CA')}  Canada'), findsOneWidget);
    expect(find.textContaining('Whole country'), findsOneWidget);
    expect(find.textContaining('Ontario'), findsOneWidget);
    expect(find.text('My holidays'), findsOneWidget);
    final cn = tester.widget<Container>(
      find.byKey(const Key('holiday-swatch-CN')),
    );
    expect((cn.decoration! as BoxDecoration).color, kHolidayPalette[0]);
  });

  testWidgets('subtitle shows the update date and unpublished next year', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    _cache = _FakeCache();
    _cache.years['CN_${now.year}'] = CachedYear(
      status: CachedStatus.ok,
      fetchedAt: DateTime(now.year, 3, 4),
    );
    _cache.years['CA-ON_${now.year + 1}'] = CachedYear(
      status: CachedStatus.notPublished,
      fetchedAt: now,
    );
    _refresher = _Refresher(_cache);
    _adapter = _Adapter();
    final container = ProviderContainer(
      overrides: [
        holidayDioProvider.overrideWithValue(
          holidayDio()..httpClientAdapter = _adapter,
        ),
        holidayCacheProvider.overrideWithValue(_cache),
        holidayRefresherProvider.overrideWithValue(_refresher),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HolidaysScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Updated Mar 4, ${now.year}'), findsOneWidget);
    expect(
      find.textContaining('${now.year + 1} not published yet'),
      findsOneWidget,
    );
  });

  testWidgets('China shows 中国 in zh', (tester) async {
    await _mount(tester, locale: const Locale('zh'));
    expect(find.text('${flagEmoji('CN')}  中国'), findsOneWidget);
  });

  testWidgets('adding Canada again offers regions without Ontario', (
    tester,
  ) async {
    final c = await _mount(tester);
    await _openAddAndSearch(tester, 'Canada');
    await tester.tap(find.text('${flagEmoji('CA')}  Canada').last);
    await tester.pumpAndSettle();
    expect(_inSheet('Whole country'), findsOneWidget);
    expect(_inSheet('Alberta'), findsOneWidget);
    expect(_inSheet('Ontario'), findsNothing);
    final names = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data)
        .toList();
    expect(
      names.indexOf('Alberta'),
      lessThan(names.indexOf('British Columbia')),
    );

    await tester.tap(_inSheet('Alberta'));
    await tester.pumpAndSettle();
    final regions = c.read(holidayRegionsProvider);
    expect(regions.map((r) => r.sourceId), ['CN', 'CA-ON', 'CA-AB']);
    expect(regions.last.color, 2);
    expect(_refresher.calls, hasLength(1));
  });

  testWidgets('adding the same country/region twice keeps one entry', (
    tester,
  ) async {
    final c = await _mount(tester);
    await _openAddAndSearch(tester, 'Canada');
    await tester.tap(find.text('${flagEmoji('CA')}  Canada').last);
    await tester.pumpAndSettle();
    await tester.tap(_inSheet('Alberta'));
    await tester.pumpAndSettle();

    await _openAddAndSearch(tester, 'Canada');
    await tester.tap(find.text('${flagEmoji('CA')}  Canada').last);
    await tester.pumpAndSettle();
    expect(_inSheet('Alberta'), findsNothing);
    expect(_inSheet('British Columbia'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();
    final notifier = c.read(holidayRegionsProvider.notifier);
    expect(await notifier.add('CA', 'CA-AB'), isFalse);
    expect(
      c.read(holidayRegionsProvider).where((r) => r.sourceId == 'CA-AB'),
      hasLength(1),
    );
  });

  testWidgets('China is added directly without asking Nager for regions', (
    tester,
  ) async {
    final c = await _mount(tester);
    await c.read(holidayRegionsProvider.notifier).remove('CN');
    await tester.pumpAndSettle();
    await _openAddAndSearch(tester, 'China');
    await tester.tap(find.text('${flagEmoji('CN')}  China').last);
    await tester.pumpAndSettle();
    expect(c.read(holidayRegionsProvider).map((r) => r.sourceId), [
      'CA-ON',
      'CN',
    ]);
    expect(
      _adapter.requests.where((u) => u.contains('PublicHolidays')),
      isEmpty,
    );
  });

  testWidgets('offline add shows a message and adds nothing', (tester) async {
    final c = await _mount(tester);
    _adapter.offline = true;
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't load countries. Check your connection."),
      findsOneWidget,
    );
    expect(c.read(holidayRegionsProvider), kDefaultHolidayRegions);
  });

  testWidgets('swipe removes with undo; undo restores order and colour', (
    tester,
  ) async {
    final c = await _mount(tester);
    await tester.drag(
      find.byKey(const Key('holiday-region-CN')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(c.read(holidayRegionsProvider).map((r) => r.sourceId), ['CA-ON']);
    expect(find.text('China removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(c.read(holidayRegionsProvider), kDefaultHolidayRegions);
    expect(find.byKey(const Key('holiday-region-CN')), findsOneWidget);
  });

  testWidgets('iOS has a top-bar add button and no FAB', (tester) async {
    await _mount(tester, platform: TargetPlatform.iOS);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add country'), findsOneWidget);
  });

  testWidgets('help button opens the holidays help', (tester) async {
    await _mount(tester);
    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text('Add a country'), findsOneWidget);
    expect(find.text('Remove a country'), findsOneWidget);
  });

  test('regionName maps Canada and US codes, else the code', () {
    expect(regionName('CA-ON'), 'Ontario');
    expect(regionName('CA-NL'), 'Newfoundland and Labrador');
    expect(regionName('US-DC'), 'District of Columbia');
    expect(regionName('GB-SCT'), 'GB-SCT');
  });

  test('countries.json round-trips and survives pruneExcept', () async {
    final dir = Directory.systemTemp.createTempSync('holiday_cache_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cache = HolidayCache(() async => dir);
    expect(await cache.readCountries(), isEmpty);
    await cache.writeCountries([(code: 'CA', name: 'Canada')]);
    await cache.write(
      'XX',
      2026,
      CachedYear(status: CachedStatus.ok, fetchedAt: DateTime(2026)),
    );
    expect(await cache.pruneExcept({}), isTrue);
    expect(await cache.readCountries(), [(code: 'CA', name: 'Canada')]);
    expect(await cache.read('XX', 2026), isNull);
  });
}
