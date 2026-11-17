import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/calendar_event.dart';
import '../../states/calendar_view_state.dart';

/// One occurrence in the day's agenda: time, title, repeat mark and status.
/// Swipe right = done, left = skipped (the callbacks decide; the row never
/// leaves the list by itself). Long press opens the row menu.
class AgendaRow extends StatelessWidget {
  const AgendaRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDone,
    required this.onSkip,
    required this.onMenu,
  });

  final AgendaItem item;
  final VoidCallback onTap;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final e = item.event;
    final o = item.occurrence;

    final String time;
    if (o.allDay) {
      time = l.calendarAllDay;
    } else {
      final t = localTimeOf(o.start);
      time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: t.hour, minute: t.minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
    }
    final done = o.status == OccurrenceStatus.done;
    final skipped = o.status == OccurrenceStatus.skipped;
    final title = o.titleOverride ?? e.title;
    final muted = e.draft || done || skipped;

    final tile = ListTile(
      leading: SizedBox(
        width: 64,
        child: Text(
          time,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          decoration: skipped ? TextDecoration.lineThrough : null,
          color: muted ? theme.disabledColor : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (e.rrule != null)
            Icon(Icons.repeat, size: 18, semanticLabel: l.calendarRepeats),
          if (done)
            Icon(
              Icons.check,
              size: 18,
              semanticLabel: l.calendarStatusDone,
              color: theme.colorScheme.primary,
            ),
          if (skipped)
            Icon(
              Icons.remove,
              size: 18,
              semanticLabel: l.calendarStatusSkipped,
            ),
        ],
      ),
      onTap: onTap,
      onLongPress: onMenu,
    );

    Widget swipeBg(Color c, IconData i, String label, Alignment a) => Container(
      color: c,
      alignment: a,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(i, semanticLabel: label),
    );

    return Dismissible(
      key: ValueKey('${e.id}|${o.originalStart.wireKey}'),
      background: swipeBg(
        theme.colorScheme.primaryContainer,
        Icons.check,
        l.calendarMarkDone,
        Alignment.centerLeft,
      ),
      secondaryBackground: swipeBg(
        theme.colorScheme.surfaceContainerHighest,
        Icons.skip_next,
        l.calendarSkip,
        Alignment.centerRight,
      ),
      // The action runs and the row stays; the list rebuilds from the
      // repository's change stream.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onDone();
        } else {
          onSkip();
        }
        return false;
      },
      child: tile,
    );
  }
}
