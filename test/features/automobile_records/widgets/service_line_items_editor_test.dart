import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/presentation/widgets/service_line_items_editor.dart';

void main() {
  testWidgets('add item, edit tax, totals recompute', (t) async {
    List<PartItem> items = const [
      PartItem(type: LineItemType.part, name: 'Oil', quantity: 2, unitCost: 10.0),
    ];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ServiceLineItemsEditor(
          initialItems: items,
          initialTax: 5.0,
          onChanged: (i, x) => items = i,
        ),
      ),
    ));
    // subtotal 20.00, tax 5.00, grand 25.00
    expect(find.textContaining('25.00'), findsWidgets);
    await t.tap(find.text('Add item'));
    await t.pump();
    expect(find.byKey(const Key('li-name')), findsNWidgets(2));
  });
}
