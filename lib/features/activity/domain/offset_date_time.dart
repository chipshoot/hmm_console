import '../../calendar/domain/event_time.dart';

/// One real moment plus the UTC offset it was recorded with, so the wall
/// clock date the user saw survives travel and time zone changes.
class OffsetDateTime {
  const OffsetDateTime(this.utc, this.offset);

  /// A device-local time, keeping the device's offset at that instant.
  factory OffsetDateTime.fromLocal(DateTime local) =>
      OffsetDateTime(local.toUtc(), local.timeZoneOffset);

  /// The moment, in UTC.
  final DateTime utc;
  final Duration offset;

  /// The recorded wall clock, as UTC-flagged fields (utc + offset).
  DateTime get wall => utc.add(offset);

  /// The recorded wall clock date as `DateTime.utc(y, m, d)`.
  DateTime get wallDate {
    final w = wall;
    return DateTime.utc(w.year, w.month, w.day);
  }

  /// ISO 8601 with whole seconds and a `+HH:MM` / `-HH:MM` offset.
  String toIso() => isoWithOffset(utc, offset);

  /// Null when [s] is not an ISO 8601 time carrying an offset.
  static OffsetDateTime? tryParse(String s) {
    try {
      final f = FixedTime.parse(s);
      return OffsetDateTime(f.instant, f.offset);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OffsetDateTime && other.utc == utc && other.offset == offset;

  @override
  int get hashCode => Object.hash(utc, offset);

  @override
  String toString() => 'OffsetDateTime(${toIso()})';
}
