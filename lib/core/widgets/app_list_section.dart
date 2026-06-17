import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import 'app_list_row.dart';
import 'app_row_separator.dart';

/// A grouped list section, Apple-Mail style: an optional uppercase header label
/// followed by [children] separated by hairline dividers inset to align under
/// the row text. No divider after the last child.
class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    this.header,
    required this.children,
    this.separatorIndent = kRowInsetWithLeading,
  });

  final String? header;
  final List<Widget> children;

  /// Start inset for the dividers. Defaults to the leading-aware row inset so
  /// separators line up under the text. Pass [kRowInsetNoLeading] for rows
  /// without a leading widget.
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(AppRowSeparator(indent: separatorIndent));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 6),
            child: Text(
              header!.toUpperCase(),
              style: DesignTokens.caption.copyWith(
                color: c.secondaryLabel,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ...rows,
      ],
    );
  }
}
