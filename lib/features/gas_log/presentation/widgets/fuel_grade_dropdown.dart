import 'package:flutter/material.dart';

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
    return DropdownButtonFormField<String>(
      initialValue: grades.contains(value) ? value : grades.first,
      decoration: const InputDecoration(
        labelText: 'Fuel Grade',
        border: OutlineInputBorder(),
      ),
      items: grades
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
