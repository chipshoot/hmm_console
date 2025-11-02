import '../../domain/entities/gas_log.dart';

abstract class IGasLogRepository {
  Future<List<GasLog>> getGasLogs();

  Future<GasLog> getGasLog(String id);

  Future<GasLog> finGasLogByDate(DateTime date);

  Future<String> saveGasLog(GasLog gasLog);

  Future<bool> deleteGasLog(String id);
}
