import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/automobile_repository.dart';
import '../domain/entities/automobile.dart';

abstract interface class CreateAutomobileUseCase {
  Future<Automobile> call(Automobile automobile);
}

class _CreateAutomobileUseCase implements CreateAutomobileUseCase {
  _CreateAutomobileUseCase(this._repository);

  final IAutomobileRepository _repository;

  @override
  Future<Automobile> call(Automobile automobile) {
    return _repository.createAutomobile(automobile);
  }
}

final createAutomobileUseCaseProvider = Provider<CreateAutomobileUseCase>(
  (ref) => _CreateAutomobileUseCase(ref.watch(automobileRepositoryProvider)),
);
