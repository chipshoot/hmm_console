import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/gas_log/data/datasources/gas_log_remote_datasource.dart';
import 'package:hmm_console/features/gas_log/data/mappers/gas_log_api_mapper.dart';
import 'package:hmm_console/features/gas_log/data/repositories/i_gas_log_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../helpers/gas_log_fixtures.dart';

/// Mirrors the private _GasLogApiRepository to test the same logic.
class _TestGasLogApiRepository implements IGasLogRepository {
  _TestGasLogApiRepository(this._remote);
  final GasLogRemoteDataSource _remote;

  @override
  Future<PaginatedResponse<GasLog>> getGasLogs(int autoId,
      {int page = 1, int pageSize = 20}) async {
    final response =
        await _remote.getGasLogs(autoId, page: page, pageSize: pageSize);
    return PaginatedResponse(
      items: GasLogApiMapper.fromApiList(response.items),
      meta: response.meta,
    );
  }

  @override
  Future<GasLog> getGasLogById(int autoId, int id) async {
    final api = await _remote.getGasLogById(autoId, id);
    return GasLogApiMapper.fromApi(api);
  }

  @override
  Future<GasLog> createGasLog(int autoId, GasLog gasLog) async {
    final dto = GasLogApiMapper.toCreationDto(gasLog);
    final api = await _remote.createGasLog(autoId, dto);
    return GasLogApiMapper.fromApi(api);
  }

  @override
  Future<GasLog> updateGasLog(int autoId, int id, GasLog gasLog) async {
    final dto = GasLogApiMapper.toUpdateDto(gasLog);
    final api = await _remote.updateGasLog(autoId, id, dto);
    return GasLogApiMapper.fromApi(api);
  }

  @override
  Future<void> deleteGasLog(int autoId, int id) =>
      _remote.deleteGasLog(autoId, id);
}

IGasLogRepository _createRepository(Dio dio) {
  final dataSource = GasLogRemoteDataSource(ApiClient(dio));
  return _TestGasLogApiRepository(dataSource);
}

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
  });

  group('GasLogApiRepository integration', () {
    test('getGasLogs returns domain GasLog objects with pagination', () async {
      adapter.onGet(
        '/automobiles/42/gaslogs',
        (server) => server.reply(
          200,
          [
            GasLogFixtures.apiGasLogJson(id: 1),
            GasLogFixtures.apiGasLogJson(id: 2),
          ],
          headers: {
            Headers.contentTypeHeader: ['application/json'],
            'x-pagination': [
              jsonEncode(GasLogFixtures.paginationHeaderJson(totalCount: 2)),
            ],
          },
        ),
        queryParameters: {'pageNumber': 1, 'pageSize': 20},
      );

      final repo = _createRepository(dio);
      final result = await repo.getGasLogs(42);

      expect(result.items, hasLength(2));
      expect(result.items[0].id, 1);
      expect(result.items[1].id, 2);
      expect(result.meta.totalCount, 2);
    });

    test('getGasLogById returns domain GasLog', () async {
      adapter.onGet(
        '/automobiles/42/gaslogs/1',
        (server) => server.reply(200, GasLogFixtures.apiGasLogJson()),
      );

      final repo = _createRepository(dio);
      final result = await repo.getGasLogById(42, 1);

      expect(result.id, 1);
      expect(result.odometer, 45230.0);
      expect(result.stationName, 'Shell Station');
    });

    test('createGasLog sends creation DTO and returns domain GasLog',
        () async {
      adapter.onPost(
        '/automobiles/42/gaslogs',
        (server) => server.reply(200, GasLogFixtures.apiGasLogJson()),
        data: Matchers.any,
      );

      final repo = _createRepository(dio);
      final result = await repo.createGasLog(42, GasLogFixtures.gasLog());

      expect(result.id, 1);
    });

    test('updateGasLog sends update DTO and returns domain GasLog', () async {
      adapter.onPut(
        '/automobiles/42/gaslogs/1',
        (server) => server.reply(200, GasLogFixtures.apiGasLogJson()),
        data: Matchers.any,
      );

      final repo = _createRepository(dio);
      final result =
          await repo.updateGasLog(42, 1, GasLogFixtures.gasLog());

      expect(result.id, 1);
    });

    test('deleteGasLog sends delete request successfully', () async {
      adapter.onDelete(
        '/automobiles/42/gaslogs/1',
        (server) => server.reply(204, null),
      );

      final repo = _createRepository(dio);
      await repo.deleteGasLog(42, 1);
      // No exception means success
    });
  });
}
