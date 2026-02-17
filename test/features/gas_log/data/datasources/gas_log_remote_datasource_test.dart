import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/gas_log/data/datasources/gas_log_remote_datasource.dart';
import 'package:hmm_console/features/gas_log/data/models/api_gas_log_for_creation.dart';
import 'package:hmm_console/features/gas_log/data/models/api_gas_log_for_update.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../helpers/gas_log_fixtures.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late GasLogRemoteDataSource dataSource;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    dataSource = GasLogRemoteDataSource(ApiClient(dio));
  });

  group('getGasLogs', () {
    test('returns paginated list of gas logs', () async {
      adapter.onGet(
        '/automobiles/42/gaslogs',
        (server) => server.reply(
          200,
          [GasLogFixtures.apiGasLogJson(id: 1)],
          headers: {
            Headers.contentTypeHeader: ['application/json'],
            'x-pagination': [
              jsonEncode(GasLogFixtures.paginationHeaderJson()),
            ],
          },
        ),
        queryParameters: {'pageNumber': 1, 'pageSize': 20},
      );

      final result = await dataSource.getGasLogs(42);

      expect(result.items, hasLength(1));
      expect(result.items.first.id, 1);
      expect(result.meta.totalCount, 2);
      expect(result.meta.currentPage, 1);
    });

    test('handles missing pagination header', () async {
      adapter.onGet(
        '/automobiles/42/gaslogs',
        (server) => server.reply(
          200,
          [GasLogFixtures.apiGasLogJson()],
        ),
        queryParameters: {'pageNumber': 1, 'pageSize': 20},
      );

      final result = await dataSource.getGasLogs(42);

      expect(result.items, hasLength(1));
      expect(result.meta.totalCount, 1);
      expect(result.meta.totalPages, 1);
    });

    test('passes custom page and pageSize', () async {
      adapter.onGet(
        '/automobiles/42/gaslogs',
        (server) => server.reply(200, []),
        queryParameters: {'pageNumber': 3, 'pageSize': 10},
      );

      final result =
          await dataSource.getGasLogs(42, page: 3, pageSize: 10);
      expect(result.items, isEmpty);
    });
  });

  group('getGasLogById', () {
    test('returns single gas log', () async {
      adapter.onGet(
        '/automobiles/42/gaslogs/1',
        (server) => server.reply(200, GasLogFixtures.apiGasLogJson()),
      );

      final result = await dataSource.getGasLogById(42, 1);
      expect(result.id, 1);
      expect(result.automobileId, 42);
    });
  });

  group('createGasLog', () {
    test('posts creation DTO and returns created gas log', () async {
      adapter.onPost(
        '/automobiles/42/gaslogs',
        (server) => server.reply(200, GasLogFixtures.apiGasLogJson()),
        data: Matchers.any,
      );

      final dto = ApiGasLogForCreation(
        date: GasLogFixtures.date,
        automobileId: 42,
        odometer: 45230,
        distance: 320.5,
        fuel: 42.3,
        fuelGrade: 'Regular',
        totalPrice: 164.55,
        unitPrice: 3.89,
      );

      final result = await dataSource.createGasLog(42, dto);
      expect(result.id, 1);
    });
  });

  group('updateGasLog', () {
    test('puts update DTO and returns updated gas log', () async {
      adapter.onPut(
        '/automobiles/42/gaslogs/1',
        (server) => server.reply(200, GasLogFixtures.apiGasLogJson()),
        data: Matchers.any,
      );

      const dto = ApiGasLogForUpdate(odometer: 46000);
      final result = await dataSource.updateGasLog(42, 1, dto);
      expect(result.id, 1);
    });
  });

  group('deleteGasLog', () {
    test('sends delete request', () async {
      adapter.onDelete(
        '/automobiles/42/gaslogs/1',
        (server) => server.reply(204, null),
      );

      await dataSource.deleteGasLog(42, 1);
      // No exception means success
    });
  });
}
