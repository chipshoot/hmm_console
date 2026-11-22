import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/glucose/domain/glucose_range.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';

void main() {
  const range = GlucoseRange(low: 4.0, high: 7.0, unit: GlucoseUnit.mmoll);
  GlucoseValue mmol(num v) => GlucoseValue(v, GlucoseUnit.mmoll);

  test('null range gives null', () {
    expect(bandFor(mmol(6), null), isNull);
  });

  test('4.0-7.0 mmol/L bands, ends inclusive', () {
    expect(bandFor(mmol(6.2), range), GlucoseBand.inRange);
    expect(bandFor(mmol(7.0), range), GlucoseBand.inRange);
    expect(bandFor(mmol(4.0), range), GlucoseBand.inRange);
    expect(bandFor(mmol(7.1), range), GlucoseBand.above);
    expect(bandFor(mmol(3.9), range), GlucoseBand.below);
  });

  test('a mg/dL value is converted to the range unit', () {
    expect(
      bandFor(const GlucoseValue(130, GlucoseUnit.mgdl), range),
      GlucoseBand.above,
    );
    expect(
      bandFor(const GlucoseValue(100, GlucoseUnit.mgdl), range),
      GlucoseBand.inRange,
    );
  });

  test('compares at display precision: HealthKit 4.0 mmol/L is in range', () {
    // HealthKit converts with 18.015588: 4.0 mmol/L arrives as 72.062352
    // mg/dL, which is 3.99991 mmol/L at 18.016 and shows as 4.0.
    expect(
      bandFor(const GlucoseValue(72.062352, GlucoseUnit.mgdl), range),
      GlucoseBand.inRange,
    );
  });

  test('a mg/dL range rounds to whole mg/dL', () {
    const mgRange = GlucoseRange(low: 70, high: 140, unit: GlucoseUnit.mgdl);
    expect(
      bandFor(const GlucoseValue(69.6, GlucoseUnit.mgdl), mgRange),
      GlucoseBand.inRange,
    );
    expect(
      bandFor(const GlucoseValue(140.4, GlucoseUnit.mgdl), mgRange),
      GlucoseBand.inRange,
    );
    expect(
      bandFor(const GlucoseValue(140.6, GlucoseUnit.mgdl), mgRange),
      GlucoseBand.above,
    );
  });
}
