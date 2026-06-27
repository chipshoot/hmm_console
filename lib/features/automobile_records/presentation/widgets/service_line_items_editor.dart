import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/line_item_type.dart';
import '../../domain/entities/part_item.dart';
import 'service_line_item_row.dart';

/// Editable list of service line items + a manual tax field + a live totals
/// summary. Calls [onChanged] with the current items + tax on every change.
class ServiceLineItemsEditor extends StatefulWidget {
  const ServiceLineItemsEditor({
    super.key,
    required this.initialItems,
    required this.initialTax,
    required this.onChanged,
  });

  final List<PartItem> initialItems;
  final double? initialTax;
  final void Function(List<PartItem> items, double? tax) onChanged;

  @override
  State<ServiceLineItemsEditor> createState() => _ServiceLineItemsEditorState();
}

class _ServiceLineItemsEditorState extends State<ServiceLineItemsEditor> {
  late final List<PartItem> _items = [...widget.initialItems];
  late final List<int> _keys =
      List.generate(widget.initialItems.length, (i) => i);
  int _nextKey = 1 << 20;
  late final TextEditingController _tax = TextEditingController(
      text: widget.initialTax?.toStringAsFixed(2) ?? '');

  @override
  void dispose() {
    _tax.dispose();
    super.dispose();
  }

  double? get _taxValue =>
      _tax.text.trim().isEmpty ? null : double.tryParse(_tax.text);

  void _emit() => widget.onChanged(List.unmodifiable(_items), _taxValue);

  double _totalFor(LineItemType t) =>
      _items.where((p) => p.type == t).fold(0.0, (s, p) => s + p.lineTotal);

  void _add() {
    setState(() {
      _items.add(const PartItem(name: ''));
      _keys.add(_nextKey++);
    });
    _emit();
  }

  void _removeAt(int i) {
    setState(() {
      _items.removeAt(i);
      _keys.removeAt(i);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = _totalFor(LineItemType.labour) +
        _totalFor(LineItemType.part) +
        _totalFor(LineItemType.fee);
    final grand = subtotal + (_taxValue ?? 0);

    Widget totalLine(String label, double v, {bool bold = false}) {
      final style =
          bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style),
            Text(v.toStringAsFixed(2), style: style),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Line items', style: theme.textTheme.titleSmall),
        for (var i = 0; i < _items.length; i++)
          ServiceLineItemRow(
            key: ValueKey(_keys[i]),
            item: _items[i],
            onChanged: (p) {
              _items[i] = p;
              setState(() {});
              _emit();
            },
            onRemove: () => _removeAt(i),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ),
        const Divider(),
        totalLine('Parts', _totalFor(LineItemType.part)),
        totalLine('Labour', _totalFor(LineItemType.labour)),
        totalLine('Fees', _totalFor(LineItemType.fee)),
        totalLine('Subtotal', subtotal),
        Row(
          children: [
            const Expanded(child: Text('Tax')),
            SizedBox(
              width: 90,
              child: TextField(
                key: const Key('li-tax'),
                controller: _tax,
                textAlign: TextAlign.right,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(hintText: '0.00'),
                onChanged: (_) {
                  setState(() {});
                  _emit();
                },
              ),
            ),
          ],
        ),
        totalLine('Grand total', grand, bold: true),
      ],
    );
  }
}
