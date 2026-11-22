/// Glucose units. Values are stored in the unit they arrived in; conversion
/// happens only for display.
enum GlucoseUnit {
  mgdl('mg/dL'),
  mmoll('mmol/L');

  const GlucoseUnit(this.wire);

  final String wire;

  static GlucoseUnit? fromWire(String s) {
    for (final u in values) {
      if (u.wire == s) return u;
    }
    return null;
  }
}

/// mg/dL per mmol/L (the common clinical factor).
const double kMgdlPerMmoll = 18.016;

/// A glucose number with the unit it was recorded in.
class GlucoseValue {
  const GlucoseValue(
    this.value,
    this.unit, {
    this.extraFields = const <String, Object?>{},
  });

  final num value;
  final GlucoseUnit unit;

  /// Unknown keys of the stored `glucose` object, written back.
  final Map<String, Object?> extraFields;

  /// The value in [u], converted only when it differs from [unit].
  num inUnit(GlucoseUnit u) {
    if (u == unit) return value;
    return u == GlucoseUnit.mmoll
        ? value / kMgdlPerMmoll
        : value * kMgdlPerMmoll;
  }

  /// mmol/L to 1 decimal, mg/dL as a whole number, e.g. `6.2 mmol/L`.
  String display(GlucoseUnit u) {
    final v = inUnit(u);
    final text = u == GlucoseUnit.mmoll
        ? v.toStringAsFixed(1)
        : v.round().toString();
    return '$text ${u.wire}';
  }

  @override
  bool operator ==(Object other) =>
      other is GlucoseValue &&
      other.value == value &&
      other.unit == unit &&
      other.extraFields.toString() == extraFields.toString();

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => 'GlucoseValue($value ${unit.wire})';
}

/// Whether a typed [v] is plausible: 20-600 mg/dL or 1.1-33.3 mmol/L,
/// checked in the value's own unit.
bool isValidTypedValue(GlucoseValue v) {
  final x = v.value;
  return switch (v.unit) {
    GlucoseUnit.mgdl => x >= 20 && x <= 600,
    GlucoseUnit.mmoll => x >= 1.1 && x <= 33.3,
  };
}
