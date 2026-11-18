import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';

/// Stands in for an event note that could not be decoded, so the rest of the
/// calendar still shows. Shared with the event screen.
class UnreadableEventTile extends StatelessWidget {
  const UnreadableEventTile({super.key, required this.eventId, this.onTap});

  final String eventId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(
        Icons.warning_amber_rounded,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(l.calendarUnreadableEvent),
      subtitle: Text(l.calendarUnreadableEventHint),
      onTap: onTap,
    );
  }
}
