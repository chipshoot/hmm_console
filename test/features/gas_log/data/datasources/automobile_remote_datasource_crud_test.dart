import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/gas_log/data/datasources/automobile_remote_datasource.dart';
import 'package:hmm_console/features/gas_log/data/models/api_automobile_for_create.dart';
import 'package:hmm_console/features/gas_log/data/models/api_automobile_for_update.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../helpers/gas_log_fixtures.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AutomobileRemoteDataSource dataSource;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    dataSource = AutomobileRemoteDataSource(ApiClient(dio));
  });

  group('createAutomobile', () {
    test('sends POST and returns created automobile', () async {
      adapter.onPost(
        '/automobiles',
        (server) => server.reply(200, GasLogFixtures.apiAutomobileJson(id: 99)),
        data: Matchers.any,
      );

      const dto = ApiAutomobileForCreate(
        vin: '1HGBH41JXMN109186',
        maker: 'Toyota',
        brand: 'Toyota',
        model: 'Camry',
        plate: 'ABC 123',
        engineType: 'Gasoline',
        fuelType: 'Regular',
      );

      final result = await dataSource.createAutomobile(dto);

      expect(result.id, 99);
      expect(result.maker, 'Toyota');
      expect(result.vin, '1HGBH41JXMN109186');
    });

    test('throws on server error', () async {
      adapter.onPost(
        '/automobiles',
        (server) => server.reply(500, {'error': 'Internal Server Error'}),
        data: Matchers.any,
      );

      const dto = ApiAutomobileForCreate(
        vin: '1HGBH41JXMN109186',
        maker: 'Toyota',
        brand: 'Toyota',
        model: 'Camry',
        plate: 'ABC 123',
        engineType: 'Gasoline',
        fuelType: 'Regular',
      );

      expect(
        () => dataSource.createAutomobile(dto),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('updateAutomobile', () {
    test('sends PUT with no content response', () async {
      adapter.onPut(
        '/automobiles/42',
        (server) => server.reply(204, null),
        data: Matchers.any,
      );

      const dto = ApiAutomobileForUpdate(
        color: 'Red',
        plate: 'XYZ 789',
        meterReading: 50000,
        ownershipStatus: 'Owned',
        isActive: true,
      );

      // Should complete without error
      await dataSource.updateAutomobile(42, dto);
    });

    test('sends PUT for deactivation', () async {
      adapter.onPut(
        '/automobiles/42',
        (server) => server.reply(204, null),
        data: Matchers.any,
      );

      const dto = ApiAutomobileForUpdate(
        color: 'Silver',
        plate: 'ABC 123',
        meterReading: 45230,
        isActive: false,
      );

      await dataSource.updateAutomobile(42, dto);
    });

    test('throws on server error', () async {
      adapter.onPut(
        '/automobiles/42',
        (server) => server.reply(500, {'error': 'Internal Server Error'}),
        data: Matchers.any,
      );

      const dto = ApiAutomobileForUpdate(
        meterReading: 50000,
        isActive: true,
      );

      expect(
        () => dataSource.updateAutomobile(42, dto),
        throwsA(isA<DioException>()),
      );
    });
  });
}
