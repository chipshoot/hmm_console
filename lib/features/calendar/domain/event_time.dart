/// When something happens on a calendar.
///
/// * [FixedTime]: one real moment plus the offset it was written with.
/// * [FloatingTime]: a wall-clock time that stays put across time zones.
/// * [AllDay]: a date only.
sealed class EventTime {
  const EventTime();

  /// Canonical one-line string for ids, payloads and override matching,
  /// e.g. `floating:2026-11-18T19:00`.
  String get wireKey;

  /// `{"fixed": ...}`, `{"floating": ...}` or `{"allDay": ...}`.
  Map<String, String> toWire();

  /// Throws [FormatException] when [m] is not one of the three wire shapes.
  static EventTime fromWire(Map<dynamic, dynamic> m) {
    final fixed = m['fixed'];
    if (fixed is String) return FixedTime.parse(fixed);
    final floating = m['floating'];
    if (floating is String) return FloatingTime.parse(floating);
    final allDay = m['allDay'];
    if (allDay is String) return AllDay.parse(allDay);
    throw FormatException('not an event time: $m');
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
String _four(int v) => v.toString().padLeft(4, '0');

/// ISO 8601 of [instant] written at [offset] (not converted to `Z`).
String isoWithOffset(DateTime instant, Duration offset) {
  final w = instant.toUtc().add(offset);
  final neg = offset.isNegative;
  final abs = offset.abs();
  final sign = neg ? '-' : '+';
  return '${_four(w.year)}-${_two(w.month)}-${_two(w.day)}'
      'T${_two(w.hour)}:${_two(w.minute)}:${_two(w.second)}'
      '$sign${_two(abs.inHours)}:${_two(abs.inMinutes % 60)}';
}

final class FixedTime extends EventTime {
  const FixedTime(this.instant, this.offset);

  /// The moment, in UTC.
  final DateTime instant;
  final Duration offset;

  static final _tail = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  static FixedTime parse(String s) {
    final m = _tail.firstMatch(s);
    if (m == null) throw FormatException('fixed time needs an offset: $s');
    final t = m.group(1)!;
    var offset = Duration.zero;
    if (t != 'Z') {
      final digits = t.substring(1).replaceAll(':', '');
      offset = Duration(
        hours: int.parse(digits.substring(0, 2)),
        minutes: int.parse(digits.substring(2)),
      );
      if (t.startsWith('-')) offset = -offset;
    }
    return FixedTime(DateTime.parse(s).toUtc(), offset);
  }

  @override
  String get wireKey => 'fixed:${instant.toUtc().toIso8601String()}';

  @override
  Map<String, String> toWire() => {'fixed': isoWithOffset(instant, offset)};

  @override
  bool operator ==(Object other) =>
      other is FixedTime &&
      other.instant.isAtSameMomentAs(instant) &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(instant.microsecondsSinceEpoch, offset);

  @override
  String toString() => 'FixedTime(${isoWithOffset(instant, offset)})';
}

final class FloatingTime extends EventTime {
  const FloatingTime(this.year, this.month, this.day, this.hour, this.minute);

  final int year, month, day, hour, minute;

  static final _re = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$');

  static FloatingTime parse(String s) {
    final m = _re.firstMatch(s);
    if (m == null) throw FormatException('not a floating time: $s');
    final v = [for (var i = 1; i <= 5; i++) int.parse(m.group(i)!)];
    return FloatingTime(v[0], v[1], v[2], v[3], v[4]);
  }

  String get _iso =>
      '${_four(year)}-${_two(month)}-${_two(day)}T${_two(hour)}:${_two(minute)}';

  @override
  String get wireKey => 'floating:$_iso';

  @override
  Map<String, String> toWire() => {'floating': _iso};

  @override
  bool operator ==(Object other) =>
      other is FloatingTime &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(year, month, day, hour, minute);

  @override
  String toString() => 'FloatingTime($_iso)';
}

final class AllDay extends EventTime {
  const AllDay(this.year, this.month, this.day);

  final int year, month, day;

  static final _re = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static AllDay parse(String s) {
    final m = _re.firstMatch(s);
    if (m == null) throw FormatException('not a date: $s');
    return AllDay(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  String get _iso => '${_four(year)}-${_two(month)}-${_two(day)}';

  @override
  String get wireKey => 'allDay:$_iso';

  @override
  Map<String, String> toWire() => {'allDay': _iso};

  @override
  bool operator ==(Object other) =>
      other is AllDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'AllDay($_iso)';
}
