import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/lunar.dart';
import '../../domain/recurrence_rule.dart';
import '../../states/event_edit_state.dart';
import 'platform_date_time_pickers.dart';
import 'repeat_description.dart';

/// "Custom repeat" / "Lunar repeat" for a rule the picker cannot edit.
String describeRuleText(String text, AppLocalizations l) {
  try {
    return describeRepeat(RecurrenceRule.parse(text), l);
  } on FormatException {
    return l.calendarRepeatCustom;
  }
}

/// Repeat: None, Daily, Weekly (weekday chips), Monthly, Yearly (on the
/// date or on its lunar date), and when it ends (never, on a date, after N
/// times). A rule outside the subset is shown in words and read-only until
/// the owner taps Clear.
class RepeatPicker extends StatelessWidget {
  const RepeatPicker({super.key, required this.form, required this.onChanged});

  final EventForm form;
  final ValueChanged<EventForm> onChanged;

  bool _apple(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;

  Widget _choice<T extends Object>(
    BuildContext context, {
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onSelected,
    required String keyPrefix,
  }) {
    if (_apple(context)) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: value,
          children: {
            for (final e in options.entries)
              e.key: Padding(
                key: Key('$keyPrefix-${e.key}'),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(e.value, maxLines: 1, overflow: TextOverflow.fade),
              ),
          },
          onValueChanged: (v) {
            if (v != null) onSelected(v);
          },
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            key: Key('$keyPrefix-${e.key}'),
            label: Text(e.value),
            selected: e.key == value,
            onSelected: (_) => onSelected(e.key),
          ),
      ],
    );
  }

  void _setFreq(RepeatFreq f) {
    var next = form.copyWith(freq: f);
    if (f == RepeatFreq.weekly && form.byDay.isEmpty) {
      next = next.copyWith(byDay: {Weekday.values[form.start.weekday - 1]});
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final custom = form.customRule;
    if (custom != null) {
      return ListTile(
        leading: const Icon(Icons.repeat),
        title: Text(describeRuleText(custom, l)),
        subtitle: Text(l.calendarRepeatReadOnlyHint),
        trailing: TextButton(
          onPressed: () => onChanged(
            form.copyWith(clearCustomRule: true, freq: RepeatFreq.none),
          ),
          child: Text(l.calendarRepeatClear),
        ),
      );
    }
    final children = <Widget>[
      _choice<RepeatFreq>(
        context,
        keyPrefix: 'calendar-repeat',
        value: form.freq,
        options: {
          RepeatFreq.none: l.calendarRepeatNone,
          RepeatFreq.daily: l.calendarRepeatDaily,
          RepeatFreq.weekly: l.calendarRepeatWeekly,
          RepeatFreq.monthly: l.calendarRepeatMonthly,
          RepeatFreq.yearly: l.calendarRepeatYearly,
        },
        onSelected: _setFreq,
      ),
    ];
    if (form.freq == RepeatFreq.weekly) {
      children.add(
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final w in Weekday.values)
              FilterChip(
                label: Text(weekdayShortName(w, l)),
                selected: form.byDay.contains(w),
                onSelected: (on) {
                  final next = {...form.byDay};
                  on ? next.add(w) : next.remove(w);
                  // A weekly repeat always has at least one day.
                  if (next.isNotEmpty) onChanged(form.copyWith(byDay: next));
                },
              ),
          ],
        ),
      );
    }
    final lunarDate = form.freq == RepeatFreq.yearly ? form.lunarDate : null;
    if (lunarDate != null) {
      children.add(
        _choice<bool>(
          context,
          keyPrefix: 'calendar-repeat-calendar',
          value: form.lunar,
          options: {
            // The series start's month/day (moved as the shown date moved):
            // what a Gregorian yearly rule saved from here expands on.
            false: l.calendarRepeatOnDate(
              DateFormat.MMMd(l.localeName).format(form.seriesDate),
            ),
            true: l.calendarRepeatOnLunarDate(
              lunarMonthDayText(
                lunarDate.month,
                lunarDate.day,
                leap: lunarDate.isLeap,
              ),
            ),
          },
          onSelected: (v) => onChanged(form.copyWith(lunar: v)),
        ),
      );
    }
    if (form.repeats) {
      children
        ..add(Text(l.calendarRepeatEndLabel))
        ..add(
          _choice<RepeatEnd>(
            context,
            keyPrefix: 'calendar-repeat-end',
            value: form.repeatEnd,
            options: {
              RepeatEnd.never: l.calendarRepeatEndNever,
              RepeatEnd.onDate: l.calendarRepeatEndOnDate,
              RepeatEnd.afterCount: l.calendarRepeatEndAfter,
            },
            onSelected: (v) => onChanged(
              form.copyWith(
                repeatEnd: v,
                until: v == RepeatEnd.onDate && form.until == null
                    ? DateTime(
                        form.start.year,
                        form.start.month + 1,
                        form.start.day,
                      )
                    : null,
              ),
            ),
          ),
        );
      if (form.repeatEnd == RepeatEnd.onDate && form.until != null) {
        children.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(DateFormat.yMMMEd(l.localeName).format(form.until!)),
            onTap: () async {
              final d = await showPlatformDatePicker(context, form.until!);
              if (d != null) onChanged(form.copyWith(until: dateOnly(d)));
            },
          ),
        );
      }
      if (form.repeatEnd == RepeatEnd.afterCount) {
        children.add(
          Row(
            children: [
              Expanded(child: Text(l.calendarRepeatCountLabel)),
              HmmIconButton(
                icon: Icons.remove,
                tooltip: l.calendarRepeatFewer,
                onPressed: form.count > 1
                    ? () => onChanged(form.copyWith(count: form.count - 1))
                    : null,
              ),
              Text('${form.count}'),
              HmmIconButton(
                icon: Icons.add,
                tooltip: l.calendarRepeatMore,
                onPressed: () =>
                    onChanged(form.copyWith(count: form.count + 1)),
              ),
            ],
          ),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: children,
      ),
    );
  }
}
