import 'package:flutter/material.dart';

import '../../domain/entities/automobile.dart';

class ManageableAutomobileTile extends StatelessWidget {
  final Automobile automobile;
  final String distanceLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;

  const ManageableAutomobileTile({
    super.key,
    required this.automobile,
    this.distanceLabel = 'mi',
    this.onEdit,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isInactive = !automobile.isActive;

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
              Icons.directions_car,
              color: isInactive
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSecondaryContainer,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  automobile.displayName,
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
          subtitle: Text(
            [
              if (automobile.vin != null && automobile.vin!.length >= 6)
                'VIN ...${automobile.vin!.substring(automobile.vin!.length - 6)}',
              if (automobile.engineType != null &&
                  automobile.engineType!.isNotEmpty)
                automobile.engineType!,
              '${automobile.meterReading} $distanceLabel',
            ].join(' \u2022 '),
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
