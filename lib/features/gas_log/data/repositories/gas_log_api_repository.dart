import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/pagination.dart';
import '../../domain/entities/gas_log.dart';
import '../datasources/gas_log_remote_datasource.dart';
import '../mappers/gas_log_api_mapper.dart';
import 'i_gas_log_repository.dart';

class _GasLogApiRepository implements IGasLogRepository {
  _GasLogApiRepository(this._remoteDataSource);

  final GasLogRemoteDataSource _remoteDataSource;

  @override
  Future<PaginatedResponse<GasLog>> getGasLogs(
    int autoId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _remoteDataSource.getGasLogs(
      autoId,
      page: page,
      pageSize: pageSize,
    );
    return PaginatedResponse(
      items: GasLogApiMapper.fromApiList(response.items),
      meta: response.meta,
    );
  }

  @override
  Future<GasLog> getGasLogById(int autoId, int id) async {
    final api = await _remoteDataSource.getGasLogById(autoId, id);
    return GasLogApiMapper.fromApi(api);
  }

  @override
  Future<GasLog> createGasLog(int autoId, GasLog gasLog) async {
    final dto = GasLogApiMapper.toCreationDto(gasLog);
    final api = await _remoteDataSource.createGasLog(autoId, dto);
    return GasLogApiMapper.fromApi(api);
  }

  @override
  Future<GasLog> updateGasLog(int autoId, int id, GasLog gasLog) async {
    final dto = GasLogApiMapper.toUpdateDto(gasLog);
    final api = await _remoteDataSource.updateGasLog(autoId, id, dto);
    return GasLogApiMapper.fromApi(api);
  }

  @override
  Future<void> deleteGasLog(int autoId, int id) {
    return _remoteDataSource.deleteGasLog(autoId, id);
  }
}

final gasLogRepositoryProvider = Provider<IGasLogRepository>(
  (ref) => _GasLogApiRepository(ref.watch(gasLogRemoteDataSourceProvider)),
);
