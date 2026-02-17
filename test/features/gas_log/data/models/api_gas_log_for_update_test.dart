import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/data/models/api_gas_log_for_update.dart';

void main() {
  group('ApiGasLogForUpdate.toJson', () {
    test('empty update produces empty JSON', () {
      const dto = ApiGasLogForUpdate();
      expect(dto.toJson(), isEmpty);
    });

    test('only includes non-null fields', () {
      final dto = ApiGasLogForUpdate(
        odometer: 46000,
        fuel: 35.0,
        comment: 'Updated',
      );

      final json = dto.toJson();

      expect(json.length, 3);
      expect(json['odometer'], 46000);
      expect(json['fuel'], 35.0);
      expect(json['comment'], 'Updated');
      expect(json.containsKey('date'), false);
      expect(json.containsKey('totalPrice'), false);
    });

    test('serializes date as ISO 8601', () {
      final dto = ApiGasLogForUpdate(date: DateTime(2026, 2, 1));
      final json = dto.toJson();
      expect(json['date'], DateTime(2026, 2, 1).toIso8601String());
    });
  });
}
