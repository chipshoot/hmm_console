import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/pagination.dart';
import '../data/repositories/gas_log_api_repository.dart';
import '../data/repositories/i_gas_log_repository.dart';
import '../domain/entities/gas_log.dart';

abstract interface class GetGasLogsUseCase {
  Future<PaginatedResponse<GasLog>> call(
    int autoId, {
    int page,
    int pageSize,
  });
}

class _GetGasLogsUseCase implements GetGasLogsUseCase {
  _GetGasLogsUseCase(this._repository);

  final IGasLogRepository _repository;

  @override
  Future<PaginatedResponse<GasLog>> call(
    int autoId, {
    int page = 1,
    int pageSize = 20,
  }) {
    return _repository.getGasLogs(autoId, page: page, pageSize: pageSize);
  }
}

final getGasLogsUseCaseProvider = Provider<GetGasLogsUseCase>(
  (ref) => _GetGasLogsUseCase(ref.watch(gasLogRepositoryProvider)),
);
