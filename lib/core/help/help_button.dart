import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../widgets/hmm_icon_button.dart';
import 'help_registry.dart';
import 'help_sheet.dart';

/// The top-bar "?" that opens a screen's help sheet.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.helpId});
  final HelpId helpId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return HmmIconButton(
      icon: Icons.help_outline,
      tooltip: l.helpButtonTooltip,
      onPressed: () => showHelpSheet(context, helpFor(helpId, l)),
    );
  }
}
