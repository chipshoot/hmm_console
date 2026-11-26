import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';

/// One choice in [showAiChoice]; [value] null is a real option (e.g. "Default
/// provider"), distinct from the picker being dismissed.
class AiChoice<T> {
  const AiChoice(this.value, this.label);
  final T value;
  final String label;
}

/// Action sheet on iOS, dialog elsewhere. Returns null when dismissed, else
/// the chosen option (wrapped, so a null [AiChoice.value] is distinguishable).
Future<AiChoice<T>?> showAiChoice<T>(
  BuildContext context,
  List<AiChoice<T>> options,
) {
  final l = AppLocalizations.of(context);
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<AiChoice<T>>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          for (final o in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, o),
              child: Text(o.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.commonCancel),
        ),
      ),
    );
  }
  return showDialog<AiChoice<T>>(
    context: context,
    builder: (ctx) => SimpleDialog(
      children: [
        for (final o in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, o),
            child: Text(o.label),
          ),
      ],
    ),
  );
}
