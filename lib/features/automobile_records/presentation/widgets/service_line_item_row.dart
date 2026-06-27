import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/line_item_type.dart';
import '../../domain/entities/part_item.dart';

/// One editable service line item: type, name, qty, unit cost, live line total,
/// and a remove button. Emits the updated [PartItem] on every change.
class ServiceLineItemRow extends StatefulWidget {
  const ServiceLineItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final PartItem item;
  final ValueChanged<PartItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<ServiceLineItemRow> createState() => _ServiceLineItemRowState();
}

class _ServiceLineItemRowState extends State<ServiceLineItemRow> {
  late final TextEditingController _name =
      TextEditingController(text: widget.item.name);
  late final TextEditingController _qty =
      TextEditingController(text: widget.item.quantity.toString());
  late final TextEditingController _unit = TextEditingController(
      text: widget.item.unitCost?.toStringAsFixed(2) ?? '');

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(widget.item.copyWith(
      name: _name.text,
      quantity: int.tryParse(_qty.text) ?? 1,
      unitCost: _unit.text.trim().isEmpty ? null : double.tryParse(_unit.text),
    ));
  }

  double get _lineTotal =>
      (double.tryParse(_unit.text) ?? 0) * (int.tryParse(_qty.text) ?? 1);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DropdownButton<LineItemType>(
            value: widget.item.type,
            onChanged: (v) => v == null
                ? null
                : widget.onChanged(widget.item.copyWith(type: v)),
            items: [
              for (final t in LineItemType.values)
                DropdownMenuItem(value: t, child: Text(t.displayName)),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              key: const Key('li-name'),
              controller: _name,
              decoration: const InputDecoration(hintText: 'Item'),
              onChanged: (_) => _emit(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: TextField(
              key: const Key('li-qty'),
              controller: _qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'Qty'),
              onChanged: (_) => setState(_emit),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              key: const Key('li-unit'),
              controller: _unit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: const InputDecoration(hintText: 'Unit'),
              onChanged: (_) => setState(_emit),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child:
                Text(_lineTotal.toStringAsFixed(2), textAlign: TextAlign.right),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
