import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';

bool _isApple(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

Future<DateTime?> _cupertino(
  BuildContext context,
  DateTime initial,
  CupertinoDatePickerMode mode,
) async {
  final l = AppLocalizations.of(context);
  var picked = initial;
  var done = false;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => Container(
      height: 300,
      color: CupertinoColors.systemBackground.resolveFrom(ctx),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                child: Text(l.calendarPickerDone),
                onPressed: () {
                  done = true;
                  Navigator.of(ctx).pop();
                },
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: mode,
                initialDateTime: initial,
                use24hFormat: MediaQuery.alwaysUse24HourFormatOf(ctx),
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return done ? picked : null;
}

/// A date (time of day kept from [initial]): Cupertino wheel on Apple
/// platforms, the Material calendar elsewhere. Null when cancelled.
Future<DateTime?> showPlatformDatePicker(
  BuildContext context,
  DateTime initial,
) async {
  if (_isApple(context)) {
    return _cupertino(context, initial, CupertinoDatePickerMode.date);
  }
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day, initial.hour, initial.minute);
}

/// A time of day on [initial]'s date: Cupertino wheel on Apple platforms,
/// the Material clock elsewhere. Null when cancelled.
Future<DateTime?> showPlatformTimePicker(
  BuildContext context,
  DateTime initial,
) async {
  if (_isApple(context)) {
    return _cupertino(context, initial, CupertinoDatePickerMode.time);
  }
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (t == null) return null;
  return DateTime(initial.year, initial.month, initial.day, t.hour, t.minute);
}
