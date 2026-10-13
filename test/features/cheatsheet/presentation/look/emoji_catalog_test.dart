import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/emoji_catalog.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/look_labels.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  test(
    'every entry is one emoji, unique, with English and Chinese keywords',
    () {
      final seen = <String>{};
      for (final e in EmojiCatalog.entries) {
        expect(isSingleEmoji(e.emoji), isTrue, reason: e.en.first);
        expect(seen.add(e.emoji), isTrue, reason: 'duplicate ${e.en.first}');
        expect(e.en, isNotEmpty);
        expect(e.zh, isNotEmpty);
        expect(
          e.en.every((k) => k == k.toLowerCase()),
          isTrue,
          reason: 'English keywords are stored lower-case',
        );
      }
    },
  );

  test('every group has at least six entries', () {
    for (final g in EmojiGroup.values) {
      expect(
        EmojiCatalog.inGroup(g).length,
        greaterThanOrEqualTo(6),
        reason: g.name,
      );
    }
  });

  test('search matches English keywords case-insensitively', () {
    expect(
      EmojiCatalog.search('BOOK').map((e) => e.emoji),
      containsAll(['\u{1F4D6}', '\u{1F4DA}']),
    );
    expect(
      EmojiCatalog.search('car').map((e) => e.emoji),
      contains('\u{1F697}'),
    );
  });

  test('search matches Chinese keywords', () {
    expect(EmojiCatalog.search('护照').map((e) => e.emoji), ['\u{1F6C2}']);
    expect(
      EmojiCatalog.search('汽车').map((e) => e.emoji),
      contains('\u{1F697}'),
    );
  });

  test('an empty query returns everything; nonsense returns nothing', () {
    expect(EmojiCatalog.search('  '), EmojiCatalog.entries);
    expect(EmojiCatalog.search('zzzz'), isEmpty);
  });

  for (final code in ['en', 'zh']) {
    test(
      'every theme, pattern, layout and group has a distinct $code label',
      () {
        final l = lookupAppLocalizations(Locale(code));
        Set<String> labels(Iterable<String> all) {
          final s = all.toSet();
          expect(s.every((x) => x.trim().isNotEmpty), isTrue);
          return s;
        }

        expect(
          labels(CardThemeId.values.map((t) => cheatsheetThemeLabel(t, l))),
          hasLength(CardThemeId.values.length),
        );
        expect(
          labels(CardPattern.values.map((p) => cheatsheetPatternLabel(p, l))),
          hasLength(CardPattern.values.length),
        );
        expect(
          labels(CardLayout.values.map((x) => cheatsheetLayoutLabel(x, l))),
          hasLength(CardLayout.values.length),
        );
        expect(
          labels(EmojiGroup.values.map((g) => emojiGroupLabel(g, l))),
          hasLength(EmojiGroup.values.length),
        );
      },
    );
  }
}
