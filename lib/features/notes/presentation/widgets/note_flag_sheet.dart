import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/notes/note_flag.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// What the flag sheet returns. A null [color] means "Clear flag"; a null
/// choice (the sheet dismissed / Cancel) means change nothing.
class NoteFlagChoice {
  const NoteFlagChoice(this.color);

  final NoteFlagColor? color;
}

/// Default (unrenamed) colour names. User-nameable flags arrive with the
/// synced settings in a later slice.
String noteFlagColorLabel(NoteFlagColor color, AppLocalizations l) =>
    switch (color) {
      NoteFlagColor.red => l.flagColorRed,
      NoteFlagColor.orange => l.flagColorOrange,
      NoteFlagColor.yellow => l.flagColorYellow,
      NoteFlagColor.green => l.flagColorGreen,
      NoteFlagColor.blue => l.flagColorBlue,
      NoteFlagColor.purple => l.flagColorPurple,
      NoteFlagColor.grey => l.flagColorGrey,
    };

bool _isApple(TargetPlatform p) =>
    p == TargetPlatform.iOS || p == TargetPlatform.macOS;

/// Pick a flag colour: a Cupertino action sheet on iOS/macOS, a Material
/// bottom sheet elsewhere. "Clear flag" appears only when [current] is set.
Future<NoteFlagChoice?> showNoteFlagSheet(
  BuildContext context, {
  NoteFlagColor? current,
}) {
  final l = AppLocalizations.of(context);
  if (_isApple(Theme.of(context).platform)) {
    return showCupertinoModalPopup<NoteFlagChoice>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l.notesFlagSheetTitle),
        actions: [
          for (final c in NoteFlagColor.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(NoteFlagChoice(c)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    c == current ? Icons.flag : Icons.flag_outlined,
                    color: c.color,
                  ),
                  const SizedBox(width: 8),
                  Text(noteFlagColorLabel(c, l)),
                ],
              ),
            ),
          if (current != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () =>
                  Navigator.of(ctx).pop(const NoteFlagChoice(null)),
              child: Text(l.notesClearFlag),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l.commonCancel),
        ),
      ),
    );
  }
  return showModalBottomSheet<NoteFlagChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      // A scrolling Column (not a lazy ListView) so all seven colours exist
      // even when the sheet is taller than the viewport.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l.notesFlagSheetTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final c in NoteFlagColor.values)
              ListTile(
                leading: Icon(
                  c == current ? Icons.flag : Icons.flag_outlined,
                  color: c.color,
                ),
                title: Text(noteFlagColorLabel(c, l)),
                selected: c == current,
                onTap: () => Navigator.of(ctx).pop(NoteFlagChoice(c)),
              ),
            if (current != null)
              ListTile(
                leading: const Icon(Icons.outlined_flag),
                title: Text(l.notesClearFlag),
                onTap: () => Navigator.of(ctx).pop(const NoteFlagChoice(null)),
              ),
          ],
        ),
      ),
    ),
  );
}
