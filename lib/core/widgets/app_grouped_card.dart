import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// A rounded, filled container for grouped form/list sections (iOS Settings /
/// Mail style). Fills with the secondary grouped background and clips its child
/// so inset separators sit flush inside the rounded corners.
class AppGroupedCard extends StatelessWidget {
  const AppGroupedCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: ColoredBox(
        color: context.appColors.secondaryGroupedBackground,
        child: child,
      ),
    );
  }
}
