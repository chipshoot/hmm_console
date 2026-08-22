import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'option_labels.dart';

class EngineTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  static const types = [
    'Gasoline',
    'Diesel',
    'Hybrid',
    'PlugInHybrid',
    'Electric',
    'Hydrogen',
    'CNG',
  ];

  const EngineTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      initialValue: types.contains(value) ? value : types.first,
      decoration: InputDecoration(
        labelText: l.engineTypeLabel,
        border: const OutlineInputBorder(),
      ),
      // `value:` stays the persisted literal; only the child is
      // translated. See option_labels.dart.
      items: types
          .map((t) =>
              DropdownMenuItem(value: t, child: Text(optionLabel(t, l))))
          .toList(),
      onChanged: onChanged,
    );
  }
}
