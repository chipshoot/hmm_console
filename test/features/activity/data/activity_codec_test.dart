import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/activity/data/activity_codec.dart';

Map<String, Object?> _example() =>
    (jsonDecode('''
{
  "schemaVersion": 1,
  "id": "6f1c",
  "kind": "health.walk",
  "start": "2026-11-21T18:40:00-05:00",
  "durationMinutes": 30,
  "intensity": "moderate",
  "measurements": [ { "name": "distance", "value": 2.4, "unit": "km" } ],
  "links": [ { "noteUuid": "n1", "role": "meal" } ],
  "plannedEvent": { "eventId": "e1", "occurrence": "floating:2026-11-21T18:30", "at": "2026-11-21T18:30:00-05:00" },
  "notes": "after dinner, felt fine",
  "details": { "health": { } },
  "source": "manual",
  "draft": false,
  "updatedAt": "2026-11-21T19:12:03Z"
}
''')
            as Map)
        .cast<String, Object?>();

Map<String, Object?> _rt(Map<String, Object?> j) =>
    ActivityCodec.encode(ActivityCodec.decode('6f1c', j));

void main() {
  test('spec example round-trips', () {
    expect(_rt(_example()), _example());
  });

  test('unknown keys survive at every level', () {
    final j = _example()
      ..['future'] = 1
      ..['measurements'] = [
        {'name': 'distance', 'value': 2.4, 'unit': 'km', 'fm': 'x'},
      ]
      ..['links'] = [
        {'noteUuid': 'n1', 'role': 'meal', 'fl': true},
      ]
      ..['plannedEvent'] = {
        'eventId': 'e1',
        'occurrence': 'floating:2026-11-21T18:30',
        'at': '2026-11-21T18:30:00-05:00',
        'fp': [1],
      };
    expect(_rt(j), j);
  });

  test('wrong-typed intensity decodes to null and is written back', () {
    final j = _example()..['intensity'] = 7;
    expect(ActivityCodec.decode('x', j).intensity, isNull);
    expect(_rt(j)['intensity'], 7);
  });

  test('unknown source string behaves like a wrong type', () {
    final j = _example()..['source'] = 'watch';
    expect(ActivityCodec.decode('x', j).source.name, 'manual');
    expect(_rt(j)['source'], 'watch');
  });

  test('unreadable measurement entry is kept and re-emitted', () {
    final j = _example()..['measurements'] = ['x'];
    final a = ActivityCodec.decode('x', j);
    expect(a.measurements, isEmpty);
    expect(a.unreadableEntries['measurements'], ['x']);
    expect(_rt(j)['measurements'], ['x']);
  });

  test('missing schemaVersion reads as 1', () {
    final j = _example()..remove('schemaVersion');
    expect(ActivityCodec.decode('x', j).schemaVersion, 1);
  });

  test('missing kind, bad start or string duration are unreadable', () {
    for (final bad in [
      _example()..remove('kind'),
      _example()..['start'] = 'bad',
      _example()..['durationMinutes'] = '30',
    ]) {
      expect(
        () => ActivityCodec.decode('abc', bad),
        throwsA(isA<ActivityUnreadable>().having((x) => x.id, 'id', 'abc')),
      );
    }
  });

  test('an integral number duration reads as an int (ruling R5)', () {
    final j = _example()..['durationMinutes'] = 30.0;
    expect(ActivityCodec.decode('x', j).durationMinutes, 30);
    expect(_rt(j)['durationMinutes'], 30);
  });

  test('a non-integral duration is unreadable', () {
    final j = _example()..['durationMinutes'] = 30.5;
    expect(
      () => ActivityCodec.decode('abc', j),
      throwsA(isA<ActivityUnreadable>()),
    );
  });

  test('details round-trip untouched and area comes from kind', () {
    final j = _example()
      ..['details'] = {
        'reading': {'pages': 25},
      };
    expect(_rt(j)['details'], j['details']);
    expect(ActivityCodec.decode('x', j).area, 'health');
  });

  test('unknown kind edit keeps everything else', () {
    final j = _example()
      ..['kind'] = 'garden.weeding'
      ..['future'] = 'x';
    final a = ActivityCodec.decode('6f1c', j).copyWith(durationMinutes: 45);
    expect(ActivityCodec.encode(a), {...j, 'durationMinutes': 45});
  });

  test('encoded output satisfies the schema', () {
    final schema =
        jsonDecode(
              File(
                'docs/schemas/activity.activity.schema.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final out = _rt(_example());
    for (final k in (schema['required'] as List)) {
      expect(out.containsKey(k), isTrue, reason: 'required $k');
    }
    final props = (schema['properties'] as Map).keys.toSet();
    for (final k in out.keys) {
      expect(props.contains(k), isTrue, reason: 'unexpected key $k');
    }
    expect(
      (schema['properties'] as Map)['schemaVersion']['const'],
      ActivityCodec.currentSchemaVersion,
    );
  });
}
