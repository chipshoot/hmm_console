import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/glucose/data/glucose_codec.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';

Map<String, Object?> _example() => {
  'schemaVersion': 1,
  'id': 'r1',
  'takenAt': '2026-11-22T07:41:00-05:00',
  'glucose': {'value': 112, 'unit': 'mg/dL'},
  'context': 'fasting',
  'notes': '',
  'source': 'appleHealth',
  'appleHealth': <String, Object?>{
    'sampleId': '9C1E',
    'sourceName': 'CONTOUR DIABETES',
  },
  'draft': false,
  'updatedAt': '2026-11-22T12:42:10Z',
};

Map<String, Object?> _roundTrip(Map<String, Object?> m) =>
    jsonDecode(GlucoseCodec.encode(GlucoseCodec.decode('r1', jsonEncode(m))))
        as Map<String, Object?>;

void main() {
  test('decodes the spec example', () {
    final r = GlucoseCodec.decode('r1', jsonEncode(_example()));
    expect(r.glucose.value, 112);
    expect(r.glucose.unit, GlucoseUnit.mgdl);
    expect(r.context, GlucoseContext.fasting);
    expect(r.source, GlucoseSource.appleHealth);
    expect(r.appleHealth!.sampleId, '9C1E');
    expect(r.appleHealth!.sourceName, 'CONTOUR DIABETES');
    expect(r.takenAt.toIso(), '2026-11-22T07:41:00-05:00');
    expect(r.updatedAt, DateTime.utc(2026, 11, 22, 12, 42, 10));
  });

  test('round-trips the spec example', () {
    expect(_roundTrip(_example()), _example());
  });

  test('keeps unknown keys at top level, in glucose and in appleHealth', () {
    final m = _example()..['future'] = {'x': 1};
    (m['glucose']! as Map<String, Object?>)['meter'] = 'abc';
    (m['appleHealth']! as Map<String, Object?>)['extra'] = [1];
    expect(_roundTrip(m), m);
  });

  test('keeps a wrong-typed context', () {
    final m = _example()..['context'] = 7;
    final r = GlucoseCodec.decode('r1', jsonEncode(m));
    expect(r.context, isNull);
    expect(_roundTrip(m)['context'], 7);
  });

  test('replaces the kept wrong-typed value once the field is set', () {
    final m = _example()..['context'] = 7;
    final r = GlucoseCodec.decode('r1', jsonEncode(m));
    final out =
        jsonDecode(
              GlucoseCodec.encode(r.copyWith(context: GlucoseContext.bedtime)),
            )
            as Map;
    expect(out['context'], 'bedtime');
  });

  test('clearContext drops a valid context', () {
    final r = GlucoseCodec.decode('r1', jsonEncode(_example()));
    final out =
        jsonDecode(GlucoseCodec.encode(r.copyWith(clearContext: true))) as Map;
    expect(out.containsKey('context'), isFalse);
  });

  test('keeps a malformed appleHealth', () {
    final m = _example()..['appleHealth'] = {'sourceName': 5};
    expect(_roundTrip(m)['appleHealth'], {'sourceName': 5});
  });

  test('missing takenAt throws GlucoseUnreadable', () {
    final m = _example()..remove('takenAt');
    expect(
      () => GlucoseCodec.decode('r1', jsonEncode(m)),
      throwsA(isA<GlucoseUnreadable>()),
    );
  });

  test('bad glucose or non-JSON throws GlucoseUnreadable', () {
    final m = _example()..['glucose'] = {'value': 'x', 'unit': 'mg/dL'};
    expect(
      () => GlucoseCodec.decode('r1', jsonEncode(m)),
      throwsA(isA<GlucoseUnreadable>()),
    );
    expect(
      () => GlucoseCodec.decode('r1', 'nope'),
      throwsA(isA<GlucoseUnreadable>()),
    );
  });

  test('an integral double value decodes to an int', () {
    final r = GlucoseCodec.decode(
      'r1',
      '{"takenAt":"2026-11-22T07:41:00-05:00",'
          '"glucose":{"value":112.0,"unit":"mg/dL"}}',
    );
    expect(r.glucose.value, isA<int>());
    expect(r.glucose.value, 112);
  });

  test('a fractional value is stored exactly', () {
    final m = _example()..['glucose'] = {'value': 6.2, 'unit': 'mmol/L'};
    expect(_roundTrip(m)['glucose'], {'value': 6.2, 'unit': 'mmol/L'});
  });
}
