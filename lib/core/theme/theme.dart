import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'design_tokens.dart';

class AppTheme {
  static bool get _isApplePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static TextTheme _textTheme(AppColors c) => TextTheme(
        titleLarge: DesignTokens.titleLarge.copyWith(color: c.label),
        headlineMedium: DesignTokens.titleLarge.copyWith(color: c.label),
        headlineSmall: DesignTokens.titleLarge.copyWith(color: c.label),
        titleSmall: DesignTokens.rowTitle.copyWith(color: c.label),
        titleMedium: DesignTokens.rowTitle.copyWith(color: c.label),
        bodyLarge: DesignTokens.rowPrimary.copyWith(color: c.label),
        bodyMedium: DesignTokens.rowSecondary.copyWith(color: c.secondaryLabel),
        bodySmall: DesignTokens.caption.copyWith(color: c.tertiaryLabel),
      );

  static ThemeData _build(Brightness brightness, AppColors c) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness),
      extensions: [c],
      textTheme: _textTheme(c),
      scaffoldBackgroundColor: c.groupedBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: c.groupedBackground,
        centerTitle: _isApplePlatform,
        elevation: _isApplePlatform ? 0 : null,
        scrolledUnderElevation: _isApplePlatform ? 0.5 : null,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.accent),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static final ThemeData lightThemeData =
      _build(Brightness.light, AppColors.light);

  static final ThemeData darkThemeData =
      _build(Brightness.dark, AppColors.dark);
}
