import 'package:flutter/material.dart';

import '../../domain/entities/automobile.dart';

class AutomobileListTile extends StatelessWidget {
  final Automobile automobile;
  final String distanceLabel;
  final VoidCallback? onTap;

  const AutomobileListTile({
    super.key,
    required this.automobile,
    this.distanceLabel = 'mi',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(Icons.directions_car,
              color: colorScheme.onSecondaryContainer),
        ),
        title: Text(
          automobile.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            if (automobile.plate != null && automobile.plate!.isNotEmpty)
              automobile.plate!,
            if (automobile.color != null && automobile.color!.isNotEmpty)
              automobile.color!,
            '${automobile.meterReading} $distanceLabel',
          ].join(' \u2022 '),
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
