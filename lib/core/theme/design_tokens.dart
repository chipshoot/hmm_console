import 'package:flutter/material.dart';

/// Centralized design tokens for the Hmm Console app.
///
/// Usage: reference these constants instead of hardcoding values in widgets.
/// This ensures visual consistency and makes theming changes easy.
abstract final class DesignTokens {
  // ---------------------------------------------------------------------------
  // Seed Colors
  // ---------------------------------------------------------------------------
  static const Color lightSeedColor = Colors.deepPurple;
  static const Color darkSeedColor = Colors.green;

  // ---------------------------------------------------------------------------
  // Brand / Accent Colors (hardcoded in legacy screens – migrate to colorScheme)
  // ---------------------------------------------------------------------------
  static const Color gradientStart = Color(0xFF667EEA);
  static const Color gradientEnd = Color(0xFF764BA2);
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentRed = Color(0xFFFF4757);

  // ---------------------------------------------------------------------------
  // Neutral Colors (legacy – prefer colorScheme.onSurface variants)
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color surfaceLight = Color(0xFFF8F9FA);
  static const Color surfaceHighlight = Color(0xFFE3F2FD);

  // ---------------------------------------------------------------------------
  // Spacing Scale (matches GapWidgets)
  // ---------------------------------------------------------------------------
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // ---------------------------------------------------------------------------
  // Padding
  // ---------------------------------------------------------------------------
  static const EdgeInsets screenPadding = EdgeInsets.all(spacing16);

  // ---------------------------------------------------------------------------
  // Border Radius
  // ---------------------------------------------------------------------------
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 15.0;
  static const double radiusXLarge = 20.0;
  static const double radiusCard = 28.0;

  static BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static BorderRadius borderRadiusXLarge = BorderRadius.circular(radiusXLarge);
  static BorderRadius borderRadiusCard = BorderRadius.circular(radiusCard);

  // ---------------------------------------------------------------------------
  // Font Sizes
  // ---------------------------------------------------------------------------
  static const double fontSizeCaption = 10.0;
  static const double fontSizeXSmall = 11.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeBody = 14.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeTitle = 18.0;
  static const double fontSizeIcon = 22.0;
  static const double fontSizeHeadline = 24.0;
  static const double fontSizeDisplay = 64.0;

  // ---------------------------------------------------------------------------
  // Font Weights
  // ---------------------------------------------------------------------------
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.bold;

  // ---------------------------------------------------------------------------
  // Component Sizes
  // ---------------------------------------------------------------------------
  static const double buttonMinHeight = 48.0;
  static const Size buttonMinSize = Size(double.infinity, buttonMinHeight);

  // ---------------------------------------------------------------------------
  // Elevation / Shadows
  // ---------------------------------------------------------------------------
  static const double elevationNone = 0.0;
  static const double elevationLow = 4.0;

  static List<BoxShadow> shadowLight = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------
  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
  );

  // ---------------------------------------------------------------------------
  // Bottom Navigation Bar
  // ---------------------------------------------------------------------------
  static const BottomNavigationBarType navBarType =
      BottomNavigationBarType.fixed;
  static const bool navBarShowUnselectedLabels = false;
  static const bool navBarShowSelectedLabels = false;
  static const Color navBarUnselectedColor = Colors.grey;
}
