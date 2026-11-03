import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';

bool _isApple(TargetPlatform p) =>
    p == TargetPlatform.iOS || p == TargetPlatform.macOS;

/// Asks for a saved search's name, prefilled with [initial]. Resolves to the
/// trimmed name, or null when cancelled. Save is disabled while the name is
/// blank. A Cupertino alert on iOS/macOS, a Material dialog elsewhere.
Future<String?> showSavedSearchNameDialog(
  BuildContext context, {
  required String title,
  required String initial,
}) => _isApple(Theme.of(context).platform)
    ? showCupertinoDialog<String>(
        context: context,
        builder: (_) =>
            _NameDialog(title: title, initial: initial, apple: true),
      )
    : showDialog<String>(
        context: context,
        builder: (_) =>
            _NameDialog(title: title, initial: initial, apple: false),
      );

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.apple,
  });

  final String title;
  final String initial;
  final bool apple;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void save() => Navigator.of(context).pop(_controller.text.trim());
    void cancel() => Navigator.of(context).pop();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final canSave = value.text.trim().isNotEmpty;
        if (widget.apple) {
          return CupertinoAlertDialog(
            title: Text(widget.title),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoTextField(
                controller: _controller,
                placeholder: l.notesSaveSearchNameLabel,
                autofocus: true,
                onSubmitted: (_) {
                  if (canSave) save();
                },
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: cancel,
                child: Text(l.commonCancel),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: canSave ? save : null,
                child: Text(l.notesSaveSearchSave),
              ),
            ],
          );
        }
        return AlertDialog(
          title: Text(widget.title),
          content: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l.notesSaveSearchNameLabel),
            onSubmitted: (_) {
              if (canSave) save();
            },
          ),
          actions: [
            TextButton(onPressed: cancel, child: Text(l.commonCancel)),
            TextButton(
              onPressed: canSave ? save : null,
              child: Text(l.notesSaveSearchSave),
            ),
          ],
        );
      },
    );
  }
}

enum SavedSearchAction { rename, moveUp, moveDown, delete }

/// The long-press menu of a saved search. Move up / down are left out at the
/// ends of the list. A Cupertino action sheet on iOS/macOS, a Material bottom
/// sheet elsewhere; resolves to null when dismissed.
Future<SavedSearchAction?> showSavedSearchMenu(
  BuildContext context, {
  required bool canMoveUp,
  required bool canMoveDown,
}) {
  final l = AppLocalizations.of(context);
  final entries = <(SavedSearchAction, String, IconData)>[
    (SavedSearchAction.rename, l.notesSavedSearchRename, Icons.edit_outlined),
    if (canMoveUp)
      (SavedSearchAction.moveUp, l.notesSavedSearchMoveUp, Icons.arrow_upward),
    if (canMoveDown)
      (
        SavedSearchAction.moveDown,
        l.notesSavedSearchMoveDown,
        Icons.arrow_downward,
      ),
    (SavedSearchAction.delete, l.notesSavedSearchDelete, Icons.delete_outline),
  ];
  if (_isApple(Theme.of(context).platform)) {
    return showCupertinoModalPopup<SavedSearchAction>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          for (final (action, label, _) in entries)
            CupertinoActionSheetAction(
              isDestructiveAction: action == SavedSearchAction.delete,
              onPressed: () => Navigator.of(ctx).pop(action),
              child: Text(label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l.commonCancel),
        ),
      ),
    );
  }
  return showModalBottomSheet<SavedSearchAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (action, label, icon) in entries)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.of(ctx).pop(action),
            ),
        ],
      ),
    ),
  );
}
