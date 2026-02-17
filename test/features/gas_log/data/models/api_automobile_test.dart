import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/data/models/api_automobile.dart';

import '../../helpers/gas_log_fixtures.dart';

void main() {
  group('ApiAutomobile.fromJson', () {
    test('parses full JSON correctly', () {
      final auto = ApiAutomobile.fromJson(GasLogFixtures.apiAutomobileJson());

      expect(auto.id, 42);
      expect(auto.maker, 'Toyota');
      expect(auto.brand, 'Toyota');
      expect(auto.model, 'Camry');
      expect(auto.year, 2023);
      expect(auto.color, 'Silver');
      expect(auto.plate, 'ABC 123');
      expect(auto.meterReading, 45230);
      expect(auto.isActive, true);
    });

    test('defaults for missing optional fields', () {
      final auto = ApiAutomobile.fromJson({'id': 1});

      expect(auto.id, 1);
      expect(auto.maker, isNull);
      expect(auto.brand, isNull);
      expect(auto.model, isNull);
      expect(auto.year, 0);
      expect(auto.color, isNull);
      expect(auto.plate, isNull);
      expect(auto.meterReading, 0);
      expect(auto.isActive, true);
    });
  });
}
