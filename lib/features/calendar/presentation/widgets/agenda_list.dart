import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../states/calendar_view_state.dart';
import 'agenda_row.dart';
import 'unreadable_event_tile.dart';

/// The selected day's occurrences, then a tile for each unreadable event.
class AgendaList extends StatelessWidget {
  const AgendaList({
    super.key,
    required this.day,
    required this.items,
    required this.unreadableIds,
    required this.onTap,
    required this.onDone,
    required this.onSkip,
    required this.onMenu,
  });

  final DateTime day;
  final List<AgendaItem> items;
  final List<String> unreadableIds;
  final void Function(AgendaItem) onTap;
  final void Function(AgendaItem) onDone;
  final void Function(AgendaItem) onSkip;
  final void Function(AgendaItem) onMenu;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      key: const Key('calendar-agenda'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            MaterialLocalizations.of(context).formatFullDate(day),
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l.calendarEmptyDay,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        for (final i in items)
          AgendaRow(
            item: i,
            onTap: () => onTap(i),
            onDone: () => onDone(i),
            onSkip: () => onSkip(i),
            onMenu: () => onMenu(i),
          ),
        for (final id in unreadableIds) UnreadableEventTile(eventId: id),
      ],
    );
  }
}
