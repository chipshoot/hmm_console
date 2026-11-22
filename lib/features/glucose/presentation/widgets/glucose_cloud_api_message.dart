import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';

/// Cloud API mode has no glucose log yet; a friendly explanation, not an
/// error.
class GlucoseCloudApiMessage extends StatelessWidget {
  const GlucoseCloudApiMessage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        AppLocalizations.of(context).glucoseCloudApiUnavailable,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
