import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/activity.dart';
import '../../domain/activity_kind.dart';
import '../activity_summary.dart';

/// One entry: kind icon, summary, the recorded start time and a draft mark.
/// Tap opens it; long press opens the row menu; swiping left asks to delete
/// (the callback decides; the row never leaves the list by itself).
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.activity,
    required this.kinds,
    required this.onTap,
    required this.onMenu,
    required this.onDelete,
    this.noteTitle,
  });

  final Activity activity;
  final ActivityKindRegistry kinds;
  final String? noteTitle;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = activity;
    // The wall clock the entry was recorded with, matching its day header.
    final w = a.start.wall;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: w.hour, minute: w.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    final tile = ListTile(
      leading: Icon(kinds.byId(a.kind)?.icon ?? Icons.more_horiz),
      title: Text(
        activitySummary(a, kinds, l, noteTitle: noteTitle),
        style: a.draft ? TextStyle(color: theme.disabledColor) : null,
      ),
      subtitle: a.draft ? Text(l.activityDraftLabel) : null,
      trailing: Text(
        time,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
      onLongPress: onMenu,
    );

    return Dismissible(
      key: ValueKey('activity-row-${a.id}'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.delete_outline,
          semanticLabel: l.commonDelete,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      // The delete runs and the list rebuilds from the repository's change
      // stream, so Undo can bring the row back.
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: tile,
    );
  }
}
