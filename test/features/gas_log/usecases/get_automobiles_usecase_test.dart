import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/data/repositories/automobile_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/usecases/get_automobiles_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeAutomobileRepository implements IAutomobileRepository {
  List<Automobile> autos = [];

  @override
  Future<List<Automobile>> getAutomobiles() async => autos;

  @override
  Future<Automobile> getAutomobileById(int id) => throw UnimplementedError();

  @override
  Future<Automobile> createAutomobile(Automobile automobile) =>
      throw UnimplementedError();

  @override
  Future<void> updateAutomobile(int id, Automobile automobile) =>
      throw UnimplementedError();

  @override
  Future<void> deactivateAutomobile(int id) => throw UnimplementedError();
}

void main() {
  group('GetAutomobilesUseCase', () {
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

    test('returns list from repository', () async {
      fakeRepo.autos = [
        GasLogFixtures.automobile(id: 1),
        GasLogFixtures.automobile(id: 2),
      ];

      final useCase = container.read(getAutomobilesUseCaseProvider);
      final result = await useCase.call();

      expect(result, hasLength(2));
      expect(result[0].id, 1);
      expect(result[1].id, 2);
    });

    test('returns empty list when no automobiles', () async {
      final useCase = container.read(getAutomobilesUseCaseProvider);
      final result = await useCase.call();
      expect(result, isEmpty);
    });
  });
}
