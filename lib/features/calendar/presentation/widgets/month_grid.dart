import 'package:flutter/material.dart';

import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/lunar.dart';

/// A compact month: header with previous/next, weekday initials, day cells
/// with a dot under days that have events. The first weekday follows the
/// locale. Takes everything as parameters (no providers).
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.eventDays,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
    this.lunarLabels,
  });

  /// Any date in the month shown.
  final DateTime month;
  final DateTime selected;
  final DateTime today;

  /// Day-of-month numbers that have events.
  final Set<int> eventDays;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Lunar label per day of month; null = lunar display off.
  final Map<int, LunarCellLabel>? lunarLabels;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final m = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstIdx = m.firstDayOfWeekIndex; // 0 = Sunday
    final lead = (first.weekday % 7 - firstIdx + 7) % 7;
    final rows = ((lead + daysInMonth) / 7).ceil();

    final lunar = lunarLabels;
    final cellHeight = lunar == null ? 44.0 : 56.0;

    Widget cell(int? day) {
      if (day == null) return SizedBox(height: cellHeight);
      final date = DateTime(month.year, month.month, day);
      final isSel = date == selected;
      final isToday = date == today;
      return InkWell(
        key: Key('calendar-day-$day'),
        customBorder: const CircleBorder(),
        onTap: () => onSelect(date),
        child: SizedBox(
          height: cellHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSel ? theme.colorScheme.primary : null,
                    border: isToday && !isSel
                        ? Border.all(color: theme.colorScheme.primary)
                        : null,
                  ),
                  child: Text(
                    m.formatDecimal(day),
                    style: TextStyle(
                      color: isSel ? theme.colorScheme.onPrimary : null,
                    ),
                  ),
                ),
                if (lunar != null)
                  SizedBox(
                    height: 12,
                    child: lunar[day] == null
                        ? null
                        : Text(
                            lunar[day]!.text,
                            key: Key('calendar-lunar-$day'),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              height: 1.2,
                              color:
                                  lunar[day]!.kind == LunarLabelKind.festival ||
                                      lunar[day]!.kind ==
                                          LunarLabelKind.solarTerm
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                SizedBox(
                  height: 6,
                  child: eventDays.contains(day)
                      ? Container(
                          key: Key('calendar-dot-$day'),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      key: const Key('calendar-month-grid'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            HmmIconButton(
              icon: Icons.chevron_left,
              tooltip: l.calendarPreviousMonth,
              onPressed: onPrevious,
            ),
            Expanded(
              child: Text(
                m.formatMonthYear(first),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            HmmIconButton(
              icon: Icons.chevron_right,
              tooltip: l.calendarNextMonth,
              onPressed: onNext,
            ),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    m.narrowWeekdays[(firstIdx + i) % 7],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: cell(() {
                    final d = r * 7 + c - lead + 1;
                    return d >= 1 && d <= daysInMonth ? d : null;
                  }()),
                ),
            ],
          ),
      ],
    );
  }
}
