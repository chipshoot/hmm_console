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
}) => DateGrouper(now: now, firstDayOfWeek: firstDayOfWeek).groupOf(date);

/// [dateGroupFor] with the day boundaries computed once, for grouping many
/// dates against the same [now].
class DateGrouper {
  DateGrouper({required DateTime now, required int firstDayOfWeek}) {
    final localNow = now.toLocal();
    final today = _day(localNow);
    _tomorrow = DateTime(today.year, today.month, today.day + 1);
    _today = today;
    _yesterday = DateTime(today.year, today.month, today.day - 1);
    // Dart weekday: 1 = Monday ... 7 = Sunday; `% 7` makes Sunday 0.
    final back = ((localNow.weekday % 7) - firstDayOfWeek) % 7;
    _weekStart = DateTime(today.year, today.month, today.day - back);
    _monthStart = DateTime(today.year, today.month);
  }

  late final DateTime _today, _tomorrow, _yesterday, _weekStart, _monthStart;

  NoteGroupKey groupOf(DateTime date) {
    // Day-start boundaries make "which local day" a plain instant compare.
    if (!date.isBefore(_tomorrow)) {
      final d = date.toLocal();
      return MonthGroup(d.year, d.month);
    }
    if (!date.isBefore(_today)) return const TodayGroup();
    if (!date.isBefore(_yesterday)) return const YesterdayGroup();
    if (!date.isBefore(_weekStart)) return const ThisWeekGroup();
    if (!date.isBefore(_monthStart)) return const ThisMonthGroup();
    final d = date.toLocal();
    return MonthGroup(d.year, d.month);
  }
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
