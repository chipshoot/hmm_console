import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Runs [run] now and reports the outcome in a snackbar; on success the
/// snackbar offers Undo, which runs [undo]. Four outcomes, four messages:
/// [done], [failed], [undone], [undoFailed] — never one message for several
/// states. [onChanged] (e.g. reload a list) runs only after a success.
///
/// The snackbar outlives the calling screen, so everything it needs is
/// captured before the first await; [undo] and [onChanged] must not use the
/// caller's WidgetRef or BuildContext (capture a ProviderContainer instead).
Future<void> showUndoableAction(
  BuildContext context, {
  required Future<void> Function() run,
  required Future<void> Function() undo,
  required String done,
  required String failed,
  required String undone,
  required String undoFailed,
  VoidCallback? onChanged,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final undoLabel = AppLocalizations.of(context).undoAction;

  void say(String text, {SnackBarAction? action}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: action,
        // Flutter keeps a snackbar with an action up until dismissed unless
        // told otherwise; Undo is a short window, not a dialog.
        persist: false,
        duration: const Duration(seconds: 5),
      ));
  }

  Future<void> runUndo() async {
    try {
      await undo();
    } catch (e, st) {
      debugPrint('undo failed: $e\n$st');
      say(undoFailed);
      return;
    }
    onChanged?.call();
    say(undone);
  }

  try {
    await run();
  } catch (e, st) {
    debugPrint('undoable action failed: $e\n$st');
    say(failed);
    return;
  }
  onChanged?.call();
  say(done,
      action: SnackBarAction(
          label: undoLabel, onPressed: () => unawaited(runUndo())));
}
