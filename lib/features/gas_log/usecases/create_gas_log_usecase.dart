import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/gas_log_api_repository.dart';
import '../data/repositories/i_gas_log_repository.dart';
import '../domain/entities/gas_log.dart';

abstract interface class CreateGasLogUseCase {
  Future<GasLog> call(int autoId, GasLog gasLog);
}

class _CreateGasLogUseCase implements CreateGasLogUseCase {
  _CreateGasLogUseCase(this._repository);

  final IGasLogRepository _repository;

  @override
  Future<GasLog> call(int autoId, GasLog gasLog) {
    return _repository.createGasLog(autoId, gasLog);
  }
}

final createGasLogUseCaseProvider = Provider<CreateGasLogUseCase>(
  (ref) => _CreateGasLogUseCase(ref.watch(gasLogRepositoryProvider)),
);
