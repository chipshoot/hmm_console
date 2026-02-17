import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/gas_log/data/datasources/automobile_remote_datasource.dart';
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

  group('getAutomobiles', () {
    test('returns list of automobiles', () async {
      adapter.onGet(
        '/automobiles',
        (server) => server.reply(200, [
          GasLogFixtures.apiAutomobileJson(id: 1),
          GasLogFixtures.apiAutomobileJson(id: 2),
        ]),
      );

      final result = await dataSource.getAutomobiles();

      expect(result, hasLength(2));
      expect(result[0].id, 1);
      expect(result[1].id, 2);
    });

    test('returns empty list when no automobiles', () async {
      adapter.onGet(
        '/automobiles',
        (server) => server.reply(200, []),
      );

      final result = await dataSource.getAutomobiles();
      expect(result, isEmpty);
    });
  });

  group('getAutomobileById', () {
    test('returns single automobile', () async {
      adapter.onGet(
        '/automobiles/42',
        (server) => server.reply(200, GasLogFixtures.apiAutomobileJson()),
      );

      final result = await dataSource.getAutomobileById(42);

      expect(result.id, 42);
      expect(result.maker, 'Toyota');
      expect(result.model, 'Camry');
    });
  });
}
