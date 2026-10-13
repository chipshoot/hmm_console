import 'dart:ui' show Brightness, Color;

import '../../domain/entities/card_style.dart';

/// Pattern strokes are the foreground colour at this opacity. The AA test
/// composites it over the background, so raising it needs that test green.
const double kPatternInkOpacity = 0.10;

/// Subtitle text is the foreground colour at this opacity.
const double kCardSubtitleOpacity = 0.90;

/// How much black darkens the theme colour behind white text on a card with
/// a cover (the detail app bar). 0.5 keeps amber's white text at AA.
const double kCoverScrimOpacity = 0.50;

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);

/// Background plus the text colour derived from it. Text colour is never
/// user-chosen: it comes with the variant.
class CardColors {
  const CardColors({
    required this.background,
    required this.foreground,
    this.subtitleOpacity = kCardSubtitleOpacity,
  });

  final Color background;
  final Color foreground;
  final double subtitleOpacity;

  Color get subtitle => foreground.withValues(alpha: subtitleOpacity);
  Color get patternInk => foreground.withValues(alpha: kPatternInkOpacity);
}

/// The twelve themes, each with a light and a dark variant whose text meets
/// WCAG AA (pinned by `cheatsheet_palette_test.dart`).
class CheatsheetPalette {
  const CheatsheetPalette._();

  static CardColors of(CardThemeId id, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final (Color light, Color night, Color fg) = switch (id) {
      CardThemeId.blue => (
        const Color(0xFF1258A8),
        const Color(0xFF0D47A1),
        _white,
      ),
      CardThemeId.green => (
        const Color(0xFF1E6B24),
        const Color(0xFF1B5E20),
        _white,
      ),
      CardThemeId.orange => (
        const Color(0xFFA8380A),
        const Color(0xFF8A2E0E),
        _white,
      ),
      CardThemeId.red => (
        const Color(0xFFB71C1C),
        const Color(0xFF8E1B1B),
        _white,
      ),
      CardThemeId.purple => (
        const Color(0xFF6A1B9A),
        const Color(0xFF4A148C),
        _white,
      ),
      CardThemeId.teal => (
        const Color(0xFF00695C),
        const Color(0xFF004D40),
        _white,
      ),
      CardThemeId.pink => (
        const Color(0xFFAD1457),
        const Color(0xFF880E4F),
        _white,
      ),
      CardThemeId.amber => (
        const Color(0xFFFFC107),
        const Color(0xFFC79500),
        _black,
      ),
      CardThemeId.slate => (
        const Color(0xFF475569),
        const Color(0xFF334155),
        _white,
      ),
      CardThemeId.indigo => (
        const Color(0xFF3949AB),
        const Color(0xFF283593),
        _white,
      ),
      CardThemeId.brown => (
        const Color(0xFF6D4C41),
        const Color(0xFF4E342E),
        _white,
      ),
      CardThemeId.black => (
        const Color(0xFF212121),
        const Color(0xFF2A2A2A),
        _white,
      ),
    };
    return CardColors(background: dark ? night : light, foreground: fg);
  }

  /// The app bar over a card that has a cover: the theme darkened, with white
  /// text, so the bar reads the same whether or not the photo loads.
  static CardColors forCover(CardThemeId id, Brightness brightness) =>
      CardColors(
        background: Color.alphaBlend(
          _black.withValues(alpha: kCoverScrimOpacity),
          of(id, brightness).background,
        ),
        foreground: _white,
      );
}

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
