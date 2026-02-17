import 'package:flutter/material.dart';

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
    return DropdownButtonFormField<String>(
      initialValue: types.contains(value) ? value : types.first,
      decoration: const InputDecoration(
        labelText: 'Engine Type',
        border: OutlineInputBorder(),
      ),
      items: types
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
