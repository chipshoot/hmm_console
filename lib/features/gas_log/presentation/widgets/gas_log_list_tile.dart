import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/gas_log_display_model.dart';

class GasLogListTile extends StatelessWidget {
  final GasLogDisplayModel displayModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const GasLogListTile({
    super.key,
    required this.displayModel,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd().format(displayModel.date);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(Icons.local_gas_station,
              color: colorScheme.onPrimaryContainer),
        ),
        title: Text(
          '${displayModel.odometer.toStringAsFixed(0)} ${displayModel.distanceLabel}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${displayModel.fuel.toStringAsFixed(1)} ${displayModel.fuelLabel}'
              ' \u2022 ${displayModel.currencySymbol}${displayModel.totalPrice.toStringAsFixed(2)}',
            ),
            Text(
              '$dateStr'
              '${displayModel.stationName != null ? ' \u2022 ${displayModel.stationName}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (displayModel.fuelEfficiency > 0)
              Text(
                '${displayModel.fuelEfficiency.toStringAsFixed(1)} ${displayModel.distanceLabel}/${displayModel.fuelLabel}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                onPressed: onDelete,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
