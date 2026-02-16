import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/gas_log/data/datasources/automobile_remote_datasource.dart';
import 'package:hmm_console/features/gas_log/data/mappers/gas_log_api_mapper.dart';
import 'package:hmm_console/features/gas_log/data/repositories/automobile_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../helpers/gas_log_fixtures.dart';

/// Test impl that mirrors the private _AutomobileApiRepository.
class _TestAutomobileRepository implements IAutomobileRepository {
  _TestAutomobileRepository(this._remote);
  final AutomobileRemoteDataSource _remote;

  @override
  Future<List<Automobile>> getAutomobiles() async {
    final apiList = await _remote.getAutomobiles();
    return apiList.map(GasLogApiMapper.automobileFromApi).toList();
  }

  @override
  Future<Automobile> getAutomobileById(int id) async {
    final api = await _remote.getAutomobileById(id);
    return GasLogApiMapper.automobileFromApi(api);
  }

  @override
  Future<Automobile> createAutomobile(Automobile automobile) =>
      throw UnimplementedError();

  @override
  Future<void> updateAutomobile(int id, Automobile automobile) =>
      throw UnimplementedError();

  @override
  Future<void> deactivateAutomobile(int id) => throw UnimplementedError();
}

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
  });

  group('AutomobileRepository integration', () {
    test('getAutomobiles returns domain Automobile list', () async {
      adapter.onGet(
        '/automobiles',
        (server) => server.reply(200, [
          GasLogFixtures.apiAutomobileJson(id: 1),
          GasLogFixtures.apiAutomobileJson(id: 2),
        ]),
      );

      final remote = AutomobileRemoteDataSource(ApiClient(dio));
      final repo = _TestAutomobileRepository(remote);
      final result = await repo.getAutomobiles();

      expect(result, hasLength(2));
      expect(result[0].id, 1);
      expect(result[0].displayName, contains('Toyota'));
      expect(result[1].id, 2);
    });

    test('getAutomobileById returns domain Automobile', () async {
      adapter.onGet(
        '/automobiles/42',
        (server) => server.reply(200, GasLogFixtures.apiAutomobileJson()),
      );

      final remote = AutomobileRemoteDataSource(ApiClient(dio));
      final repo = _TestAutomobileRepository(remote);
      final result = await repo.getAutomobileById(42);

      expect(result.id, 42);
      expect(result.maker, 'Toyota');
      expect(result.year, 2023);
    });
  });
}
