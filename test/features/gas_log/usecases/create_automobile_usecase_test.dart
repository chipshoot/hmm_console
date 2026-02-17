import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/data/repositories/automobile_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/usecases/create_automobile_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeAutomobileRepository implements IAutomobileRepository {
  Automobile? lastInput;

  @override
  Future<Automobile> createAutomobile(Automobile automobile) async {
    lastInput = automobile;
    return GasLogFixtures.automobile(id: 99);
  }

  @override
  Future<List<Automobile>> getAutomobiles() => throw UnimplementedError();
  @override
  Future<Automobile> getAutomobileById(int id) => throw UnimplementedError();
  @override
  Future<void> updateAutomobile(int id, Automobile automobile) =>
      throw UnimplementedError();
  @override
  Future<void> deactivateAutomobile(int id) => throw UnimplementedError();
}

void main() {
  group('CreateAutomobileUseCase', () {
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

    test('delegates to repository and returns created automobile', () async {
      final input = GasLogFixtures.automobileForCreate();
      final useCase = container.read(createAutomobileUseCaseProvider);
      final result = await useCase.call(input);

      expect(result.id, 99);
      expect(fakeRepo.lastInput, isNotNull);
      expect(fakeRepo.lastInput!.vin, '1HGBH41JXMN109186');
    });
  });
}
