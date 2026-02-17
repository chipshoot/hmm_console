import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/data/repositories/automobile_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/usecases/update_automobile_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeAutomobileRepository implements IAutomobileRepository {
  int? lastId;
  Automobile? lastInput;

  @override
  Future<void> updateAutomobile(int id, Automobile automobile) async {
    lastId = id;
    lastInput = automobile;
  }

  @override
  Future<List<Automobile>> getAutomobiles() => throw UnimplementedError();
  @override
  Future<Automobile> getAutomobileById(int id) => throw UnimplementedError();
  @override
  Future<Automobile> createAutomobile(Automobile automobile) =>
      throw UnimplementedError();
  @override
  Future<void> deactivateAutomobile(int id) => throw UnimplementedError();
}

void main() {
  group('UpdateAutomobileUseCase', () {
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

    test('delegates to repository with correct id and automobile', () async {
      final input = GasLogFixtures.automobile(id: 42);
      final useCase = container.read(updateAutomobileUseCaseProvider);
      await useCase.call(42, input);

      expect(fakeRepo.lastId, 42);
      expect(fakeRepo.lastInput, isNotNull);
      expect(fakeRepo.lastInput!.id, 42);
    });
  });
}
