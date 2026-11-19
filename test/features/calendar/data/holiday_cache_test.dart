import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/data/holiday_cache.dart';
import 'package:hmm_console/features/calendar/data/holiday_sources.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';

class FakeSource implements HolidaySource {
  FakeSource(this.sourceId, this.result);
  @override
  final String sourceId;
  HolidayFetch result;
  int calls = 0;
  @override
  Future<HolidayFetch> fetchYear(int year) async {
    calls++;
    await Future<void>.delayed(Duration.zero);
    return result;
  }
}

CachedYear ok(DateTime at, [List<HolidayDay> days = const []]) =>
    CachedYear(status: CachedStatus.ok, fetchedAt: at, days: days);
CachedYear notPub(DateTime at) =>
    CachedYear(status: CachedStatus.notPublished, fetchedAt: at);

HolidayDay day(String src, DateTime d, String n) =>
    HolidayDay(date: d, name: n, offDay: true, sourceId: src);

void main() {
  late Directory tmp;
  late HolidayCache cache;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('hol');
    cache = HolidayCache(() async => tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  const cn = HolidayRegion(country: 'CN', color: 0);

  test('yearsToFetch', () {
    expect(yearsToFetch(DateTime(2026, 3), DateTime(2026, 10, 31)), {2026});
    expect(yearsToFetch(DateTime(2026, 11), DateTime(2026, 11, 1)), {
      2026,
      2027,
    });
    expect(yearsToFetch(DateTime(2025, 6), DateTime(2026, 12, 5)), {
      2025,
      2027,
    });
  });

  test('needsFetch policy', () {
    final now = DateTime(2026, 11, 19);
    expect(needsFetch(null, 2026, now), isTrue);
    expect(needsFetch(ok(DateTime(2020)), 2025, now), isFalse);
    expect(needsFetch(ok(DateTime(2026, 11, 13)), 2026, now), isFalse);
    expect(needsFetch(ok(DateTime(2026, 11, 11)), 2026, now), isTrue);
    expect(needsFetch(notPub(DateTime(2026, 11, 18, 23)), 2027, now), isFalse);
    expect(needsFetch(notPub(DateTime(2026, 11, 18)), 2027, now), isTrue);
  });

  test('write/read round trip; corrupt file reads as absent', () async {
    final y = ok(DateTime(2026, 5, 1, 10), [
      day('CN', DateTime(2026, 1, 1), '元旦'),
    ]);
    await cache.write('CN', 2026, y);
    final r = await cache.read('CN', 2026);
    expect(r!.days, y.days);
    expect(r.fetchedAt, y.fetchedAt);
    File('${tmp.path}/holidays/CN_2026.json').writeAsStringSync('{nope');
    expect(await cache.read('CN', 2026), isNull);
    expect(await cache.read('CN', 1999), isNull);
  });

  test('not published, then published after the daily retry', () async {
    final src = FakeSource('CN', const HolidayNotPublished());
    var now = DateTime(2026, 11, 19);
    final r = HolidayRefresher(cache, (_) => src, () => now);
    await r.refresh([cn], {2027});
    expect(await cache.daysFor({'CN'}, {2027}), isEmpty);
    now = DateTime(2026, 11, 20);
    src.result = HolidayYear([day('CN', DateTime(2027), '元旦')]);
    expect(await r.refresh([cn], {2027}), isTrue);
    expect((await cache.daysFor({'CN'}, {2027})).single.name, '元旦');
  });

  test('failure keeps saved data', () async {
    final at = DateTime(2026, 11, 11);
    await cache.write(
      'CN',
      2026,
      ok(at, [day('CN', DateTime(2026, 1, 1), 'x')]),
    );
    final src = FakeSource('CN', const HolidayFetchFailed('boom'));
    final r = HolidayRefresher(cache, (_) => src, () => DateTime(2026, 11, 19));
    expect(await r.refresh([cn], {2026}), isFalse);
    expect(src.calls, 1);
    expect((await cache.daysFor({'CN'}, {2026})).length, 1);
    expect((await cache.read('CN', 2026))!.fetchedAt, at);
  });

  test('prune drops removed sources only', () async {
    final at = DateTime(2026, 11, 18);
    await cache.write('CN', 2026, ok(at));
    await cache.write('CA-ON', 2026, ok(at));
    File(
      '${tmp.path}/holidays/countries.json',
    ).writeAsStringSync(jsonEncode([]));
    final src = FakeSource('CN', const HolidayFetchFailed('x'));
    final r = HolidayRefresher(cache, (_) => src, () => DateTime(2026, 11, 19));
    expect(await r.refresh([cn], {2026}), isTrue);
    expect(await cache.read('CA-ON', 2026), isNull);
    expect(await cache.read('CN', 2026), isNotNull);
    expect(File('${tmp.path}/holidays/countries.json').existsSync(), isTrue);
  });

  test('overlapping refresh fetches once', () async {
    final src = FakeSource('CN', const HolidayYear([]));
    final r = HolidayRefresher(cache, (_) => src, () => DateTime(2026, 11, 19));
    final a = r.refresh([cn], {2026});
    final b = r.refresh([cn], {2026});
    await Future.wait([a, b]);
    expect(src.calls, 1);
  });
}
