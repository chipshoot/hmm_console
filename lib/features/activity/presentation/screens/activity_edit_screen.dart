import 'package:flutter/material.dart';

import '../../../../core/help/help_button.dart';
import '../../../../core/help/help_registry.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// Placeholder for the activity form (replaced by the real form next).
class ActivityEditScreen extends StatelessWidget {
  const ActivityEditScreen({super.key, this.activityId});

  /// Null for a new activity.
  final String? activityId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.activityLogAction),
        actions: const [HelpButton(helpId: HelpId.activityEdit)],
      ),
    );
  }
}
