import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/automobile_repository.dart';
import '../domain/entities/automobile.dart';

abstract interface class GetAutomobilesUseCase {
  Future<List<Automobile>> call();
}

class _GetAutomobilesUseCase implements GetAutomobilesUseCase {
  _GetAutomobilesUseCase(this._repository);

  final IAutomobileRepository _repository;

  @override
  Future<List<Automobile>> call() {
    return _repository.getAutomobiles();
  }
}

final getAutomobilesUseCaseProvider = Provider<GetAutomobilesUseCase>(
  (ref) => _GetAutomobilesUseCase(ref.watch(automobileRepositoryProvider)),
);
