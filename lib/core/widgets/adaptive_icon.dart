import 'package:flutter/material.dart';

/// Picks the Apple glyph (CupertinoIcons, SF Symbols style) on iOS/macOS and
/// the Material one elsewhere.
IconData adaptiveIcon(
  BuildContext context, {
  required IconData material,
  required IconData apple,
}) => switch (Theme.of(context).platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => apple,
  _ => material,
};
