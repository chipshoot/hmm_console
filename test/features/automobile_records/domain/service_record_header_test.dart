import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

void main() {
  ServiceRecord base() => ServiceRecord(
      id: 1,
      automobileId: 2,
      date: DateTime(2026),
      mileage: 50,
      type: ServiceType.oilChange);

  test('carries name and referenceNumber (null by default)', () {
    expect(base().name, isNull);
    expect(base().referenceNumber, isNull);
    final r = ServiceRecord(
        id: 1,
        automobileId: 2,
        date: DateTime(2026),
        mileage: 50,
        type: ServiceType.oilChange,
        name: 'Service A',
        referenceNumber: 'SO#952333');
    expect(r.name, 'Service A');
    expect(r.referenceNumber, 'SO#952333');
  });

  test('copyWith updates name/referenceNumber', () {
    final r = base().copyWith(name: 'Service B', referenceNumber: 'X1');
    expect(r.name, 'Service B');
    expect(r.referenceNumber, 'X1');
    expect(r.type, ServiceType.oilChange);
  });
}
