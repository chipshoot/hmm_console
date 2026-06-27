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

  testWidgets('clearing the unit cost emits null (not the stale value)',
      (t) async {
    PartItem? changed;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ServiceLineItemRow(
          item: const PartItem(name: 'Oil', quantity: 1, unitCost: 17.95),
          onChanged: (p) => changed = p,
          onRemove: () {},
        ),
      ),
    ));
    await t.enterText(find.byKey(const Key('li-unit')), '');
    expect(changed, isNotNull);
    expect(changed!.unitCost, isNull); // was 17.95 — must clear, not retain
  });

  testWidgets('changing type after editing fields preserves the edits',
      (t) async {
    PartItem? changed;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ServiceLineItemRow(
          item: const PartItem(
              type: LineItemType.part, name: 'X', quantity: 1, unitCost: 5.0),
          onChanged: (p) => changed = p,
          onRemove: () {},
        ),
      ),
    ));
    await t.enterText(find.byKey(const Key('li-name')), 'Service A');
    await t.enterText(find.byKey(const Key('li-unit')), '61.50');
    // Now change the type via the dropdown.
    await t.tap(find.text('Part').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Labour').last);
    await t.pumpAndSettle();
    expect(changed!.type, LineItemType.labour);
    expect(changed!.name, 'Service A'); // edit preserved
    expect(changed!.unitCost, 61.50); // edit preserved
  });
}
