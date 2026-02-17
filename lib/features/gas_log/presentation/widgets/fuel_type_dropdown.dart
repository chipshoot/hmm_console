import 'package:flutter/material.dart';

class FuelTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  static const types = [
    'Regular',
    'MidGrade',
    'Premium',
    'Diesel',
    'E85',
    'Electric',
    'Other',
  ];

  const FuelTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: types.contains(value) ? value : types.first,
      decoration: const InputDecoration(
        labelText: 'Fuel Type',
        border: OutlineInputBorder(),
      ),
      items: types
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
