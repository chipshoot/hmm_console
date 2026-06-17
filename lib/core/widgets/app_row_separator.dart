import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_list_row.dart';

/// The hairline separator used between rows in a list, inset to align under the
/// row text (Apple-Mail style). Shared by [AppListSection] (box layout) and any
/// lazy `SliverList` that interleaves rows with separators.
class AppRowSeparator extends StatelessWidget {
  const AppRowSeparator({super.key, this.indent = kRowInsetWithLeading});

  /// Start inset. Use [kRowInsetWithLeading] for rows with a leading widget,
  /// [kRowInsetNoLeading] for rows without one.
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: indent,
      color: context.appColors.separator,
    );
  }
}
