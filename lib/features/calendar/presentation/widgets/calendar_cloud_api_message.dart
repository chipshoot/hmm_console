import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';

/// Cloud API mode has no calendar yet; this is a friendly explanation, not an
/// error. Shared with the event screen.
class CalendarCloudApiMessage extends StatelessWidget {
  const CalendarCloudApiMessage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        AppLocalizations.of(context).calendarCloudApiUnavailable,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
