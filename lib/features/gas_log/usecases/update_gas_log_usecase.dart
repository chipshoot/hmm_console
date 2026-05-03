import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/repository_providers.dart';
import '../data/repositories/i_gas_log_repository.dart';
import '../domain/entities/gas_log.dart';

abstract interface class UpdateGasLogUseCase {
  Future<GasLog> call(int autoId, int id, GasLog gasLog);
}

class _UpdateGasLogUseCase implements UpdateGasLogUseCase {
  _UpdateGasLogUseCase(this._repository);

  final IGasLogRepository _repository;

  @override
  Future<GasLog> call(int autoId, int id, GasLog gasLog) {
    return _repository.updateGasLog(autoId, id, gasLog);
  }
}

final updateGasLogUseCaseProvider = Provider<UpdateGasLogUseCase>(
  (ref) => _UpdateGasLogUseCase(ref.watch(gasLogRepositoryModeProvider)),
);
