import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../states/event_edit_state.dart';

/// Asks whether an edit of a repeating event applies to the occurrence that
/// was opened or to the whole series. Null when dismissed.
Future<EditScope?> showEditScopeDialog(BuildContext context) {
  final l = AppLocalizations.of(context);
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<EditScope>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(l.calendarEditScopeTitle),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, EditScope.thisOccurrence),
            child: Text(l.calendarEditThisOccurrence),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, EditScope.all),
            child: Text(l.calendarEditAllOccurrences),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
      ),
    );
  }
  return showDialog<EditScope>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l.calendarEditScopeTitle),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, EditScope.thisOccurrence),
          child: Text(l.calendarEditThisOccurrence),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, EditScope.all),
          child: Text(l.calendarEditAllOccurrences),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
      ],
    ),
  );
}
