import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/receipt_scan/data/receipt_llm_schema.dart';

void main() {
  final schema = receiptLlmSchema.schema;
  final props = schema['properties']! as Map<String, Object?>;
  final item =
      (props['lineItems']! as Map<String, Object?>)['items']!
          as Map<String, Object?>;
  final itemProps = item['properties']! as Map<String, Object?>;

  test('schema field list matches the server', () {
    expect(receiptLlmSchema.name, 'record_service_receipt');
    expect(props.keys.toSet(), {
      'shopName',
      'date',
      'odometer',
      'tax',
      'total',
      'currency',
      'lineItems',
    });
    expect(itemProps.keys.toSet(), {
      'type',
      'name',
      'quantity',
      'unitCost',
      'amount',
    });
    expect((itemProps['type']! as Map)['enum'], ['Labour', 'Part', 'Fee']);
  });

  test('schema is strict-compatible', () {
    for (final (obj, p) in [(schema, props), (item, itemProps)]) {
      expect(obj['additionalProperties'], false);
      expect((obj['required']! as List).toSet(), p.keys.toSet());
    }
  });

  test('prompt is the server text without "using the tool"', () {
    expect(receiptLlmPrompt, startsWith('Extract this vehicle service receipt.'));
    expect(receiptLlmPrompt, isNot(contains('using the tool')));
    expect(receiptLlmPrompt, contains('Shp, Ship, or Shipped'));
  });
}
