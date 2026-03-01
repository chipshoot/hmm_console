import 'package:flutter/material.dart';

import '../../domain/entities/gas_station.dart';

class ManageableGasStationTile extends StatelessWidget {
  final GasStation station;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;

  const ManageableGasStationTile({
    super.key,
    required this.station,
    this.onEdit,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isInactive = !station.isActive;

    final location = [
      if (station.city != null) station.city!,
      if (station.state != null) station.state!,
      if (station.country != null) station.country!,
    ].join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Opacity(
        opacity: isInactive ? 0.5 : 1.0,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isInactive
                ? colorScheme.surfaceContainerHighest
                : colorScheme.secondaryContainer,
            child: Icon(
              Icons.local_gas_station,
              color: isInactive
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSecondaryContainer,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  station.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (isInactive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (location.isNotEmpty) Text(location),
              if (station.address != null && station.address!.isNotEmpty)
                Text(
                  station.address!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              IconButton(
                icon: Icon(
                  isInactive
                      ? Icons.toggle_off_outlined
                      : Icons.toggle_on_outlined,
                  color: isInactive ? colorScheme.error : colorScheme.primary,
                ),
                tooltip: isInactive ? 'Reactivate' : 'Deactivate',
                onPressed: onToggleActive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
