import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/data/repositories/automobile_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/usecases/deactivate_automobile_usecase.dart';

class _FakeAutomobileRepository implements IAutomobileRepository {
  int? lastDeactivatedId;

  @override
  Future<void> deactivateAutomobile(int id) async {
    lastDeactivatedId = id;
  }

  @override
  Future<List<Automobile>> getAutomobiles() => throw UnimplementedError();
  @override
  Future<Automobile> getAutomobileById(int id) => throw UnimplementedError();
  @override
  Future<Automobile> createAutomobile(Automobile automobile) =>
      throw UnimplementedError();
  @override
  Future<void> updateAutomobile(int id, Automobile automobile) =>
      throw UnimplementedError();
}

void main() {
  group('DeactivateAutomobileUseCase', () {
    late _FakeAutomobileRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = _FakeAutomobileRepository();
      container = ProviderContainer(
        overrides: [
          automobileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
    });

    test('delegates to repository with correct id', () async {
      final useCase = container.read(deactivateAutomobileUseCaseProvider);
      await useCase.call(42);

      expect(fakeRepo.lastDeactivatedId, 42);
    });
  });
}
