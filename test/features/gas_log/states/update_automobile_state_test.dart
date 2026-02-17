import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/states/update_automobile_state.dart';
import 'package:hmm_console/features/gas_log/usecases/get_automobiles_usecase.dart';
import 'package:hmm_console/features/gas_log/usecases/update_automobile_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeUpdateAutomobileUseCase implements UpdateAutomobileUseCase {
  int? lastId;
  Automobile? lastInput;

  @override
  Future<void> call(int id, Automobile automobile) async {
    lastId = id;
    lastInput = automobile;
  }
}

class _ErrorUpdateAutomobileUseCase implements UpdateAutomobileUseCase {
  @override
  Future<void> call(int id, Automobile automobile) async {
    throw Exception('Update failed');
  }
}

class _FakeGetAutomobilesUseCase implements GetAutomobilesUseCase {
  @override
  Future<List<Automobile>> call() async => [];
}

void main() {
  group('UpdateAutomobileState', () {
    late _FakeUpdateAutomobileUseCase fakeUseCase;
    late ProviderContainer container;

    setUp(() {
      fakeUseCase = _FakeUpdateAutomobileUseCase();
      container = ProviderContainer(
        overrides: [
          updateAutomobileUseCaseProvider.overrideWithValue(fakeUseCase),
          getAutomobilesUseCaseProvider
              .overrideWithValue(_FakeGetAutomobilesUseCase()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('updateAutomobile delegates to use case', () async {
      final input = GasLogFixtures.automobile(id: 42);
      await container
          .read(updateAutomobileStateProvider.notifier)
          .updateAutomobile(42, input);

      expect(fakeUseCase.lastId, 42);
      expect(fakeUseCase.lastInput, isNotNull);
    });

    test('updateAutomobile sets loading then data state', () async {
      final states = <AsyncValue<void>>[];
      container.listen(updateAutomobileStateProvider, (prev, next) {
        states.add(next);
      });

      await container
          .read(updateAutomobileStateProvider.notifier)
          .updateAutomobile(42, GasLogFixtures.automobile(id: 42));

      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.hasValue, isTrue);
    });

    test('error state on failure', () async {
      final errorContainer = ProviderContainer(
        overrides: [
          updateAutomobileUseCaseProvider
              .overrideWithValue(_ErrorUpdateAutomobileUseCase()),
          getAutomobilesUseCaseProvider
              .overrideWithValue(_FakeGetAutomobilesUseCase()),
        ],
      );
      addTearDown(errorContainer.dispose);

      await errorContainer
          .read(updateAutomobileStateProvider.notifier)
          .updateAutomobile(42, GasLogFixtures.automobile(id: 42));

      final state = errorContainer.read(updateAutomobileStateProvider);
      expect(state.hasError, isTrue);
    });
  });
}
