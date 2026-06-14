import 'package:flutter/material.dart';

/// Semantic, brightness-adaptive colors for text hierarchy, separators, and
/// the grouped background. Resolved via `Theme.of(context).extension<AppColors>()`
/// (or the `context.appColors` shortcut). Values mirror the iOS system palette.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.groupedBackground,
    required this.accent,
  });

  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color groupedBackground;
  final Color accent;

  static const AppColors light = AppColors(
    label: Color(0xFF1C1C1E),
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFFAEAEB2),
    separator: Color(0xFFE5E5EA),
    groupedBackground: Color(0xFFF2F2F7),
    accent: Color(0xFF0A84FF),
  );

  static const AppColors dark = AppColors(
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFF636366),
    separator: Color(0xFF38383A),
    // Pure black (OLED-friendly), intentionally deeper than iOS's
    // systemGroupedBackground (#1C1C1E) for a truer dark surface.
    groupedBackground: Color(0xFF000000),
    accent: Color(0xFF0A84FF),
  );

  @override
  AppColors copyWith({
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? separator,
    Color? groupedBackground,
    Color? accent,
  }) {
    return AppColors(
      label: label ?? this.label,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
      separator: separator ?? this.separator,
      groupedBackground: groupedBackground ?? this.groupedBackground,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      groupedBackground:
          Color.lerp(groupedBackground, other.groupedBackground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  /// Shortcut for the registered [AppColors] extension. Asserts it is present.
  AppColors get appColors {
    final c = Theme.of(this).extension<AppColors>();
    assert(c != null, 'AppColors extension not registered on the theme');
    return c ?? AppColors.light;
  }
}
