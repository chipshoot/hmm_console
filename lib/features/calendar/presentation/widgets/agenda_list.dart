import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/holidays.dart';
import '../../states/calendar_view_state.dart';
import 'agenda_row.dart';
import 'unreadable_event_tile.dart';

/// One holiday on the selected day, ready to show.
class HolidayLine {
  const HolidayLine({
    required this.flag,
    required this.name,
    required this.offDay,
    required this.color,
    required this.range,
    required this.day,
  });

  /// Flag emoji; null for My holidays (shown with a person icon).
  final String? flag;
  final String name;
  final bool offDay;
  final Color color;

  /// Formatted block range (e.g. `Oct 1 – Oct 8`); null for a single day.
  final String? range;
  final HolidayDay day;

  bool get downloaded => day.sourceId != kMyHolidaysSourceId;
}

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
    this.lunarText,
    this.holidayLines = const [],
    this.onHolidayTap,
  });

  final DateTime day;
  final List<AgendaItem> items;
  final List<String> unreadableIds;
  final void Function(AgendaItem) onTap;
  final void Function(AgendaItem) onDone;
  final void Function(AgendaItem) onSkip;
  final void Function(AgendaItem) onMenu;

  /// Lunar date text for the header; null = off.
  final String? lunarText;

  /// The day's holidays, shown under the header.
  final List<HolidayLine> holidayLines;

  /// Tap on a downloaded holiday line (My holidays lines are not tappable).
  final void Function(HolidayLine)? onHolidayTap;

  Widget _holiday(BuildContext context, AppLocalizations l, HolidayLine h) {
    final theme = Theme.of(context);
    final status = h.offDay
        ? l.calendarHolidayDayOff
        : l.calendarHolidayWorkday;
    final text = '${h.name} · $status${h.range == null ? '' : ' (${h.range})'}';
    final tap = onHolidayTap;
    return InkWell(
      onTap: tap != null && h.downloaded ? () => tap(h) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: h.flag == null
                  ? Icon(Icons.person_outline, size: 18, color: h.color)
                  : Text(h.flag!, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(color: h.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            lunarText == null
                ? MaterialLocalizations.of(context).formatFullDate(day)
                : '${MaterialLocalizations.of(context).formatFullDate(day)}'
                      ' · $lunarText',
            style: theme.textTheme.titleSmall,
          ),
        ),
        for (final h in holidayLines) _holiday(context, l, h),
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
