// The only file in the app that imports `package:lunar`. Gregorian is the
// only internal calendar; everything here converts at the edges. All inputs
// and outputs are date-only (time of day and zone are ignored).
import 'package:lunar/lunar.dart' as pkg;

const int kLunarMinYear = 1901;
const int kLunarMaxYear = 2099;

class LunarDate {
  const LunarDate(this.year, this.month, this.day, {this.isLeap = false});
  final int year, month, day;
  final bool isLeap;

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.isLeap == isLeap;

  @override
  int get hashCode => Object.hash(year, month, day, isLeap);

  @override
  String toString() => 'LunarDate($year, ${isLeap ? '闰' : ''}$month, $day)';
}

enum LunarLabelKind { festival, solarTerm, month, day }

class LunarCellLabel {
  const LunarCellLabel(this.text, this.kind);
  final String text;
  final LunarLabelKind kind;

  @override
  bool operator ==(Object other) =>
      other is LunarCellLabel && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'LunarCellLabel($text, $kind)';
}

const _monthNames = [
  '正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊', //
];

const _dayNames = [
  '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十', //
  '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
  '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十',
];

// Fixed lunar-date festivals (non-leap months only). 除夕 is handled
// separately because it is the last day of month 12.
const _festivals = {
  (1, 1): '春节',
  (1, 15): '元宵',
  (5, 5): '端午',
  (7, 7): '七夕',
  (8, 15): '中秋',
  (9, 9): '重阳',
};

bool _inRange(int year) => year >= kLunarMinYear && year <= kLunarMaxYear;

LunarDate? toLunar(DateTime date) {
  if (!_inRange(date.year)) return null;
  final l = pkg.Solar.fromYmd(date.year, date.month, date.day).getLunar();
  final m = l.getMonth();
  return LunarDate(l.getYear(), m.abs(), l.getDay(), isLeap: m < 0);
}

int? _dayCount(int year, int month, {required bool leap}) =>
    pkg.LunarMonth.fromYm(year, leap ? -month : month)?.getDayCount();

DateTime? _solarOf(int year, int month, int day, bool leap) {
  final s = pkg.Lunar.fromYmd(year, leap ? -month : month, day).getSolar();
  return DateTime.utc(s.getYear(), s.getMonth(), s.getDay());
}

DateTime? fromLunar(int year, int month, int day, {bool leap = false}) {
  if (!_inRange(year) || month < 1 || month > 12 || day < 1) return null;
  final count = _dayCount(year, month, leap: leap);
  if (count == null || day > count) return null;
  return _solarOf(year, month, day, leap);
}

DateTime? fromLunarBackward(int year, int month, int day, {bool leap = false}) {
  if (!_inRange(year) || month < 1 || month > 12 || day < 1) return null;
  var useLeap = leap;
  var count = _dayCount(year, month, leap: useLeap);
  if (count == null) {
    useLeap = false;
    count = _dayCount(year, month, leap: false);
    if (count == null) return null;
  }
  return _solarOf(year, month, day > count ? count : day, useLeap);
}

String _monthName(int month, bool leap) =>
    '${leap ? '闰' : ''}${_monthNames[month - 1]}月';

String lunarMonthDayText(int month, int day, {bool leap = false}) =>
    '${_monthName(month, leap)}${_dayNames[day - 1]}';

String? _festivalOf(pkg.Lunar l) {
  final m = l.getMonth();
  if (m < 0) return null;
  final f = _festivals[(m, l.getDay())];
  if (f != null) return f;
  if (m == 12) {
    final count = _dayCount(l.getYear(), 12, leap: false);
    if (count != null && l.getDay() == count) return '除夕';
  }
  return null;
}

LunarCellLabel? lunarCellLabel(DateTime date) {
  if (!_inRange(date.year)) return null;
  final l = pkg.Solar.fromYmd(date.year, date.month, date.day).getLunar();
  final festival = _festivalOf(l);
  if (festival != null) {
    return LunarCellLabel(festival, LunarLabelKind.festival);
  }
  final term = l.getJieQi();
  if (term.isNotEmpty) return LunarCellLabel(term, LunarLabelKind.solarTerm);
  final m = l.getMonth();
  if (l.getDay() == 1) {
    return LunarCellLabel(_monthName(m.abs(), m < 0), LunarLabelKind.month);
  }
  return LunarCellLabel(_dayNames[l.getDay() - 1], LunarLabelKind.day);
}

String? lunarFullText(DateTime date) {
  if (!_inRange(date.year)) return null;
  final l = pkg.Solar.fromYmd(date.year, date.month, date.day).getLunar();
  final m = l.getMonth();
  final base =
      '${l.getYearInGanZhi()}年${lunarMonthDayText(m.abs(), l.getDay(), leap: m < 0)}';
  final extra =
      _festivalOf(l) ?? (l.getJieQi().isNotEmpty ? l.getJieQi() : null);
  return extra == null ? base : '$base · $extra';
}
