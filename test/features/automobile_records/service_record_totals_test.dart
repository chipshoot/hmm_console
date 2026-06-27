import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

ServiceRecord _rec(List<PartItem> parts, {double? tax, double? cost}) =>
    ServiceRecord(
      id: 1, automobileId: 1, date: DateTime(2026), mileage: 1,
      type: ServiceType.oilChange, parts: parts, tax: tax, cost: cost);

void main() {
  test('totals split by type + grand total adds tax', () {
    final r = _rec([
      const PartItem(type: LineItemType.labour, name: 'L', quantity: 1, unitCost: 61.50),
      const PartItem(type: LineItemType.part, name: 'Oil', quantity: 2, unitCost: 17.95),
      const PartItem(type: LineItemType.fee, name: 'Env', quantity: 1, unitCost: 1.54),
    ], tax: 28.90);
    expect(r.labourTotal, 61.50);
    expect(r.partsTotal, 35.90);
    expect(r.feesTotal, 1.54);
    expect(r.subtotal, closeTo(98.94, 1e-9));
    expect(r.grandTotal, closeTo(127.84, 1e-9));
    expect(r.effectiveTotal, closeTo(127.84, 1e-9));
  });

  test('effectiveTotal falls back to flat cost when no items', () {
    final r = _rec(const [], cost: 85.0);
    expect(r.effectiveTotal, 85.0);
  });

  test('PartItem defaults to part type', () {
    expect(const PartItem(name: 'x').type, LineItemType.part);
  });
}
