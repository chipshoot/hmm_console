// lib/features/calendar/states/holiday_providers.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/holiday_cache.dart';
import '../data/holiday_sources.dart';
import '../domain/holidays.dart';
import 'holiday_settings_providers.dart';

/// HTTP client for the public holiday sources (no auth, no app interceptors).
final holidayDioProvider = Provider<Dio>((ref) => holidayDio());

/// Per-device holiday files under the app support directory.
final holidayCacheProvider = Provider<HolidayCache>(
  (ref) => HolidayCache(getApplicationSupportDirectory),
);

final holidayRefresherProvider = Provider<HolidayRefresher>((ref) {
  final dio = ref.watch(holidayDioProvider);
  return HolidayRefresher(
    ref.watch(holidayCacheProvider),
    (r) => sourceFor(r, dio),
    DateTime.now,
  );
});

/// Holidays for the month starting at the given date (first of month).
///
/// Returns what is cached without waiting for the network, then refreshes in
/// the background and rebuilds when the refresh changed anything. The refresh
/// waits until both holiday settings have been read from prefs, so a cold
/// start never refreshes with the default list; once they load, a changed
/// list rebuilds this provider and the stale build starts nothing. An
/// overlapping refresh shares the run already in flight, so the rebuild asks
/// again for its own regions and years; once nothing is due the refresher
/// returns false and the cycle stops.
final holidaysForMonthProvider = FutureProvider.autoDispose
    .family<HolidayIndex, DateTime>((ref, month) async {
      final regions = ref.watch(holidayRegionsProvider);
      final mine = ref.watch(myHolidaysProvider);
      final hydrated = Future.wait([
        ref.read(holidayRegionsProvider.notifier).hydrated,
        ref.read(myHolidaysProvider.notifier).hydrated,
      ]);
      final cache = ref.watch(holidayCacheProvider);
      final refresher = ref.watch(holidayRefresherProvider);
      final years = yearsToFetch(month, DateTime.now());
      final sourceOrder = [for (final r in regions) r.sourceId];
      final days = await cache.daysFor(sourceOrder.toSet(), years);
      final index = HolidayIndex(
        downloaded: days,
        mine: mine,
        sourceOrder: sourceOrder,
      );
      if (!ref.mounted) return index;
      unawaited(
        hydrated
            .then<bool>((_) {
              // Hydration changed the list: the rebuild (which is only
              // scheduled, so this build may still be mounted) refreshes.
              if (!ref.mounted) return false;
              if (!identical(ref.read(holidayRegionsProvider), regions)) {
                return false;
              }
              return refresher.refresh(regions, years);
            })
            .then<void>((changed) {
              if (changed && ref.mounted) ref.invalidateSelf();
            })
            .catchError((Object e) {
              debugPrint('Holiday refresh failed (${e.runtimeType})');
            }),
      );
      return index;
    });

/// A holiday mark in a month-grid cell: one per source per day.
class HolidayMark {
  const HolidayMark(this.color, this.offDay);

  final Color color;
  final bool offDay;

  @override
  bool operator ==(Object other) =>
      other is HolidayMark && other.color == color && other.offDay == offDay;

  @override
  int get hashCode => Object.hash(color, offDay);

  @override
  String toString() => 'HolidayMark($color, off=$offDay)';
}

const Color _unknownSourceColor = Color(0xFF9E9E9E);

/// Colour per source id; My holidays has its own colour.
Map<String, Color> holidayColors(List<HolidayRegion> regions) => {
  for (final r in regions)
    r.sourceId: kHolidayPalette[r.color % kHolidayPalette.length],
  kMyHolidaysSourceId: kMyHolidaysColor,
};

/// Marks by day of [month]: one per source, in source order; a source with
/// any day off that day marks it off.
Map<int, List<HolidayMark>> holidayMarksFor(
  HolidayIndex idx,
  DateTime month,
  Map<String, Color> colors,
) {
  final out = <int, List<HolidayMark>>{};
  idx.forMonth(month).forEach((day, list) {
    final off = <String, bool>{};
    for (final h in list) {
      off[h.sourceId] = (off[h.sourceId] ?? false) || h.offDay;
    }
    out[day] = [
      for (final e in off.entries)
        HolidayMark(colors[e.key] ?? _unknownSourceColor, e.value),
    ];
  });
  return out;
}
