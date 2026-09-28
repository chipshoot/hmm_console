import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'help_models.dart';

/// Shows [help] as a Cupertino popup on iOS and a Material bottom sheet
/// elsewhere. Capped at 80% of the screen height; longer help scrolls.
Future<void> showHelpSheet(BuildContext context, ScreenHelp help) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
  final body = ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: _HelpBody(help: help),
  );
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoPopupSurface(
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(top: false, child: body),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(child: body),
  );
}

class _HelpBody extends StatelessWidget {
  const _HelpBody({required this.help});
  final ScreenHelp help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(help.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(help.summary,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (final e in help.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(e.icon),
            title: Text(e.title),
            subtitle: Text(e.body),
          ),
        const SizedBox(height: 8),
        // An explicit way out: the iOS popup is not dismissible from
        // VoiceOver's barrier, and not everyone knows to swipe down.
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).commonClose),
          ),
        ),
      ],
    );
  }
}
