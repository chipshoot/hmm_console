import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';

void main() {
  test('wire round-trip + default', () {
    expect(LineItemType.labour.wireName, 'Labour');
    expect(LineItemType.fromWire('Fee'), LineItemType.fee);
    expect(LineItemType.fromWire(null), LineItemType.part);
    expect(LineItemType.fromWire('nonsense'), LineItemType.part);
  });
}
