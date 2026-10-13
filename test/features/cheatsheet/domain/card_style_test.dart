import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';

void main() {
  group('template defaults', () {
    test('match the spec table', () {
      final claim = CardLookDefaults.of('accidentClaim');
      expect(claim.theme, CardThemeId.blue);
      expect(claim.icon, '\u{1F697}');
      expect(claim.layout, CardLayout.facts);

      final health = CardLookDefaults.of('healthInfo');
      expect(health.theme, CardThemeId.green);
      expect(health.icon, '⚕️');
      expect(health.layout, CardLayout.facts);

      final doc = CardLookDefaults.of('document');
      expect(doc.theme, CardThemeId.orange);
      expect(doc.icon, '\u{1F4D6}');
      expect(doc.layout, CardLayout.keyPoints);

      for (final id in ['blank', 'someFutureTemplate', '']) {
        final d = CardLookDefaults.of(id);
        expect(d.theme, CardThemeId.slate, reason: id);
        expect(d.icon, '\u{1F5C2}️', reason: id);
        expect(d.layout, CardLayout.facts, reason: id);
      }
    });

    test('an empty style resolves to the template look with no pattern', () {
      final look = CardStyle.empty.resolve('document');
      expect(look.theme, CardThemeId.orange);
      expect(look.pattern, CardPattern.none);
      expect(look.icon, '\u{1F4D6}');
      expect(look.layout, CardLayout.keyPoints);
    });
  });

  group('unknown values', () {
    test('an unknown theme renders the default and is kept raw', () {
      const s = CardStyle({'theme': 'turquoise', 'pattern': 'hexagons'});
      final look = s.resolve('accidentClaim');
      expect(look.theme, CardThemeId.blue);
      expect(look.pattern, CardPattern.none);
      expect(s.toMap(), {'theme': 'turquoise', 'pattern': 'hexagons'});
    });

    test('wrong-typed values render the default and are kept raw', () {
      const s = CardStyle({
        'theme': 5,
        'layout': ['x'],
        'icon': 7,
      });
      final look = s.resolve('blank');
      expect(look.theme, CardThemeId.slate);
      expect(look.layout, CardLayout.facts);
      expect(look.icon, '\u{1F5C2}️');
      expect(s.toMap(), {
        'theme': 5,
        'layout': ['x'],
        'icon': 7,
      });
    });

    test('a non-emoji icon renders the template icon and is kept raw', () {
      const s = CardStyle({'icon': 'abc'});
      expect(s.resolve('document').icon, '\u{1F4D6}');
      expect(s.icon, 'abc');
      expect(s.toMap(), {'icon': 'abc'});
    });
  });

  group('edits write only what differs from the template', () {
    test('choosing the template theme removes the key', () {
      final s = const CardStyle({
        'theme': 'red',
      }).withTheme(CardThemeId.blue, templateId: 'accidentClaim');
      expect(s.isEmpty, isTrue);
    });

    test('choosing another theme stores its name', () {
      final s = CardStyle.empty.withTheme(
        CardThemeId.purple,
        templateId: 'accidentClaim',
      );
      expect(s.toMap(), {'theme': 'purple'});
      expect(s.resolve('accidentClaim').theme, CardThemeId.purple);
    });

    test('pattern none is never stored', () {
      expect(
        const CardStyle({
          'pattern': 'dots',
        }).withPattern(CardPattern.none).isEmpty,
        isTrue,
      );
      expect(CardStyle.empty.withPattern(CardPattern.waves).toMap(), {
        'pattern': 'waves',
      });
    });

    test('the template icon and a cleared icon are not stored', () {
      expect(
        CardStyle.empty.withIcon('\u{1F4D6}', templateId: 'document').isEmpty,
        isTrue,
      );
      expect(
        const CardStyle({
          'icon': '\u{1F984}',
        }).withIcon(null, templateId: 'document').isEmpty,
        isTrue,
      );
      expect(
        CardStyle.empty.withIcon('', templateId: 'document').isEmpty,
        isTrue,
      );
      expect(
        CardStyle.empty.withIcon('\u{1F984}', templateId: 'document').toMap(),
        {'icon': '\u{1F984}'},
      );
    });

    test('the template layout is not stored', () {
      expect(
        CardStyle.empty
            .withLayout(CardLayout.keyPoints, templateId: 'document')
            .isEmpty,
        isTrue,
      );
      expect(
        CardStyle.empty
            .withLayout(CardLayout.facts, templateId: 'document')
            .toMap(),
        {'layout': 'facts'},
      );
    });

    test('cover path is set and cleared', () {
      final s = CardStyle.empty.withCoverPath('attachments/note-1/a.jpg');
      expect(s.coverPath, 'attachments/note-1/a.jpg');
      expect(s.withCoverPath(null).isEmpty, isTrue);
      expect(s.withCoverPath('').isEmpty, isTrue);
    });

    test(
      'an edit keeps unknown keys and replaces in place, preserving order',
      () {
        const s = CardStyle({
          'sparkle': {'a': 1},
          'theme': 'red',
          'z': true,
        });
        final edited = s.withTheme(
          CardThemeId.teal,
          templateId: 'accidentClaim',
        );
        expect(edited.toMap().keys.toList(), ['sparkle', 'theme', 'z']);
        expect(edited.toMap()['theme'], 'teal');
        expect(edited.toMap()['sparkle'], {'a': 1});
      },
    );

    test('toMap is a copy; the style cannot be mutated through it', () {
      const s = CardStyle({'theme': 'red'});
      s.toMap()['theme'] = 'blue';
      expect(s.toMap(), {'theme': 'red'});
    });
  });

  group('isSingleEmoji accepts one grapheme of any emoji shape', () {
    const valid = {
      'book': '\u{1F4D6}',
      'medical with VS16': '⚕️',
      'dividers with VS16': '\u{1F5C2}️',
      'skin tone': '\u{1F44D}\u{1F3FD}',
      'ZWJ family': '\u{1F468}‍\u{1F469}‍\u{1F467}',
      'skin tone + ZWJ technologist': '\u{1F469}\u{1F3FD}‍\u{1F4BB}',
      'flag': '\u{1F1E8}\u{1F1E6}',
      'keycap': '#️⃣',
      'star': '⭐',
    };
    const invalid = {
      'empty': '',
      'letter': 'a',
      'word': 'abc',
      'two emoji': '\u{1F4D6}\u{1F4D6}',
      'digit': '1',
      'Han character': '中',
      'emoji plus text': '\u{1F4D6}x',
    };
    for (final e in valid.entries) {
      test('accepts ${e.key}', () => expect(isSingleEmoji(e.value), isTrue));
    }
    for (final e in invalid.entries) {
      test('rejects ${e.key}', () => expect(isSingleEmoji(e.value), isFalse));
    }
  });

  test('equality is structural and key-order sensitive', () {
    expect(
      const CardStyle({'theme': 'red', 'pattern': 'dots'}),
      const CardStyle({'theme': 'red', 'pattern': 'dots'}),
    );
    expect(
      const CardStyle({'theme': 'red', 'pattern': 'dots'}).hashCode,
      const CardStyle({'theme': 'red', 'pattern': 'dots'}).hashCode,
    );
    expect(
      const CardStyle({'theme': 'red', 'pattern': 'dots'}),
      isNot(const CardStyle({'pattern': 'dots', 'theme': 'red'})),
    );
    expect(
      const CardStyle({
        'x': {
          'a': [1, 2],
        },
      }),
      const CardStyle({
        'x': {
          'a': [1, 2],
        },
      }),
    );
  });
}
