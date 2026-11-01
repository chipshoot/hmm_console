import '../../../core/notes/note_flag.dart';
import '../../../core/util/search_normalize.dart';
import '../../contacts/domain/contact_name.dart';
import '../../contacts/domain/pinyin_transcriber.dart';
import 'note_results.dart';

/// The date bucket for [date], in the device's local time. [firstDayOfWeek]
/// follows `MaterialLocalizations.firstDayOfWeekIndex` (0 = Sunday). A future
/// date groups under its own month, never Today.
NoteGroupKey dateGroupFor(
  DateTime date, {
  required DateTime now,
  required int firstDayOfWeek,
}) {
  final d = _day(date.toLocal());
  final localNow = now.toLocal();
  final today = _day(localNow);
  if (d.isAfter(today)) return MonthGroup(d.year, d.month);
  if (d == today) return const TodayGroup();
  if (d == DateTime(today.year, today.month, today.day - 1)) {
    return const YesterdayGroup();
  }
  // Dart weekday: 1 = Monday ... 7 = Sunday; `% 7` makes Sunday 0.
  final back = ((localNow.weekday % 7) - firstDayOfWeek) % 7;
  final weekStart = DateTime(today.year, today.month, today.day - back);
  if (!d.isBefore(weekStart)) return const ThisWeekGroup();
  if (d.year == today.year && d.month == today.month) {
    return const ThisMonthGroup();
  }
  return MonthGroup(d.year, d.month);
}

DateTime _day(DateTime local) => DateTime(local.year, local.month, local.day);

/// A–Z group for a title: the folded first letter; a Han first character
/// uses its pinyin initial. Everything else (digits, symbols, emoji, empty)
/// is `#`.
LetterGroup letterGroupFor(String title, PinyinTranscriber pinyin) {
  final t = title.trimLeft();
  if (t.isEmpty) return const LetterGroup('#');
  final first = String.fromCharCode(t.runes.first);
  var letter = foldForMatch(first);
  if (ContactName.hasChinese(first)) {
    final syl = pinyin.given(first).where((s) => s.isNotEmpty);
    if (syl.isNotEmpty) letter = syl.first[0].toLowerCase();
  }
  final c = letter.isEmpty ? 0 : letter.codeUnitAt(0);
  if (letter.length == 1 && c >= 0x61 && c <= 0x7a) {
    return LetterGroup(letter.toUpperCase());
  }
  return const LetterGroup('#');
}

/// Flag group for a stored colour; an unknown value joins grey.
FlagGroup flagGroupFor(int? storedFlag) =>
    FlagGroup(NoteFlagColor.fromStored(storedFlag));
