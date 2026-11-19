import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/domain/lunar.dart';

DateTime d(int y, int m, int dd) => DateTime(y, m, dd);

void main() {
  test('春节 dates', () {
    for (final day in [d(2024, 2, 10), d(2025, 1, 29), d(2026, 2, 17)]) {
      expect(lunarCellLabel(day)!.text, '春节');
      expect(lunarCellLabel(day)!.kind, LunarLabelKind.festival);
    }
    expect(toLunar(d(2024, 2, 10)), const LunarDate(2024, 1, 1));
  });
  test('other festivals', () {
    expect(lunarCellLabel(d(2024, 2, 24))!.text, '元宵');
    expect(lunarCellLabel(d(2025, 5, 31))!.text, '端午');
    expect(lunarCellLabel(d(2025, 10, 6))!.text, '中秋');
  });
  test('除夕 on a 29-day and a 30-day 腊月', () {
    expect(lunarCellLabel(d(2026, 2, 16))!.text, '除夕');
    expect(toLunar(d(2026, 2, 16)), const LunarDate(2025, 12, 29));
    expect(lunarCellLabel(d(2024, 2, 9))!.text, '除夕');
    expect(toLunar(d(2024, 2, 9)), const LunarDate(2023, 12, 30));
  });
  test('leap months', () {
    expect(toLunar(d(2025, 7, 25)), const LunarDate(2025, 6, 1, isLeap: true));
    expect(lunarCellLabel(d(2025, 7, 25))!.text, '闰六月');
    expect(lunarCellLabel(d(2025, 7, 25))!.kind, LunarLabelKind.month);
    expect(toLunar(d(2023, 3, 22)), const LunarDate(2023, 2, 1, isLeap: true));
  });
  test('节气, including terms near the year boundary', () {
    expect(lunarCellLabel(d(2025, 12, 7))!.text, '大雪');
    expect(lunarCellLabel(d(2025, 12, 21))!.text, '冬至');
    expect(lunarCellLabel(d(2026, 1, 5))!.text, '小寒');
    expect(lunarCellLabel(d(2026, 4, 5))!.text, '清明');
    expect(lunarCellLabel(d(2026, 4, 5))!.kind, LunarLabelKind.solarTerm);
  });
  test('plain day', () {
    expect(
      lunarCellLabel(d(2024, 2, 11)),
      const LunarCellLabel('初二', LunarLabelKind.day),
    );
  });
  test('fromLunar / fromLunarBackward', () {
    expect(fromLunar(2025, 6, 1, leap: true), DateTime.utc(2025, 7, 25));
    expect(fromLunar(2024, 6, 1, leap: true), isNull);
    expect(fromLunarBackward(2024, 6, 1, leap: true), fromLunar(2024, 6, 1));
    expect(fromLunar(2024, 12, 30), isNull);
    expect(fromLunarBackward(2024, 12, 30), DateTime.utc(2025, 1, 28));
    expect(fromLunar(2023, 12, 30), DateTime.utc(2024, 2, 9));
  });
  test('memoised conversions: repeated calls return identical results', () {
    // Interleave years so the memo, not the package's last-year cache, is
    // what answers the second round.
    List<Object?> round() => [
      for (final y in [1950, 2026, 1901, 2099, 1950, 2025])
        for (final m in [1, 6, 12])
          (
            fromLunar(y, m, 30),
            fromLunarBackward(y, m, 30),
            fromLunar(y, m, 1, leap: true),
            fromLunarBackward(y, m, 15, leap: true),
            toLunar(DateTime(y, m, 15)),
          ),
    ];
    final first = round();
    expect(round(), first);
    expect(round(), first);
    expect(fromLunarBackward(2024, 12, 30), DateTime.utc(2025, 1, 28));
    expect(toLunar(d(2026, 2, 17)), const LunarDate(2026, 1, 1));
  });
  test('every lunar month round-trips through toLunar (1901–2099)', () {
    for (var y = kLunarMinYear; y <= kLunarMaxYear; y++) {
      for (var m = 1; m <= 12; m++) {
        for (final leap in [false, true]) {
          final first = fromLunar(y, m, 1, leap: leap);
          // 2099's last months fall in 2100, outside toLunar's range.
          if (first == null || first.year > kLunarMaxYear) continue;
          expect(toLunar(first), LunarDate(y, m, 1, isLeap: leap));
          final last = fromLunarBackward(y, m, 30, leap: leap)!;
          if (last.year > kLunarMaxYear) continue;
          final l = toLunar(last)!;
          expect((l.year, l.month, l.isLeap), (y, m, leap));
          expect(l.day, anyOf(29, 30));
          // The day after a month's last day is the next month's first.
          expect(
            toLunar(last.add(const Duration(days: 1)))?.day,
            anyOf(1, null),
          );
        }
      }
    }
  });
  test('text', () {
    expect(lunarMonthDayText(10, 28), '十月廿八');
    expect(lunarMonthDayText(4, 8, leap: true), '闰四月初八');
    expect(lunarMonthDayText(11, 5), '冬月初五');
    expect(lunarMonthDayText(12, 20), '腊月二十');
    expect(lunarMonthDayText(1, 1), '正月初一');
    expect(lunarFullText(d(2024, 2, 10)), '甲辰年正月初一 · 春节');
  });
  test('out of range', () {
    expect(toLunar(d(1850, 1, 1)), isNull);
    expect(lunarCellLabel(d(1850, 1, 1)), isNull);
    expect(fromLunar(2150, 1, 1), isNull);
  });
}
