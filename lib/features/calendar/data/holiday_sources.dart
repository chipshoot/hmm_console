import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/holidays.dart';

/// Result of fetching one year from a holiday source.
sealed class HolidayFetch {
  const HolidayFetch();
}

class HolidayYear extends HolidayFetch {
  const HolidayYear(this.days);
  final List<HolidayDay> days;
}

/// The source has no data for that year (yet).
class HolidayNotPublished extends HolidayFetch {
  const HolidayNotPublished();
}

class HolidayFetchFailed extends HolidayFetch {
  const HolidayFetchFailed(this.reason);
  final Object reason;
}

abstract class HolidaySource {
  String get sourceId;
  Future<HolidayFetch> fetchYear(int year);
}

/// A plain Dio for holiday requests: no Hmm API interceptors, no auth.
/// Requests carry only a country code and a year.
Dio holidayDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': 'hmm-console'},
    responseType: ResponseType.plain,
    validateStatus: (_) => true,
  ),
);

Object? _decode(Object? data) => data is String ? jsonDecode(data) : data;

Future<({int status, Object? body})> _get(Dio dio, String url) async {
  final res = await dio.get<Object?>(
    url,
    options: Options(
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );
  return (status: res.statusCode ?? 0, body: res.data);
}

class NagerSource implements HolidaySource {
  NagerSource(this.dio, {required this.country, this.region});

  final Dio dio;
  final String country;
  final String? region;

  @override
  String get sourceId => region ?? country;

  @override
  Future<HolidayFetch> fetchYear(int year) async {
    try {
      final res = await _get(
        dio,
        'https://date.nager.at/api/v3/PublicHolidays/$year/$country',
      );
      if (res.status != 200) {
        return HolidayFetchFailed('HTTP ${res.status}');
      }
      final list = _decode(res.body) as List;
      final days = <HolidayDay>[];
      for (final raw in list) {
        final m = raw as Map;
        final types = (m['types'] as List).cast<String>();
        if (!types.contains('Public')) continue;
        final counties = (m['counties'] as List?)?.cast<String>();
        final ok =
            m['global'] == true ||
            (region != null && (counties?.contains(region) ?? false));
        if (!ok) continue;
        final date = parseYmd(m['date'] as String);
        if (date == null) return HolidayFetchFailed('bad date ${m['date']}');
        days.add(
          HolidayDay(
            date: date,
            name: m['localName'] as String,
            offDay: true,
            sourceId: sourceId,
          ),
        );
      }
      return HolidayYear(days);
    } catch (e) {
      return HolidayFetchFailed(e);
    }
  }
}

class HolidayCnSource implements HolidaySource {
  HolidayCnSource(this.dio);

  final Dio dio;

  @override
  String get sourceId => 'CN';

  @override
  Future<HolidayFetch> fetchYear(int year) async {
    try {
      final res = await _get(
        dio,
        'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/$year.json',
      );
      if (res.status == 404) return const HolidayNotPublished();
      if (res.status != 200) return HolidayFetchFailed('HTTP ${res.status}');
      final root = _decode(res.body) as Map;
      final days = <HolidayDay>[];
      for (final raw in root['days'] as List) {
        final m = raw as Map;
        final date = parseYmd(m['date'] as String);
        if (date == null) return HolidayFetchFailed('bad date ${m['date']}');
        days.add(
          HolidayDay(
            date: date,
            name: m['name'] as String,
            offDay: m['isOffDay'] as bool,
            sourceId: sourceId,
          ),
        );
      }
      return HolidayYear(days);
    } catch (e) {
      return HolidayFetchFailed(e);
    }
  }
}

HolidaySource sourceFor(HolidayRegion r, Dio dio) => r.country == 'CN'
    ? HolidayCnSource(dio)
    : NagerSource(dio, country: r.country, region: r.region);

Future<List<({String code, String name})>?> fetchAvailableCountries(
  Dio dio,
) async {
  try {
    final res = await _get(
      dio,
      'https://date.nager.at/api/v3/AvailableCountries',
    );
    if (res.status != 200) return null;
    return [
      for (final raw in _decode(res.body) as List)
        (
          code: (raw as Map)['countryCode'] as String,
          name: raw['name'] as String,
        ),
    ];
  } catch (_) {
    return null;
  }
}

Future<List<String>?> regionCodesIn(Dio dio, String country, int year) async {
  try {
    final res = await _get(
      dio,
      'https://date.nager.at/api/v3/PublicHolidays/$year/$country',
    );
    if (res.status != 200) return null;
    final codes = <String>{};
    for (final raw in _decode(res.body) as List) {
      final m = raw as Map;
      if (m['global'] == true) continue;
      if (!(m['types'] as List).contains('Public')) continue;
      codes.addAll(((m['counties'] as List?) ?? const []).cast<String>());
    }
    return codes.toList()..sort();
  } catch (_) {
    return null;
  }
}
