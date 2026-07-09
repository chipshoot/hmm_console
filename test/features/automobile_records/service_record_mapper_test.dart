import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/automobile_records/data/mappers/automobile_records_api_mapper.dart';
import 'package:hmm_console/features/automobile_records/data/models/api_part_item.dart';
import 'package:hmm_console/features/automobile_records/data/models/api_service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/part_item.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_record.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/service_type.dart';

void main() {
  test('maps name + referenceNumber to create and back from api', () {
    final r = ServiceRecord(
        id: 1,
        automobileId: 2,
        date: DateTime(2026),
        mileage: 50,
        types: const [ServiceType.oilChange],
        name: 'Service A',
        referenceNumber: 'SO#1');
    final create = AutomobileRecordsApiMapper.serviceToCreate(r);
    expect(create.toJson()['name'], 'Service A');
    expect(create.toJson()['referenceNumber'], 'SO#1');

    final api = ApiServiceRecord(
        id: 1,
        automobileId: 2,
        date: DateTime(2026),
        mileage: 50,
        type: 'OilChange',
        name: 'Service A',
        referenceNumber: 'SO#1');
    final back = AutomobileRecordsApiMapper.serviceFromApi(api);
    expect(back.name, 'Service A');
    expect(back.referenceNumber, 'SO#1');
  });

  test('maps types list to create and back (legacy type fallback)', () {
    final r = ServiceRecord(
        id: 1,
        automobileId: 2,
        date: DateTime(2026),
        mileage: 50,
        types: const [ServiceType.oilChange, ServiceType.inspection]);
    final create = AutomobileRecordsApiMapper.serviceToCreate(r);
    expect(create.toJson()['types'], ['OilChange', 'Inspection']);

    // A legacy single-type API payload (no `types`) still maps.
    final legacy = ApiServiceRecord(
        id: 1, automobileId: 2, date: DateTime(2026), mileage: 50,
        type: 'Brake');
    expect(AutomobileRecordsApiMapper.serviceFromApi(legacy).types,
        [ServiceType.brake]);
  });

  test('serviceToCreate carries item type + tax to the DTO', () {
    final dto = AutomobileRecordsApiMapper.serviceToCreate(ServiceRecord(
      id: 0, automobileId: 1, date: DateTime(2026), mileage: 1,
      types: const [ServiceType.oilChange], tax: 5.0,
      parts: const [PartItem(type: LineItemType.labour, name: 'L', unitCost: 10.0)],
    ));
    expect(dto.parts.first.type, 'Labour');
    expect(dto.tax, 5.0);
  });

  test('serviceFromApi reads item type + tax', () {
    final api = ApiServiceRecord(
      id: 1, automobileId: 1, date: DateTime(2026), mileage: 1,
      type: 'OilChange', tax: 5.0,
      parts: const [ApiPartItem(name: 'L', type: 'Fee', unitCost: 2.0)],
    );
    final r = AutomobileRecordsApiMapper.serviceFromApi(api);
    expect(r.parts.first.type, LineItemType.fee);
    expect(r.tax, 5.0);
  });
}
