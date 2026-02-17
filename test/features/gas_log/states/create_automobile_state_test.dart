import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/states/create_automobile_state.dart';
import 'package:hmm_console/features/gas_log/usecases/create_automobile_usecase.dart';
import 'package:hmm_console/features/gas_log/usecases/get_automobiles_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeCreateAutomobileUseCase implements CreateAutomobileUseCase {
  Automobile? lastInput;

  @override
  Future<Automobile> call(Automobile automobile) async {
    lastInput = automobile;
    return GasLogFixtures.automobile(id: 99);
  }
}

class _ErrorCreateAutomobileUseCase implements CreateAutomobileUseCase {
  @override
  Future<Automobile> call(Automobile automobile) async {
    throw Exception('Create failed');
  }
}

class _FakeGetAutomobilesUseCase implements GetAutomobilesUseCase {
  @override
  Future<List<Automobile>> call() async => [];
}

void main() {
  group('CreateAutomobileState', () {
    late _FakeCreateAutomobileUseCase fakeUseCase;
    late ProviderContainer container;

    setUp(() {
      fakeUseCase = _FakeCreateAutomobileUseCase();
      container = ProviderContainer(
        overrides: [
          createAutomobileUseCaseProvider.overrideWithValue(fakeUseCase),
          getAutomobilesUseCaseProvider
              .overrideWithValue(_FakeGetAutomobilesUseCase()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('initial state is null', () {
      final state = container.read(createAutomobileStateProvider);
      expect(state.value, isNull);
    });

    test('create delegates to use case and returns created automobile',
        () async {
      final input = GasLogFixtures.automobileForCreate();
      await container
          .read(createAutomobileStateProvider.notifier)
          .create(input);

      final state = container.read(createAutomobileStateProvider);
      expect(state.value?.id, 99);
      expect(fakeUseCase.lastInput, isNotNull);
    });

    test('create sets loading then data state', () async {
      final states = <AsyncValue<Automobile?>>[];
      container.listen(createAutomobileStateProvider, (prev, next) {
        states.add(next);
      });

      await container
          .read(createAutomobileStateProvider.notifier)
          .create(GasLogFixtures.automobileForCreate());

      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.hasValue, isTrue);
    });

    test('error state on failure', () async {
      final errorContainer = ProviderContainer(
        overrides: [
          createAutomobileUseCaseProvider
              .overrideWithValue(_ErrorCreateAutomobileUseCase()),
          getAutomobilesUseCaseProvider
              .overrideWithValue(_FakeGetAutomobilesUseCase()),
        ],
      );
      addTearDown(errorContainer.dispose);

      await errorContainer
          .read(createAutomobileStateProvider.notifier)
          .create(GasLogFixtures.automobileForCreate());

      final state = errorContainer.read(createAutomobileStateProvider);
      expect(state.hasError, isTrue);
    });
  });
}
