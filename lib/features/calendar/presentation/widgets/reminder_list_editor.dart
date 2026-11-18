import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/hmm_icon_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/calendar_event.dart';

/// Minutes-before choices offered when adding a reminder.
const kReminderChoices = [0, 5, 10, 15, 30, 60, 120, 1440, 2880];

/// "15 minutes before", "1 hour before", "At the start".
String reminderLabel(int minutesBefore, AppLocalizations l) {
  if (minutesBefore <= 0) return l.calendarReminderAtStart;
  if (minutesBefore % 1440 == 0) {
    return l.calendarReminderDays(minutesBefore ~/ 1440);
  }
  if (minutesBefore % 60 == 0) {
    return l.calendarReminderHours(minutesBefore ~/ 60);
  }
  return l.calendarReminderMinutes(minutesBefore);
}

/// The editor's reminders: one row per reminder with a remove button, and an
/// Add reminder row. Reminders on other channels are listed and kept too.
class ReminderListEditor extends StatelessWidget {
  const ReminderListEditor({
    super.key,
    required this.reminders,
    required this.onChanged,
  });

  final List<Reminder> reminders;
  final ValueChanged<List<Reminder>> onChanged;

  Future<int?> _pick(BuildContext context) {
    final l = AppLocalizations.of(context);
    final taken = {
      for (final r in reminders)
        if (r.channel == ReminderChannel.device) r.minutesBefore,
    };
    final choices = [
      for (final c in kReminderChoices)
        if (!taken.contains(c)) c,
    ];
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return showCupertinoModalPopup<int>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(l.calendarAddReminder),
          actions: [
            for (final c in choices)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, c),
                child: Text(reminderLabel(c, l)),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
        ),
      );
    }
    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in choices)
              ListTile(
                title: Text(reminderLabel(c, l)),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reminders.isEmpty)
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(l.calendarNoReminders),
          ),
        for (var i = 0; i < reminders.length; i++)
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(reminderLabel(reminders[i].minutesBefore, l)),
            trailing: HmmIconButton(
              icon: Icons.remove_circle_outline,
              tooltip: l.calendarRemoveReminder,
              onPressed: () => onChanged([...reminders]..removeAt(i)),
            ),
          ),
        ListTile(
          key: const Key('calendar-edit-add-reminder'),
          leading: const Icon(Icons.add_alert_outlined),
          title: Text(l.calendarAddReminder),
          onTap: () async {
            final m = await _pick(context);
            if (m == null) return;
            final next = [...reminders, Reminder(minutesBefore: m)]
              ..sort((a, b) => a.minutesBefore - b.minutesBefore);
            onChanged(next);
          },
        ),
      ],
    );
  }
}
