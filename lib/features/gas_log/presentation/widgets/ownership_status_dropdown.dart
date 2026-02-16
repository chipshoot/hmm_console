import 'package:flutter/material.dart';

class OwnershipStatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  static const statuses = ['Owned', 'Leased', 'Financed'];

  const OwnershipStatusDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: statuses.contains(value) ? value : statuses.first,
      decoration: const InputDecoration(
        labelText: 'Ownership Status',
        border: OutlineInputBorder(),
      ),
      items: statuses
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
