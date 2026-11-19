import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/data/holiday_sources.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';

const _fx = 'test/features/calendar/data/fixtures';
String _fixture(String n) => File('$_fx/$n').readAsStringSync();

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ({int status, String body}) Function(Uri uri) handler;
  Uri? lastUri;
  Map<String, dynamic> lastHeaders = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastUri = options.uri;
    lastHeaders = Map.of(options.headers);
    final r = handler(options.uri);
    return ResponseBody.fromString(
      r.body,
      r.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_Adapter a) => holidayDio()..httpClientAdapter = a;

({int status, String body}) _fixtures(Uri u) {
  final s = u.toString();
  if (s.contains('nager.at') && s.contains('PublicHolidays')) {
    return (status: 200, body: _fixture('nager_ca_2025.json'));
  }
  if (s.contains('AvailableCountries')) {
    return (status: 200, body: _fixture('nager_countries.json'));
  }
  return (status: 200, body: _fixture('holiday_cn_2025.json'));
}

void main() {
  late _Adapter adapter;
  late Dio dio;
  setUp(() {
    adapter = _Adapter(_fixtures);
    dio = _dioWith(adapter);
  });
  Dio dioServing(String body) =>
      _dioWith(_Adapter((_) => (status: 200, body: body)));
  Dio dioStatus(int s) => _dioWith(_Adapter((_) => (status: s, body: '')));
  Dio dioThrowing() => _dioWith(_Adapter((_) => throw StateError('offline')));

  test('Nager CA 2025 filtered to Ontario', () async {
    final r =
        await NagerSource(dio, country: 'CA', region: 'CA-ON').fetchYear(2025)
            as HolidayYear;
    final names = r.days.map((d) => d.name).toList();
    expect(r.days, hasLength(11));
    expect(
      names,
      containsAll(['Family Day', 'Civic Holiday', 'Boxing Day', 'Canada Day']),
    );
    expect(names, isNot(contains('Louis Riel Day')));
    expect(r.days.every((d) => d.offDay && d.sourceId == 'CA-ON'), isTrue);
    expect(
      r.days.firstWhere((d) => d.name == 'Family Day').date,
      DateTime(2025, 2, 17),
    );
  });

  test('Nager without region keeps global only', () async {
    final r =
        await NagerSource(dio, country: 'CA').fetchYear(2025) as HolidayYear;
    expect(r.days.map((d) => d.name), isNot(contains('Family Day')));
    expect(r.days.first.sourceId, 'CA');
  });

  test('Nager drops non-Public types', () async {
    final body =
        '[{"date":"2025-01-01","localName":"A","name":"A","global":true,"counties":null,"types":["Public"]},'
        '{"date":"2025-02-02","localName":"B","name":"B","global":true,"counties":null,"types":["Observance"]}]';
    final r =
        await NagerSource(dioServing(body), country: 'XX').fetchYear(2025)
            as HolidayYear;
    expect(r.days.single.name, 'A');
  });

  test('holiday-cn 2025 blocks and 补班', () async {
    final r = await HolidayCnSource(dio).fetchYear(2025) as HolidayYear;
    bool? off(DateTime d) =>
        r.days.where((x) => x.date == d).map((x) => x.offDay).firstOrNull;
    expect(off(DateTime(2025, 1, 28)), isTrue);
    expect(off(DateTime(2025, 1, 26)), isFalse);
    expect([4, 5, 6].map((d) => off(DateTime(2025, 4, d))), [true, true, true]);
    expect(
      r.days.firstWhere((x) => x.date == DateTime(2025, 4, 4)).name,
      '清明节',
    );
  });

  test('holiday-cn 404 is not published', () async {
    expect(
      await HolidayCnSource(dioStatus(404)).fetchYear(2027),
      isA<HolidayNotPublished>(),
    );
  });

  test('malformed JSON or network error is a failure', () async {
    expect(
      await HolidayCnSource(dioServing('{"days": 5}')).fetchYear(2025),
      isA<HolidayFetchFailed>(),
    );
    expect(
      await NagerSource(
        dioServing('[{"localName":"x"}]'),
        country: 'CA',
      ).fetchYear(2025),
      isA<HolidayFetchFailed>(),
    );
    expect(
      await NagerSource(dioStatus(500), country: 'CA').fetchYear(2025),
      isA<HolidayFetchFailed>(),
    );
    expect(
      await NagerSource(dioThrowing(), country: 'CA').fetchYear(2025),
      isA<HolidayFetchFailed>(),
    );
  });

  test('bad or missing dates fail with a date reason', () async {
    Future<void> expectBadDate(HolidayFetch r) async {
      expect(r, isA<HolidayFetchFailed>());
      expect((r as HolidayFetchFailed).reason.toString(), contains('bad date'));
    }

    const nager =
        '[{"date":"2025-13-40","localName":"x","name":"x","global":true,'
        '"counties":null,"types":["Public"]}]';
    await expectBadDate(
      await NagerSource(dioServing(nager), country: 'CA').fetchYear(2025),
    );
    const cn = '{"days":[{"name":"x","date":"2025-13-40","isOffDay":true}]}';
    await expectBadDate(await HolidayCnSource(dioServing(cn)).fetchYear(2025));
  });

  test('missing date is a failure', () async {
    const nager =
        '[{"localName":"x","name":"x","global":true,"counties":null,'
        '"types":["Public"]}]';
    expect(
      await NagerSource(dioServing(nager), country: 'CA').fetchYear(2025),
      isA<HolidayFetchFailed>(),
    );
    expect(
      await HolidayCnSource(
        dioServing('{"days":[{"name":"x","isOffDay":true}]}'),
      ).fetchYear(2025),
      isA<HolidayFetchFailed>(),
    );
  });

  test('requests carry no auth header and only the country/year', () async {
    await sourceFor(
      const HolidayRegion(country: 'CN', color: 0),
      dio,
    ).fetchYear(2025);
    expect(
      adapter.lastHeaders.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(
      adapter.lastUri.toString(),
      'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/2025.json',
    );
    expect(holidayDio().options.headers['User-Agent'], 'hmm-console');
  });

  test('regionCodesIn and available countries', () async {
    expect(
      await regionCodesIn(dio, 'CA', 2025),
      containsAll(['CA-ON', 'CA-QC', 'CA-MB']),
    );
    expect(
      (await fetchAvailableCountries(
        dio,
      ))!.any((c) => c.code == 'CA' && c.name == 'Canada'),
      isTrue,
    );
    expect(await regionCodesIn(dioThrowing(), 'CA', 2025), isNull);
  });
}
