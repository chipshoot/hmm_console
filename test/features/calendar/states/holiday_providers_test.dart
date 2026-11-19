import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/data/holiday_cache.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';
import 'package:hmm_console/features/calendar/states/holiday_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

HolidayDay _d(String src, DateTime date, String name, {bool off = true}) =>
    HolidayDay(date: date, name: name, offDay: off, sourceId: src);

/// Completes each refresh when the test says so, running [onRefresh] first.
class _StubRefresher extends HolidayRefresher {
  _StubRefresher(HolidayCache cache)
    : super(cache, (_) => throw UnimplementedError(), DateTime.now);

  final List<Completer<bool>> runs = [];
  Future<void> Function()? onRefresh;

  @override
  Future<bool> refresh(List<HolidayRegion> regions, Set<int> years) {
    final c = Completer<bool>();
    runs.add(c);
    return c.future.then((v) async {
      if (v) await onRefresh?.call();
      return v;
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('holidayMarksFor', () {
    test('marks: one per source, off wins within a source', () {
      final jan1 = DateTime(2025, 1, 1);
      final idx = HolidayIndex(
        downloaded: [
          _d('CN', jan1, '补班', off: false),
          _d('CA-ON', jan1, "New Year's Day"),
          _d('CA-ON', jan1, 'Second', off: false),
        ],
        mine: MyHolidaysData.empty,
        sourceOrder: const ['CN', 'CA-ON'],
      );
      final colors = holidayColors(kDefaultHolidayRegions);
      final cn = kHolidayPalette[0];
      final ca = kHolidayPalette[1];
      final marks = holidayMarksFor(idx, DateTime(2025, 1), colors);
      expect(marks.keys, [1]);
      expect(marks[1], [HolidayMark(cn, false), HolidayMark(ca, true)]);
    });

    test('holidayColors wraps the palette and adds My holidays', () {
      final colors = holidayColors(const [
        HolidayRegion(country: 'JP', color: 7),
      ]);
      expect(colors['JP'], kHolidayPalette[7 % kHolidayPalette.length]);
      expect(colors[kMyHolidaysSourceId], kMyHolidaysColor);
    });

    test('my holidays get their own mark in their colour', () {
      final idx = HolidayIndex(
        downloaded: const [],
        mine: MyHolidaysData(
          entries: [
            MyHoliday(
              id: '1',
              name: 'Trip',
              kind: MyHolidayKind.once,
              start: DateTime(2025, 3, 4),
              offDay: true,
            ),
          ],
          hidden: const [],
        ),
        sourceOrder: const ['CN'],
      );
      final marks = holidayMarksFor(
        idx,
        DateTime(2025, 3),
        holidayColors(const []),
      );
      expect(marks[4], [const HolidayMark(kMyHolidaysColor, true)]);
    });
  });

  group('holidaysForMonthProvider', () {
    late Directory tmp;
    late HolidayCache cache;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tmp = Directory.systemTemp.createTempSync('holprov');
      cache = HolidayCache(() async => tmp);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    CachedYear ok(List<HolidayDay> days) => CachedYear(
      status: CachedStatus.ok,
      fetchedAt: DateTime.now(),
      days: days,
    );

    test('provider returns cached data first, then refreshed data', () async {
      final month = DateTime(2025, 1);
      await cache.write('CN', 2025, ok([_d('CN', DateTime(2025, 1, 1), '元旦')]));
      final refresher = _StubRefresher(cache)
        ..onRefresh = () => cache.write(
          'CN',
          2025,
          ok([
            _d('CN', DateTime(2025, 1, 1), '元旦'),
            _d('CN', DateTime(2025, 1, 26), '补班', off: false),
          ]),
        );
      final c = ProviderContainer(
        overrides: [
          holidayCacheProvider.overrideWithValue(cache),
          holidayRefresherProvider.overrideWithValue(refresher),
        ],
      );
      addTearDown(c.dispose);
      final seen = <int>[];
      c.listen(holidaysForMonthProvider(month), (_, next) {
        final v = next.value;
        if (v != null && !next.isLoading) seen.add(v.forMonth(month).length);
      }, fireImmediately: true);

      final first = await c.read(holidaysForMonthProvider(month).future);
      expect(first.forMonth(month).length, 1);
      expect(refresher.runs, hasLength(1));

      refresher.runs.first.complete(true);
      await pumpEventQueue();
      final second = await c.read(holidaysForMonthProvider(month).future);
      expect(second.forMonth(month).length, 2);
      expect(seen.last, 2);

      // The rebuild refreshes again; nothing due → false → no further rebuild.
      expect(refresher.runs, hasLength(2));
      refresher.runs[1].complete(false);
      await pumpEventQueue();
      expect(refresher.runs, hasLength(2));
    });

    test('hidden holidays are dropped from the index', () async {
      final month = DateTime(2025, 10);
      await cache.write(
        'CN',
        2025,
        ok([_d('CN', DateTime(2025, 10, 1), '国庆节、中秋节')]),
      );
      SharedPreferences.setMockInitialValues({
        'calendar.my_holidays':
            '{"entries":[],"hidden":[{"source":"CN","name":"国庆节、中秋节"}]}',
      });
      final refresher = _StubRefresher(cache);
      final c = ProviderContainer(
        overrides: [
          holidayCacheProvider.overrideWithValue(cache),
          holidayRefresherProvider.overrideWithValue(refresher),
        ],
      );
      addTearDown(c.dispose);
      c.listen(holidaysForMonthProvider(month), (_, _) {});
      await pumpEventQueue();
      final idx = await c.read(holidaysForMonthProvider(month).future);
      expect(idx.forMonth(month), isEmpty);
    });
  });
}
