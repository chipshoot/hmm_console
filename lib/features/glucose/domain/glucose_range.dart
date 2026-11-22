import 'glucose_units.dart';

/// The user's target range, in [unit]. Both ends are inside the range.
class GlucoseRange {
  const GlucoseRange({
    required this.low,
    required this.high,
    required this.unit,
  });

  final num low;
  final num high;
  final GlucoseUnit unit;

  @override
  bool operator ==(Object other) =>
      other is GlucoseRange &&
      other.low == low &&
      other.high == high &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(low, high, unit);

  @override
  String toString() => 'GlucoseRange($low-$high ${unit.wire})';
}

enum GlucoseBand { below, inRange, above }

/// Where [v] sits against [r], compared in the range's unit. Null when there
/// is no range. A value equal to either end is [GlucoseBand.inRange].
GlucoseBand? bandFor(GlucoseValue v, GlucoseRange? r) {
  if (r == null) return null;
  final x = v.inUnit(r.unit);
  if (x < r.low) return GlucoseBand.below;
  if (x > r.high) return GlucoseBand.above;
  return GlucoseBand.inRange;
}
