import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/notes/query/note_query.dart';
import 'package:hmm_console/features/notes/states/recent_searches.dart';
import 'package:shared_preferences/shared_preferences.dart';

RecentSearch _r(String text, [List<NoteToken> tokens = const []]) =>
    (text: text, tokens: tokens);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pushRecent', () {
    test('dedups and moves to the front', () {
      final out = pushRecent([_r('a'), _r('b')], _r('b'));
      expect([for (final r in out) r.text], ['b', 'a']);
    });

    test('caps at 10, dropping the oldest', () {
      var list = <RecentSearch>[];
      for (var i = 0; i < 12; i++) {
        list = pushRecent(list, _r('q$i'));
      }
      expect(list.length, kMaxRecentSearches);
      expect(list.first.text, 'q11');
      expect(list.last.text, 'q2');
    });

    test('ignores an empty search', () {
      final start = [_r('a')];
      expect(pushRecent(start, _r('   ')), start);
    });

    test('equal ignoring surrounding spaces', () {
      final out = pushRecent([_r('a'), _r('b')], _r('  b '));
      expect([for (final r in out) r.text], ['b', 'a']);
    });

    test('a tokens-only search is kept', () {
      final out = pushRecent(const [], _r('', [const TagToken(3)]));
      expect(out.length, 1);
    });
  });

  group('RecentSearchesNotifier', () {
    test('record persists and survives a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final c1 = ProviderContainer();
      await c1.read(recentSearchesProvider.future);
      await c1
          .read(recentSearchesProvider.notifier)
          .record(const NoteQuery(text: 'oil', tokens: [TagToken(7)]));
      c1.dispose();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final list = await c2.read(recentSearchesProvider.future);
      expect(list.length, 1);
      expect(list.first.text, 'oil');
      expect(list.first.tokens, [const TagToken(7)]);
    });

    test('clear empties the list', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(recentSearchesProvider.future);
      final n = c.read(recentSearchesProvider.notifier);
      await n.record(const NoteQuery(text: 'x'));
      await n.clear();
      expect(await c.read(recentSearchesProvider.future), isEmpty);
    });

    test('an unknown token round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      final raw = {'type': 'future', 'x': 1};
      final c1 = ProviderContainer();
      await c1.read(recentSearchesProvider.future);
      await c1
          .read(recentSearchesProvider.notifier)
          .record(NoteQuery(text: 'q', tokens: [NoteToken.fromJson(raw)]));
      c1.dispose();

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final list = await c2.read(recentSearchesProvider.future);
      expect(list.first.tokens.single, isA<UnknownToken>());
      expect(list.first.tokens.single.toJson(), raw);
    });
  });
}
