import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Keys of undoable actions whose `run` has not finished yet.
final _running = <Object>{};

/// Runs [run] now and reports the outcome in a snackbar; on success the
/// snackbar offers Undo, which runs [undo]. Four outcomes, four messages:
/// [done], [failed], [undone], [undoFailed] — never one message for several
/// states. [onChanged] (e.g. reload a list) runs only after a success.
///
/// [busyKey] identifies the action (e.g. `('detach', noteId)`): while one
/// with the same key is still running, further calls are ignored, so a
/// double-tap does not write twice. A new action replaces the previous
/// snackbar, so starting a second action ends the first one's Undo window —
/// the item stays where the first action put it (help text says how to
/// reverse it by hand).
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
  Object? busyKey,
}) async {
  if (busyKey != null && !_running.add(busyKey)) return;
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
  } finally {
    if (busyKey != null) _running.remove(busyKey);
  }
  onChanged?.call();
  say(done,
      action: SnackBarAction(
          label: undoLabel, onPressed: () => unawaited(runUndo())));
}
