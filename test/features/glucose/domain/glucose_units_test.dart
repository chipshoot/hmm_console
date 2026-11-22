import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';

void main() {
  test('converts mg/dL to mmol/L', () {
    expect(
      const GlucoseValue(112, GlucoseUnit.mgdl).inUnit(GlucoseUnit.mmoll),
      closeTo(6.2166, 0.001),
    );
  });

  test('display rounds mmol/L to 1 decimal and mg/dL to whole', () {
    expect(
      const GlucoseValue(112, GlucoseUnit.mgdl).display(GlucoseUnit.mmoll),
      '6.2 mmol/L',
    );
    expect(
      const GlucoseValue(6.2, GlucoseUnit.mmoll).display(GlucoseUnit.mgdl),
      '112 mg/dL',
    );
    expect(
      const GlucoseValue(112, GlucoseUnit.mgdl).display(GlucoseUnit.mgdl),
      '112 mg/dL',
    );
  });

  test('fromWire', () {
    expect(GlucoseUnit.fromWire('mg/dL'), GlucoseUnit.mgdl);
    expect(GlucoseUnit.fromWire('mmol/L'), GlucoseUnit.mmoll);
    expect(GlucoseUnit.fromWire('x'), isNull);
  });

  test('isValidTypedValue bounds, in the value own unit', () {
    bool v(num x, GlucoseUnit u) => isValidTypedValue(GlucoseValue(x, u));
    expect(v(19, GlucoseUnit.mgdl), isFalse);
    expect(v(20, GlucoseUnit.mgdl), isTrue);
    expect(v(600, GlucoseUnit.mgdl), isTrue);
    expect(v(601, GlucoseUnit.mgdl), isFalse);
    expect(v(1.1, GlucoseUnit.mmoll), isTrue);
    expect(v(33.3, GlucoseUnit.mmoll), isTrue);
    expect(v(33.4, GlucoseUnit.mmoll), isFalse);
    expect(v(1.0, GlucoseUnit.mmoll), isFalse);
  });
}
