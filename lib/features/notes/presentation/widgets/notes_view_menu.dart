import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../query/note_query.dart';

String noteRowDensityLabel(NoteRowDensity d, AppLocalizations l) => switch (d) {
  NoteRowDensity.compact => l.notesDensityCompact,
  NoteRowDensity.standard => l.notesDensityStandard,
  NoteRowDensity.rich => l.notesDensityRich,
};

String noteSortLabel(NoteSort s, AppLocalizations l) => switch (s) {
  NoteSort.dateNewest => l.notesSortDateNewest,
  NoteSort.dateOldest => l.notesSortDateOldest,
  NoteSort.lastModified => l.notesSortLastModified,
  NoteSort.subjectAZ => l.notesSortTitle,
  NoteSort.flagColor => l.notesSortFlag,
};

bool _isApple(TargetPlatform p) =>
    p == TargetPlatform.iOS || p == TargetPlatform.macOS;

/// The list's View menu: row density and sort. A Cupertino action sheet on
/// iOS/macOS, a Material bottom sheet elsewhere. Picking a value applies it
/// and closes the menu.
Future<void> showNotesViewMenu(
  BuildContext context, {
  required NoteRowDensity density,
  required NoteSort sort,
  required ValueChanged<NoteRowDensity> onDensity,
  required ValueChanged<NoteSort> onSort,
}) {
  final l = AppLocalizations.of(context);
  if (_isApple(Theme.of(context).platform)) {
    Widget section(BuildContext ctx, String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: CupertinoTheme.of(ctx).textTheme.textStyle.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
        ),
      ),
    );
    Widget action(
      BuildContext ctx, {
      required String label,
      required bool current,
      required VoidCallback onPick,
    }) => CupertinoActionSheetAction(
      onPressed: () {
        Navigator.of(ctx).pop();
        onPick();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (current) ...[
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.check_mark, size: 18),
          ],
        ],
      ),
    );
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          section(ctx, l.notesViewRows),
          for (final d in NoteRowDensity.values)
            action(
              ctx,
              label: noteRowDensityLabel(d, l),
              current: d == density,
              onPick: () => onDensity(d),
            ),
          section(ctx, l.notesViewSort),
          for (final s in NoteSort.values)
            action(
              ctx,
              label: noteSortLabel(s, l),
              current: s == sort,
              onPick: () => onSort(s),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l.commonCancel),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              section(l.notesViewRows),
              RadioGroup<NoteRowDensity>(
                groupValue: density,
                onChanged: (d) {
                  if (d == null) return;
                  Navigator.of(ctx).pop();
                  onDensity(d);
                },
                child: Column(
                  children: [
                    for (final d in NoteRowDensity.values)
                      RadioListTile<NoteRowDensity>(
                        value: d,
                        title: Text(noteRowDensityLabel(d, l)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              section(l.notesViewSort),
              RadioGroup<NoteSort>(
                groupValue: sort,
                onChanged: (s) {
                  if (s == null) return;
                  Navigator.of(ctx).pop();
                  onSort(s);
                },
                child: Column(
                  children: [
                    for (final s in NoteSort.values)
                      RadioListTile<NoteSort>(
                        value: s,
                        title: Text(noteSortLabel(s, l)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
