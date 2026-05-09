import 'package:flutter/material.dart';

/// Tappable field with optional date value + a clear button. Mirrors the
/// `_optionalDatePicker` helper used inside automobile_edit_screen so the
/// new record screens have the same look & feel.
class OptionalDatePicker extends StatelessWidget {
  const OptionalDatePicker({
    super.key,
    required this.label,
    required this.date,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (date != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                ),
              const Icon(Icons.calendar_today),
              const SizedBox(width: 12),
            ],
          ),
        ),
        child: Text(
          date != null
              ? '${date!.month}/${date!.day}/${date!.year}'
              : 'Not set',
          style: TextStyle(
            color: date != null
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
