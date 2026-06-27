import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/presentation/widgets/service_line_item_row.dart';

void main() {
  testWidgets('edits name + shows line total + removes', (t) async {
    PartItem? changed;
    var removed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ServiceLineItemRow(
          item: const PartItem(
              type: LineItemType.part, name: 'Oil', quantity: 2, unitCost: 17.95),
          onChanged: (p) => changed = p,
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.textContaining('35.90'), findsOneWidget); // 2 × 17.95
    await t.enterText(find.byKey(const Key('li-name')), 'Oil 5W30');
    expect(changed?.name, 'Oil 5W30');
    await t.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });
}
