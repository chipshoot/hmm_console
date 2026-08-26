import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../contact_info.dart';
import '../contact_info_labels.dart';

/// Read-only rendering of one embedded contact block.
///
/// The tap actions are reported rather than launched here, so the owning
/// screen keeps whatever launch policy it already has and this widget stays
/// testable without a platform channel.
class ContactInfoView extends StatelessWidget {
  const ContactInfoView({
    super.key,
    required this.value,
    this.onCall,
    this.onEmail,
    this.onMap,
  });

  final ContactInfo value;
  final ValueChanged<String>? onCall;
  final ValueChanged<String>? onEmail;
  final ValueChanged<String>? onMap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contactRoleLabel(value.role, l),
          style: theme.textTheme.labelMedium,
        ),
        if (value.displayName.isNotEmpty)
          Text(value.displayName, style: theme.textTheme.titleMedium),
        // Only shown when it is not already the heading, so an unnamed
        // organization is not printed twice.
        if ((value.organization ?? '').isNotEmpty &&
            value.displayName != value.organization)
          Text(value.organization!, style: theme.textTheme.bodyMedium),
        _row(context, Icons.phone, value.phone, onCall, 'contactCallRow'),
        _row(context, Icons.email, value.email, onEmail, 'contactEmailRow'),
        _row(context, Icons.map, value.address, onMap, 'contactMapRow'),
        if ((value.notes ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(value.notes!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String? text,
    ValueChanged<String>? onTap,
    String keyName,
  ) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(
      key: Key(keyName),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon),
      title: Text(text),
      onTap: onTap == null ? null : () => onTap(text),
    );
  }
}
