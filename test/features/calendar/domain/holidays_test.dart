import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/holidays.dart';

void main() {
  test('parseYmd is date-only and rejects junk', () {
    expect(parseYmd('2025-01-28'), DateTime(2025, 1, 28));
    expect(parseYmd('2025-1-28x'), isNull);
    expect(parseYmd(''), isNull);
    expect(ymd(DateTime(2025, 3, 4)), '2025-03-04');
  });
  test('region and my-holidays JSON round trip (H-2 shapes)', () {
    const r = HolidayRegion(country: 'CA', region: 'CA-ON', color: 1);
    expect(r.toJson(), {'country': 'CA', 'region': 'CA-ON', 'color': 1});
    expect(HolidayRegion.fromJson(r.toJson()), r);
    expect(
      HolidayRegion.fromJson({'country': 'CN', 'color': 0})!.sourceId,
      'CN',
    );
    final m = MyHolidaysData(
      entries: [
        MyHoliday(
          id: 'a',
          name: 'Trip',
          kind: MyHolidayKind.once,
          start: DateTime(2026, 3, 2),
          end: DateTime(2026, 3, 4),
          offDay: true,
        ),
      ],
      hidden: const [
        HiddenHoliday(
          source: 'CA-ON',
          name: 'National Day for Truth and Reconciliation',
        ),
      ],
    );
    expect(m.toJson(), {
      'entries': [
        {
          'id': 'a',
          'name': 'Trip',
          'kind': 'once',
          'start': '2026-03-02',
          'end': '2026-03-04',
          'offDay': true,
        },
      ],
      'hidden': [
        {
          'source': 'CA-ON',
          'name': 'National Day for Truth and Reconciliation',
        },
      ],
    });
    expect(MyHolidaysData.fromJson(m.toJson()), m);
    expect(
      MyHolidaysData.fromJson({
        'entries': [
          {'id': 1},
        ],
        'hidden': 'x',
      }).entries,
      isEmpty,
    );
    expect(MyHolidaysData.fromJson('nope').entries, isEmpty);
  });
  test('index merges sources in order, mine last', () {
    final idx = HolidayIndex(
      downloaded: [
        HolidayDay(
          date: DateTime(2025, 1, 1),
          name: "New Year's Day",
          offDay: true,
          sourceId: 'CA-ON',
        ),
        HolidayDay(
          date: DateTime(2025, 1, 1),
          name: '元旦',
          offDay: true,
          sourceId: 'CN',
        ),
      ],
      mine: MyHolidaysData(
        entries: [
          MyHoliday(
            id: 'b',
            name: 'Bday',
            kind: MyHolidayKind.yearly,
            start: DateTime(2000, 1, 1),
            offDay: true,
          ),
        ],
        hidden: const [],
      ),
      sourceOrder: const ['CN', 'CA-ON'],
    );
    expect(idx.on(DateTime(2025, 1, 1)).map((d) => d.sourceId), [
      'CN',
      'CA-ON',
      'mine',
    ]);
  });
  test('once range inclusive; yearly Feb 29 falls on Feb 28', () {
    final idx = HolidayIndex(
      downloaded: const [],
      sourceOrder: const [],
      mine: MyHolidaysData(
        entries: [
          MyHoliday(
            id: 'r',
            name: 'Trip',
            kind: MyHolidayKind.once,
            start: DateTime(2026, 3, 2),
            end: DateTime(2026, 3, 4),
            offDay: true,
          ),
          MyHoliday(
            id: 'l',
            name: 'Leap',
            kind: MyHolidayKind.yearly,
            start: DateTime(2024, 2, 29),
            offDay: true,
          ),
        ],
        hidden: const [],
      ),
    );
    expect(idx.on(DateTime(2026, 3, 4)), hasLength(1));
    expect(idx.on(DateTime(2026, 3, 5)), isEmpty);
    expect(idx.on(DateTime(2027, 2, 28)).single.name, 'Leap');
    expect(idx.on(DateTime(2028, 2, 29)).single.name, 'Leap');
    expect(idx.on(DateTime(2028, 2, 28)), isEmpty);
  });
  test('hide removes off and 班 days of that holiday in every year (H-1)', () {
    final idx = HolidayIndex(
      sourceOrder: const ['CN'],
      downloaded: [
        HolidayDay(
          date: DateTime(2025, 1, 26),
          name: '春节',
          offDay: false,
          sourceId: 'CN',
        ),
        HolidayDay(
          date: DateTime(2025, 1, 28),
          name: '春节',
          offDay: true,
          sourceId: 'CN',
        ),
        HolidayDay(
          date: DateTime(2026, 2, 16),
          name: '春节',
          offDay: true,
          sourceId: 'CN',
        ),
      ],
      mine: const MyHolidaysData(
        entries: [],
        hidden: [HiddenHoliday(source: 'CN', name: '春节')],
      ),
    );
    expect(idx.on(DateTime(2025, 1, 26)), isEmpty);
    expect(idx.on(DateTime(2025, 1, 28)), isEmpty);
    expect(idx.on(DateTime(2026, 2, 16)), isEmpty);
  });
  test('forMonth keys by day; blockOf finds the run', () {
    final days = [
      for (var d = 1; d <= 8; d++)
        HolidayDay(
          date: DateTime(2025, 10, d),
          name: '国庆节、中秋节',
          offDay: true,
          sourceId: 'CN',
        ),
    ];
    final idx = HolidayIndex(
      downloaded: days,
      mine: const MyHolidaysData(entries: [], hidden: []),
      sourceOrder: const ['CN'],
    );
    expect(idx.forMonth(DateTime(2025, 10)).keys, [1, 2, 3, 4, 5, 6, 7, 8]);
    final b = idx.blockOf(days[3])!;
    expect((b.from, b.to), (DateTime(2025, 10, 1), DateTime(2025, 10, 8)));
    final single = HolidayIndex(
      downloaded: [days[0]],
      mine: const MyHolidaysData(entries: [], hidden: []),
      sourceOrder: const ['CN'],
    );
    expect(single.blockOf(days[0]), isNull);
  });
  test('flagEmoji', () => expect(flagEmoji('CA'), '🇨🇦'));
  test('palette', () {
    expect(kHolidayPalette.length, greaterThanOrEqualTo(6));
    expect(kHolidayPalette.toSet().length, kHolidayPalette.length);
    expect(kHolidayPalette.contains(kMyHolidaysColor), isFalse);
    expect(kDefaultHolidayRegions.length, 2);
  });
}
