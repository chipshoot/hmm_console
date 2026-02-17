import '../../../../core/network/pagination.dart';
import '../../domain/entities/gas_log.dart';

abstract interface class IGasLogRepository {
  Future<PaginatedResponse<GasLog>> getGasLogs(
    int autoId, {
    int page,
    int pageSize,
  });

  Future<GasLog> getGasLogById(int autoId, int id);

  Future<GasLog> createGasLog(int autoId, GasLog gasLog);

  Future<GasLog> updateGasLog(int autoId, int id, GasLog gasLog);

  Future<void> deleteGasLog(int autoId, int id);
}
