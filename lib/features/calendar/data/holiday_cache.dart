import 'dart:convert';
import 'dart:io';

import '../domain/holidays.dart';
import 'holiday_sources.dart';

enum CachedStatus { ok, notPublished }

class CachedYear {
  const CachedYear({
    required this.status,
    required this.fetchedAt,
    this.days = const [],
  });

  final CachedStatus status;
  final DateTime fetchedAt;
  final List<HolidayDay> days;

  Map<String, Object?> toJson() => {
    'status': status.name,
    'fetchedAt': fetchedAt.toIso8601String(),
    'days': [
      for (final d in days)
        {'date': ymd(d.date), 'name': d.name, 'offDay': d.offDay},
    ],
  };

  static CachedYear? fromJson(Object? json, String sourceId) {
    if (json is! Map) return null;
    final status = CachedStatus.values
        .where((s) => s.name == json['status'])
        .firstOrNull;
    final at = json['fetchedAt'];
    final raw = json['days'];
    if (status == null || at is! String || raw is! List) return null;
    final fetchedAt = DateTime.tryParse(at);
    if (fetchedAt == null) return null;
    final days = <HolidayDay>[];
    for (final r in raw) {
      if (r is! Map) return null;
      final date = r['date'];
      final name = r['name'];
      final off = r['offDay'];
      if (date is! String || name is! String || off is! bool) return null;
      final d = parseYmd(date);
      if (d == null) return null;
      days.add(
        HolidayDay(date: d, name: name, offDay: off, sourceId: sourceId),
      );
    }
    return CachedYear(status: status, fetchedAt: fetchedAt, days: days);
  }
}

/// Per-device holiday files (`holidays/<sourceId>_<year>.json`); not synced.
class HolidayCache {
  HolidayCache(this._dir);

  final Future<Directory> Function() _dir;

  Future<Directory> _holidays() async {
    final root = await _dir();
    return Directory('${root.path}/holidays');
  }

  Future<File> _file(String sourceId, int year) async =>
      File('${(await _holidays()).path}/${sourceId}_$year.json');

  Future<CachedYear?> read(String sourceId, int year) async {
    try {
      final f = await _file(sourceId, year);
      if (!await f.exists()) return null;
      return CachedYear.fromJson(jsonDecode(await f.readAsString()), sourceId);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String sourceId, int year, CachedYear y) async {
    final f = await _file(sourceId, year);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(y.toJson()));
  }

  /// The last fetched available-countries list (`countries.json`); not a
  /// year file, so [pruneExcept] leaves it alone. Empty when never saved.
  Future<List<({String code, String name})>> readCountries() async {
    try {
      final f = File('${(await _holidays()).path}/countries.json');
      if (!await f.exists()) return const [];
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return const [];
      return [
        for (final r in raw)
          if (r is Map && r['code'] is String && r['name'] is String)
            (code: r['code'] as String, name: r['name'] as String),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeCountries(List<({String code, String name})> list) async {
    final f = File('${(await _holidays()).path}/countries.json');
    await f.parent.create(recursive: true);
    await f.writeAsString(
      jsonEncode([
        for (final c in list) {'code': c.code, 'name': c.name},
      ]),
    );
  }

  /// Source id of a `<sourceId>_<year>.json` file name; null for others.
  static String? _sourceOf(String name) {
    final m = RegExp(r'^(.+)_(\d{4})\.json$').firstMatch(name);
    return m?.group(1);
  }

  /// Deletes year files of sources not in [keepSourceIds].
  Future<bool> pruneExcept(Set<String> keepSourceIds) async {
    var any = false;
    try {
      final dir = await _holidays();
      if (!await dir.exists()) return false;
      await for (final e in dir.list()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        final src = _sourceOf(name);
        if (src == null || keepSourceIds.contains(src)) continue;
        try {
          await e.delete();
          any = true;
        } catch (_) {}
      }
    } catch (_) {}
    return any;
  }

  Future<List<HolidayDay>> daysFor(
    Set<String> sourceIds,
    Set<int> years,
  ) async {
    final out = <HolidayDay>[];
    for (final s in sourceIds) {
      for (final y in years) {
        final c = await read(s, y);
        if (c != null && c.status == CachedStatus.ok) out.addAll(c.days);
      }
    }
    return out;
  }
}

/// The shown year; next year for a December grid (its trailing January days,
/// and China's 元旦 days off that can fall in late December, live in next
/// year's file); and next year from 1 November (H-9).
Set<int> yearsToFetch(DateTime shownMonth, DateTime now) => {
  shownMonth.year,
  if (shownMonth.month == 12) shownMonth.year + 1,
  if (now.month >= 11) now.year + 1,
};

bool needsFetch(CachedYear? c, int year, DateTime now) {
  if (c == null) return true;
  if (year < now.year) return false;
  final age = now.difference(c.fetchedAt);
  return switch (c.status) {
    CachedStatus.ok => age > const Duration(days: 7),
    CachedStatus.notPublished => age >= const Duration(days: 1),
  };
}

class HolidayRefresher {
  HolidayRefresher(this._cache, this._sourceFor, this._now);

  final HolidayCache _cache;
  final HolidaySource Function(HolidayRegion) _sourceFor;
  final DateTime Function() _now;
  Future<bool>? _inFlight;

  Future<bool> refresh(List<HolidayRegion> regions, Set<int> years) {
    final running = _inFlight;
    if (running != null) return running;
    final run = _run(regions, years).whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  /// Fetches what is due. Never deletes: removed countries' files are
  /// pruned when the owner leaves the Holidays screen, so a refresh started
  /// with a stale or not-yet-loaded region list cannot lose saved days.
  Future<bool> _run(List<HolidayRegion> regions, Set<int> years) async {
    var changed = false;
    for (final r in regions) {
      final HolidaySource source;
      try {
        source = _sourceFor(r);
      } catch (_) {
        continue;
      }
      for (final y in years) {
        try {
          final cached = await _cache.read(r.sourceId, y);
          final now = _now();
          if (!needsFetch(cached, y, now)) continue;
          final res = await source.fetchYear(y);
          switch (res) {
            case HolidayYear(:final days):
              await _cache.write(
                r.sourceId,
                y,
                CachedYear(status: CachedStatus.ok, fetchedAt: now, days: days),
              );
              changed = true;
            case HolidayNotPublished():
              await _cache.write(
                r.sourceId,
                y,
                CachedYear(status: CachedStatus.notPublished, fetchedAt: now),
              );
              changed = true;
            case HolidayFetchFailed():
              break;
          }
        } catch (_) {}
      }
    }
    return changed;
  }
}
