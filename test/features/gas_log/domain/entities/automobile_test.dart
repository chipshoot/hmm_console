import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';

void main() {
  group('Automobile', () {
    test('displayName shows year maker brand model', () {
      const auto = Automobile(
        id: 1,
        maker: 'Toyota',
        brand: 'Toyota',
        model: 'Camry',
        year: 2023,
        meterReading: 45000,
        isActive: true,
      );
      expect(auto.displayName, '2023 Toyota Toyota Camry');
    });

    test('displayName skips empty/null parts', () {
      const auto = Automobile(
        id: 1,
        maker: 'Honda',
        year: 2022,
        meterReading: 30000,
        isActive: true,
      );
      expect(auto.displayName, '2022 Honda');
    });

    test('displayName falls back to Vehicle #id when all empty', () {
      const auto = Automobile(
        id: 7,
        year: 0,
        meterReading: 0,
        isActive: true,
      );
      expect(auto.displayName, 'Vehicle #7');
    });

    test('displayName skips year 0', () {
      const auto = Automobile(
        id: 3,
        maker: 'Tesla',
        model: 'Model 3',
        year: 0,
        meterReading: 10000,
        isActive: true,
      );
      expect(auto.displayName, 'Tesla Model 3');
    });

    test('displayName skips empty strings', () {
      const auto = Automobile(
        id: 1,
        maker: '',
        brand: '',
        model: '',
        year: 2024,
        meterReading: 0,
        isActive: true,
      );
      expect(auto.displayName, '2024');
    });
  });
}
