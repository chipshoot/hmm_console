import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/automobile_repository.dart';

abstract interface class DeactivateAutomobileUseCase {
  Future<void> call(int id);
}

class _DeactivateAutomobileUseCase implements DeactivateAutomobileUseCase {
  _DeactivateAutomobileUseCase(this._repository);

  final IAutomobileRepository _repository;

  @override
  Future<void> call(int id) {
    return _repository.deactivateAutomobile(id);
  }
}

final deactivateAutomobileUseCaseProvider =
    Provider<DeactivateAutomobileUseCase>(
  (ref) =>
      _DeactivateAutomobileUseCase(ref.watch(automobileRepositoryProvider)),
);
