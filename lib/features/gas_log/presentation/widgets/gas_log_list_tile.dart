import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/gas_log.dart';

class GasLogListTile extends StatelessWidget {
  final GasLog gasLog;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const GasLogListTile({
    super.key,
    required this.gasLog,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd().format(gasLog.date);
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
          '${gasLog.odometer.toStringAsFixed(0)} ${gasLog.odometerUnit.toLowerCase()}s',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${gasLog.fuel.toStringAsFixed(1)} ${gasLog.fuelUnit.toLowerCase()}s'
              ' \u2022 \$${gasLog.totalPrice.toStringAsFixed(2)}',
            ),
            Text(
              '$dateStr'
              '${gasLog.stationName != null ? ' \u2022 ${gasLog.stationName}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (gasLog.fuelEfficiency > 0)
              Text(
                '${gasLog.fuelEfficiency.toStringAsFixed(1)} MPG',
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
