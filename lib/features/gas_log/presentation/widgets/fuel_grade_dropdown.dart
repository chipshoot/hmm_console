import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import 'option_labels.dart';

class FuelGradeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  static const grades = ['Regular', 'MidGrade', 'Premium', 'Diesel'];

  const FuelGradeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      initialValue: grades.contains(value) ? value : grades.first,
      decoration: InputDecoration(
        labelText: l.fuelGradeLabel,
        border: const OutlineInputBorder(),
      ),
      // `value:` stays the persisted literal; only the child is
      // translated. See option_labels.dart.
      items: grades
          .map((g) =>
              DropdownMenuItem(value: g, child: Text(optionLabel(g, l))))
          .toList(),
      onChanged: onChanged,
    );
  }
}
