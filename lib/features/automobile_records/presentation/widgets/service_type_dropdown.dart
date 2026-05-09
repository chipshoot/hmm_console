import 'package:flutter/material.dart';

import '../../domain/entities/service_type.dart';

class ServiceTypeDropdown extends StatelessWidget {
  const ServiceTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Service type',
  });

  final ServiceType value;
  final ValueChanged<ServiceType> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ServiceType>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: ServiceType.values
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.displayName),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
