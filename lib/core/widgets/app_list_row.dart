import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Inset (logical px) from the row's leading edge to where text starts when a
/// [AppListRow.leading] is present. [AppListSection] uses this to align its
/// separators under the text, Apple-Mail style.
const double kRowInsetWithLeading = 52.0;

/// Text inset when there is no leading widget.
const double kRowInsetNoLeading = 16.0;

/// A 3-tier list row: leading slot, a bold title, an optional bold primary
/// content line, an optional muted secondary line, and an optional trailing
/// widget (e.g. a timestamp). Direction-aware so it mirrors correctly in RTL.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    this.leading,
    required this.title,
    this.primary,
    this.secondary,
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? primary;
  final Widget? secondary;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    Widget styled(Widget child, TextStyle style) => DefaultTextStyle.merge(
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: child,
        );

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2, end: 12),
            child: SizedBox(
              width: 24,
              child: Align(alignment: AlignmentDirectional.topStart, child: leading),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: styled(title, DesignTokens.rowTitle.copyWith(color: c.label)),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    styled(trailing!, DesignTokens.caption.copyWith(color: c.tertiaryLabel)),
                  ],
                ],
              ),
              if (primary != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: styled(primary!, DesignTokens.rowPrimary.copyWith(color: c.label)),
                ),
              if (secondary != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: styled(
                      secondary!, DesignTokens.rowSecondary.copyWith(color: c.secondaryLabel)),
                ),
            ],
          ),
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 11),
            child: content,
          ),
        ),
      ),
    );
  }
}
