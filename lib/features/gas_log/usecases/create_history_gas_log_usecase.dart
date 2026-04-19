import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/gas_log_api_repository.dart';
import '../data/repositories/i_gas_log_repository.dart';
import '../domain/entities/gas_log.dart';

abstract interface class CreateHistoryGasLogUseCase {
  Future<GasLog> call(int autoId, GasLog gasLog);
}

class _CreateHistoryGasLogUseCase implements CreateHistoryGasLogUseCase {
  _CreateHistoryGasLogUseCase(this._repository);

  final IGasLogRepository _repository;

  @override
  Future<GasLog> call(int autoId, GasLog gasLog) {
    return _repository.createHistoryGasLog(autoId, gasLog);
  }
}

final createHistoryGasLogUseCaseProvider =
    Provider<CreateHistoryGasLogUseCase>(
  (ref) => _CreateHistoryGasLogUseCase(ref.watch(gasLogRepositoryProvider)),
);
