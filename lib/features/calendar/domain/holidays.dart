import 'package:flutter/painting.dart';

/// Parses `YYYY-MM-DD` into a local-midnight date; null on bad input.
DateTime? parseYmd(String s) {
  final parts = s.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (!RegExp(r'^\d+$').hasMatch(parts[1]) ||
      !RegExp(r'^\d+$').hasMatch(parts[2]) ||
      !RegExp(r'^\d{4}$').hasMatch(parts[0])) {
    return null;
  }
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  if (date.month != m || date.day != d) return null;
  return date;
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// One holiday (or 班 working) day from a source.
class HolidayDay {
  const HolidayDay({
    required this.date,
    required this.name,
    required this.offDay,
    required this.sourceId,
  });

  final DateTime date;
  final String name;

  /// True for a day off; false for a make-up working day (班).
  final bool offDay;
  final String sourceId;

  @override
  bool operator ==(Object other) =>
      other is HolidayDay &&
      other.date == date &&
      other.name == name &&
      other.offDay == offDay &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(date, name, offDay, sourceId);

  @override
  String toString() => 'HolidayDay($sourceId ${ymd(date)} $name off=$offDay)';
}

/// A subscribed holiday region (country, optionally a sub-region).
class HolidayRegion {
  const HolidayRegion({
    required this.country,
    this.region,
    required this.color,
  });

  final String country;
  final String? region;

  /// Index into [kHolidayPalette].
  final int color;

  String get sourceId => region ?? country;

  Map<String, Object?> toJson() => {
    'country': country,
    if (region != null) 'region': region,
    'color': color,
  };

  static HolidayRegion? fromJson(Object? json) {
    if (json is! Map) return null;
    final country = json['country'];
    final region = json['region'];
    final color = json['color'];
    if (country is! String || country.isEmpty) return null;
    if (region != null && region is! String) return null;
    if (color is! int) return null;
    return HolidayRegion(
      country: country,
      region: region as String?,
      color: color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HolidayRegion &&
      other.country == country &&
      other.region == region &&
      other.color == color;

  @override
  int get hashCode => Object.hash(country, region, color);
}

const kDefaultHolidayRegions = [
  HolidayRegion(country: 'CN', color: 0),
  HolidayRegion(country: 'CA', region: 'CA-ON', color: 1),
];

const kMyHolidaysSourceId = 'mine';

enum MyHolidayKind { once, yearly }

class MyHoliday {
  const MyHoliday({
    required this.id,
    required this.name,
    required this.kind,
    required this.start,
    this.end,
    required this.offDay,
  });

  final String id;
  final String name;
  final MyHolidayKind kind;
  final DateTime start;
  final DateTime? end;
  final bool offDay;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'start': ymd(start),
    if (end != null) 'end': ymd(end!),
    'offDay': offDay,
  };

  static MyHoliday? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final kind = json['kind'];
    final start = json['start'];
    final end = json['end'];
    final off = json['offDay'];
    if (id is! String || name is! String) return null;
    final k = MyHolidayKind.values.where((e) => e.name == kind).firstOrNull;
    if (k == null || start is! String) return null;
    final s = parseYmd(start);
    if (s == null) return null;
    DateTime? e;
    if (end != null) {
      if (end is! String) return null;
      e = parseYmd(end);
      if (e == null) return null;
    }
    if (off != null && off is! bool) return null;
    return MyHoliday(
      id: id,
      name: name,
      kind: k,
      start: s,
      end: e,
      offDay: (off as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MyHoliday &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.offDay == offDay;

  @override
  int get hashCode => Object.hash(id, name, kind, start, end, offDay);
}

/// A downloaded holiday hidden by the user: every day with this
/// (source, name), off days and 班 days, in all years.
class HiddenHoliday {
  const HiddenHoliday({required this.source, required this.name});

  final String source;
  final String name;

  Map<String, Object?> toJson() => {'source': source, 'name': name};

  static HiddenHoliday? fromJson(Object? json) {
    if (json is! Map) return null;
    final source = json['source'];
    final name = json['name'];
    if (source is! String || name is! String) return null;
    return HiddenHoliday(source: source, name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is HiddenHoliday && other.source == source && other.name == name;

  @override
  int get hashCode => Object.hash(source, name);
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class MyHolidaysData {
  const MyHolidaysData({required this.entries, required this.hidden});

  static const empty = MyHolidaysData(entries: [], hidden: []);

  final List<MyHoliday> entries;
  final List<HiddenHoliday> hidden;

  Map<String, Object?> toJson() => {
    'entries': [for (final e in entries) e.toJson()],
    'hidden': [for (final h in hidden) h.toJson()],
  };

  static MyHolidaysData fromJson(Object? json) {
    if (json is! Map) return empty;
    final rawEntries = json['entries'];
    final rawHidden = json['hidden'];
    return MyHolidaysData(
      entries: [
        if (rawEntries is List)
          for (final e in rawEntries) ?MyHoliday.fromJson(e),
      ],
      hidden: [
        if (rawHidden is List)
          for (final h in rawHidden) ?HiddenHoliday.fromJson(h),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MyHolidaysData &&
      _listEq(other.entries, entries) &&
      _listEq(other.hidden, hidden);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(entries), Object.hashAll(hidden));
}

/// Merged view of downloaded holidays and the user's own.
class HolidayIndex {
  HolidayIndex({
    required List<HolidayDay> downloaded,
    required MyHolidaysData mine,
    required List<String> sourceOrder,
  }) : _mine = mine,
       _order = {
         for (var i = 0; i < sourceOrder.length; i++) sourceOrder[i]: i,
       } {
    final hidden = {for (final h in mine.hidden) (h.source, h.name)};
    for (final d in downloaded) {
      if (hidden.contains((d.sourceId, d.name))) continue;
      (_byDay[ymd(d.date)] ??= []).add(d);
    }
  }

  final MyHolidaysData _mine;
  final Map<String, int> _order;
  final Map<String, List<HolidayDay>> _byDay = {};

  int _rank(HolidayDay d) => d.sourceId == kMyHolidaysSourceId
      ? 1 << 30
      : (_order[d.sourceId] ?? (1 << 29));

  List<HolidayDay> on(DateTime date) {
    final day = _dateOnly(date);
    final out = <HolidayDay>[...?_byDay[ymd(day)]];
    for (final e in _mine.entries) {
      if (_matches(e, day)) {
        out.add(
          HolidayDay(
            date: day,
            name: e.name,
            offDay: e.offDay,
            sourceId: kMyHolidaysSourceId,
          ),
        );
      }
    }
    // Stable sort: keeps input order within a source.
    final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])];
    indexed.sort((a, b) {
      final c = _rank(a.$2).compareTo(_rank(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final p in indexed) p.$2];
  }

  static bool _matches(MyHoliday e, DateTime day) {
    final start = _dateOnly(e.start);
    switch (e.kind) {
      case MyHolidayKind.once:
        final end = _dateOnly(e.end ?? e.start);
        return !day.isBefore(start) && !day.isAfter(end);
      case MyHolidayKind.yearly:
        if (start.month == day.month && start.day == day.day) return true;
        return start.month == 2 &&
            start.day == 29 &&
            day.month == 2 &&
            day.day == 28 &&
            !_isLeap(day.year);
    }
  }

  /// Holidays by day of month, only days that have any.
  Map<int, List<HolidayDay>> forMonth(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    final out = <int, List<HolidayDay>>{};
    for (var d = 1; d <= last; d++) {
      final list = on(DateTime(month.year, month.month, d));
      if (list.isNotEmpty) out[d] = list;
    }
    return out;
  }

  bool _has(DateTime day, HolidayDay like) => on(day).any(
    (x) =>
        x.sourceId == like.sourceId &&
        x.name == like.name &&
        x.offDay == like.offDay,
  );

  /// The run of consecutive days with the same source, name and off-ness
  /// containing [d]; null when the run is a single day.
  ({DateTime from, DateTime to})? blockOf(HolidayDay d) {
    final day = _dateOnly(d.date);
    var from = day;
    var to = day;
    while (_has(DateTime(from.year, from.month, from.day - 1), d)) {
      from = DateTime(from.year, from.month, from.day - 1);
    }
    while (_has(DateTime(to.year, to.month, to.day + 1), d)) {
      to = DateTime(to.year, to.month, to.day + 1);
    }
    return from == to ? null : (from: from, to: to);
  }
}

/// Regional-indicator flag emoji for an ISO 3166 alpha-2 code.
String flagEmoji(String countryCode) => String.fromCharCodes([
  for (final c in countryCode.toUpperCase().codeUnits) 0x1F1E6 + (c - 0x41),
]);

/// Per-region colours, readable on light and dark backgrounds.
const List<Color> kHolidayPalette = [
  Color(0xFFE53935), // red 600
  Color(0xFF1E88E5), // blue 600
  Color(0xFF00897B), // teal 600
  Color(0xFFF57C00), // orange 700
  Color(0xFFAB47BC), // purple 400
  Color(0xFF388E3C), // green 700
];

const Color kMyHolidaysColor = Color(0xFFD81B60); // pink 600
