import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/gas_log_api_repository.dart';
import '../data/repositories/i_gas_log_repository.dart';

abstract interface class DeleteGasLogUseCase {
  Future<void> call(int autoId, int id);
}

class _DeleteGasLogUseCase implements DeleteGasLogUseCase {
  _DeleteGasLogUseCase(this._repository);

  final IGasLogRepository _repository;

  @override
  Future<void> call(int autoId, int id) {
    return _repository.deleteGasLog(autoId, id);
  }
}

final deleteGasLogUseCaseProvider = Provider<DeleteGasLogUseCase>(
  (ref) => _DeleteGasLogUseCase(ref.watch(gasLogRepositoryProvider)),
);
