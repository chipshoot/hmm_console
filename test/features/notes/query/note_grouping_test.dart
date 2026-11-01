import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/notes/note_flag.dart';
import 'package:hmm_console/features/contacts/domain/pinyin_transcriber.dart';
import 'package:hmm_console/features/notes/query/note_grouping.dart';
import 'package:hmm_console/features/notes/query/note_results.dart';

class _Fake implements PinyinTranscriber {
  @override
  List<String> given(String text) => [
    for (final r in text.runes)
      const {'张': 'zhang', '三': 'san'}[String.fromCharCode(r)] ??
          String.fromCharCode(r),
  ];
  @override
  List<String> family(String text) => given(text);
}

void main() {
  // Wed 2026-11-04 10:00 local; week starts Monday.
  final now = DateTime(2026, 11, 4, 10);
  NoteGroupKey g(DateTime d) =>
      dateGroupFor(d, now: now, firstDayOfWeek: DateTime.monday);

  test('today / yesterday / this week / this month / months', () {
    expect(g(DateTime(2026, 11, 4, 0, 0)), isA<TodayGroup>());
    expect(g(DateTime(2026, 11, 3, 23, 59)), isA<YesterdayGroup>());
    expect(g(DateTime(2026, 11, 2)), isA<ThisWeekGroup>());
    expect(g(DateTime(2026, 11, 1)), isA<ThisMonthGroup>());
    expect(g(DateTime(2026, 10, 31)), const MonthGroup(2026, 10));
  });

  test('Sunday-first week moves Sunday 1 Nov into this week', () {
    expect(
      dateGroupFor(DateTime(2026, 11, 1), now: now, firstDayOfWeek: 0),
      isA<ThisWeekGroup>(),
    );
  });

  test('future dates group under their month, not Today', () {
    expect(g(DateTime(2026, 11, 5)), const MonthGroup(2026, 11));
    expect(g(DateTime(2027, 1, 2)), const MonthGroup(2027, 1));
  });

  test('a UTC instant buckets by its local day', () {
    final local = DateTime(2026, 11, 3, 23, 30);
    expect(g(local.toUtc()), isA<YesterdayGroup>());
  });

  test('A-Z groups Han by pinyin initial and symbols under #', () {
    final fake = _Fake();
    expect(letterGroupFor('张三', fake), const LetterGroup('Z'));
    expect(letterGroupFor('7-Eleven', fake), const LetterGroup('#'));
    expect(letterGroupFor('🙂 hi', fake), const LetterGroup('#'));
    expect(letterGroupFor('', fake), const LetterGroup('#'));
    expect(letterGroupFor('élan', fake), const LetterGroup('E'));
  });

  test('unknown flag colour joins the grey group', () {
    expect(flagGroupFor(9), const FlagGroup(NoteFlagColor.grey));
    expect(flagGroupFor(0), const FlagGroup(NoteFlagColor.red));
    expect(flagGroupFor(null), const FlagGroup(null));
  });
}
