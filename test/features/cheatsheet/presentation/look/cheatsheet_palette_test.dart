import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/card_style.dart';
import 'package:hmm_console/features/cheatsheet/presentation/look/cheatsheet_palette.dart';

void main() {
  test('contrastRatio matches the WCAG formula at its extremes', () {
    expect(
      contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
      closeTo(21, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFF777777), const Color(0xFF777777)),
      closeTo(1, 0.0001),
    );
  });

  for (final b in Brightness.values) {
    for (final t in CardThemeId.values) {
      test('${t.name} (${b.name}): title and subtitle meet AA, '
          'with and without the pattern ink', () {
        final c = CheatsheetPalette.of(t, b);
        // The pattern is drawn in foreground ink over the background, so text
        // may sit on either the bare colour or the inked one.
        final inked = Color.alphaBlend(c.patternInk, c.background);
        for (final bg in [c.background, inked]) {
          expect(
            contrastRatio(c.foreground, bg),
            greaterThanOrEqualTo(4.5),
            reason: 'title on ${bg.toARGB32().toRadixString(16)}',
          );
          expect(
            contrastRatio(Color.alphaBlend(c.subtitle, bg), bg),
            greaterThanOrEqualTo(4.5),
            reason: 'subtitle on ${bg.toARGB32().toRadixString(16)}',
          );
        }
      });

      test('${t.name} (${b.name}): the cover header bar meets AA', () {
        final c = CheatsheetPalette.forCover(t, b);
        expect(
          contrastRatio(c.foreground, c.background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(
            Color.alphaBlend(c.subtitle, c.background),
            c.background,
          ),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  }

  test('light and dark variants differ for every theme', () {
    for (final t in CardThemeId.values) {
      expect(
        CheatsheetPalette.of(t, Brightness.light).background,
        isNot(CheatsheetPalette.of(t, Brightness.dark).background),
        reason: t.name,
      );
    }
  });

  test('every theme has a distinct light background', () {
    final seen = {
      for (final t in CardThemeId.values)
        CheatsheetPalette.of(t, Brightness.light).background,
    };
    expect(seen, hasLength(CardThemeId.values.length));
  });
}
