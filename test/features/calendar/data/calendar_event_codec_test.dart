import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/data/calendar_event_codec.dart';
import 'package:hmm_console/features/calendar/domain/event_time.dart';

Map<String, Object?> _example() => {
  'schemaVersion': 1,
  'id': '4f0c',
  'title': 'Evening walk',
  'notes': null,
  'start': {'floating': '2026-11-18T19:00'},
  'end': {'floating': '2026-11-18T19:30'},
  'rrule': 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
  'reminders': [
    {'minutesBefore': 15, 'channel': 'device'},
  ],
  'owner': {'subsystem': 'diabetes', 'noteUuid': null},
  'status': 'active',
  'source': 'assistant',
  'draft': false,
  'occurrences': [
    {
      'originalStart': {'floating': '2026-11-18T19:00'},
      'status': 'done',
    },
    {
      'originalStart': {'floating': '2026-11-20T19:00'},
      'status': 'moved',
      'movedTo': {'floating': '2026-11-20T20:00'},
      'title': 'Late walk',
      'futureOverrideKey': 7,
    },
  ],
  'updatedAt': '2026-11-17T21:04:00-05:00',
  'futureKey': {'a': 1},
};

void main() {
  test('round-trips every field including extraFields', () {
    final e = CalendarEventCodec.decode('4f0c', _example());
    expect(e.extraFields, {
      'futureKey': {'a': 1},
    });
    final out = CalendarEventCodec.encode(e);
    expect(out['futureKey'], {'a': 1});
    expect(CalendarEventCodec.decode('4f0c', out), e);
    expect(
      DateTime.parse(out['updatedAt']! as String),
      DateTime.parse('2026-11-17T21:04:00-05:00'),
    );
  });

  test('unknown keys inside an override are kept and written back', () {
    final e = CalendarEventCodec.decode('4f0c', _example());
    final o = e.occurrences[1];
    expect(o.extraFields, {'title': 'Late walk', 'futureOverrideKey': 7});
    expect(o.movedTo, const FloatingTime(2026, 11, 20, 20, 0));
    final out = CalendarEventCodec.encode(e);
    final o2 = (out['occurrences']! as List)[1] as Map;
    expect(o2['title'], 'Late walk');
    expect(o2['futureOverrideKey'], 7);
  });

  test('fixed, floating and allDay starts round-trip', () {
    Map<String, Object?> with_(Object start) => {..._example(), 'start': start};
    final f = CalendarEventCodec.decode(
      'x',
      with_({'fixed': '2026-11-20T10:00:00-05:00'}),
    );
    final ft = f.start as FixedTime;
    expect(ft.offset, const Duration(hours: -5));
    expect(ft.instant.toUtc(), DateTime.utc(2026, 11, 20, 15));
    expect(
      (CalendarEventCodec.encode(f)['start']! as Map)['fixed'],
      '2026-11-20T10:00:00-05:00',
    );
    expect(
      CalendarEventCodec.decode(
        'x',
        with_({'floating': '2026-11-18T19:00'}),
      ).start,
      const FloatingTime(2026, 11, 18, 19, 0),
    );
    expect(
      CalendarEventCodec.decode('x', with_({'allDay': '2026-11-20'})).start,
      const AllDay(2026, 11, 20),
    );
  });

  test('wireKey is canonical', () {
    expect(
      const FloatingTime(2026, 11, 18, 19, 0).wireKey,
      'floating:2026-11-18T19:00',
    );
    expect(const AllDay(2026, 11, 20).wireKey, 'allDay:2026-11-20');
    expect(
      FixedTime.parse('2026-11-20T10:00:00-05:00').wireKey,
      FixedTime.parse('2026-11-20T15:00:00Z').wireKey,
    );
  });

  test('wrong-typed known value is written back unchanged', () {
    final e = CalendarEventCodec.decode('x', {..._example(), 'draft': 'yes'});
    expect(e.draft, isFalse);
    expect(CalendarEventCodec.encode(e)['draft'], 'yes');
    // Once the owner changes the field, the typed value wins.
    expect(CalendarEventCodec.encode(e.copyWith(draft: true))['draft'], true);
  });

  test('undecodable list entries are kept verbatim', () {
    final e = CalendarEventCodec.decode('x', {
      ..._example(),
      'reminders': [
        {'minutesBefore': 5, 'channel': 'device'},
        'junk',
        {'minutesBefore': 5, 'channel': 'carrierPigeon'},
      ],
    });
    expect(e.reminders, hasLength(1));
    final out = CalendarEventCodec.encode(e)['reminders']! as List;
    expect(out, hasLength(3));
    expect(out, contains('junk'));
  });

  test('missing or undecodable start or title is unreadable', () {
    for (final bad in [
      (Map<String, Object?>.of(_example())..remove('start')),
      {..._example(), 'start': 'tomorrow'},
      {
        ..._example(),
        'start': {'floating': 'nope'},
      },
      (Map<String, Object?>.of(_example())..remove('title')),
    ]) {
      expect(
        () => CalendarEventCodec.decode('abc', bad),
        throwsA(
          isA<CalendarEventUnreadable>().having((x) => x.id, 'id', 'abc'),
        ),
      );
    }
  });

  test('missing schemaVersion reads as 1', () {
    final j = Map<String, Object?>.of(_example())..remove('schemaVersion');
    expect(CalendarEventCodec.decode('x', j).schemaVersion, 1);
  });

  test('encoded output satisfies the schema', () {
    final schema =
        jsonDecode(
              File(
                'docs/schemas/calendar.event.schema.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final out = CalendarEventCodec.encode(
      CalendarEventCodec.decode('4f0c', _example()),
    );
    for (final k in (schema['required'] as List)) {
      expect(out.containsKey(k), isTrue, reason: 'required $k');
    }
    final props = (schema['properties'] as Map).keys.toSet();
    final extras = CalendarEventCodec.decode('4f0c', _example()).extraFields;
    for (final k in out.keys) {
      expect(
        props.contains(k) || extras.containsKey(k),
        isTrue,
        reason: 'unexpected key $k',
      );
    }
  });
}
