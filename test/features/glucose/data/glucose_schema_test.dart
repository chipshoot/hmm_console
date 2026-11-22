import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/glucose/data/glucose_codec.dart';

void main() {
  test('schema file matches the codec', () {
    final schema =
        jsonDecode(
              File(
                'docs/schemas/glucose.reading.schema.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    expect(schema['required'], [
      'schemaVersion',
      'id',
      'takenAt',
      'glucose',
      'source',
      'updatedAt',
    ]);
    final props = schema['properties']! as Map<String, Object?>;
    expect(
      (props['schemaVersion']! as Map)['const'],
      GlucoseCodec.schemaVersion,
    );
  });
}
