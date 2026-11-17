import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../states/open_system_settings.dart';

/// Shown on the calendar home while reminders are due on this device but the
/// notification permission was declined. Offers "Open Settings" where the
/// platform can open the app's settings page.
class PermissionBanner extends ConsumerWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final open = ref.watch(openSystemSettingsProvider);
    return MaterialBanner(
      content: Text(l.calendarPermissionBanner),
      leading: const Icon(Icons.notifications_off_outlined),
      actions: [
        if (open != null)
          TextButton(
            onPressed: () => open(),
            child: Text(l.calendarOpenSettings),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
