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
}
