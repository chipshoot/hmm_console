import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'option_labels.dart';

class OwnershipStatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  static const statuses = ['Owned', 'Financed', 'Leased', 'Company'];

  const OwnershipStatusDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      initialValue: statuses.contains(value) ? value : statuses.first,
      decoration: InputDecoration(
        labelText: l.ownershipStatusLabel,
        border: const OutlineInputBorder(),
      ),
      // `value:` stays the persisted literal; only the child is
      // translated. See option_labels.dart.
      items: statuses
          .map((s) =>
              DropdownMenuItem(value: s, child: Text(optionLabel(s, l))))
          .toList(),
      onChanged: onChanged,
    );
  }
}
