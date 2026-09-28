import 'package:flutter/material.dart';

enum HmmIconButtonStyle { standard, filled, filledTonal }

/// The app's only icon button. [tooltip] is required and must be a localized
/// string: long-press shows it and screen readers announce it, so an icon is
/// never the only explanation of what a button does. A test
/// (test/core/help/icon_button_guard_test.dart) keeps raw IconButtons out.
class HmmIconButton extends StatelessWidget {
  const HmmIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount,
    this.style = HmmIconButtonStyle.standard,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Shown as a badge when 1 or more; null and 0 draw no decoration.
  final int? badgeCount;
  final HmmIconButtonStyle style;

  @override
  Widget build(BuildContext context) {
    // Checked here, not in the const constructor, which cannot call trim().
    assert(tooltip.trim().isNotEmpty, 'HmmIconButton needs a localized tooltip');
    final n = badgeCount;
    final Widget glyph = n != null && n > 0
        ? Badge(label: Text('$n'), child: Icon(icon))
        : Icon(icon);
    return switch (style) {
      HmmIconButtonStyle.standard =>
        IconButton(tooltip: tooltip, icon: glyph, onPressed: onPressed),
      HmmIconButtonStyle.filled =>
        IconButton.filled(tooltip: tooltip, icon: glyph, onPressed: onPressed),
      HmmIconButtonStyle.filledTonal => IconButton.filledTonal(
          tooltip: tooltip, icon: glyph, onPressed: onPressed),
    };
  }
}
