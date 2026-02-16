import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/automobile_repository.dart';
import '../domain/entities/automobile.dart';

abstract interface class UpdateAutomobileUseCase {
  Future<void> call(int id, Automobile automobile);
}

class _UpdateAutomobileUseCase implements UpdateAutomobileUseCase {
  _UpdateAutomobileUseCase(this._repository);

  final IAutomobileRepository _repository;

  @override
  Future<void> call(int id, Automobile automobile) {
    return _repository.updateAutomobile(id, automobile);
  }
}

final updateAutomobileUseCaseProvider = Provider<UpdateAutomobileUseCase>(
  (ref) => _UpdateAutomobileUseCase(ref.watch(automobileRepositoryProvider)),
);
