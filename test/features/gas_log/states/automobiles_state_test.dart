import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/features/gas_log/usecases/get_automobiles_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeGetAutomobilesUseCase implements GetAutomobilesUseCase {
  List<Automobile> result = [];
  int callCount = 0;

  @override
  Future<List<Automobile>> call() async {
    callCount++;
    return result;
  }
}

class _ErrorGetAutomobilesUseCase implements GetAutomobilesUseCase {
  @override
  Future<List<Automobile>> call() async {
    throw Exception('Network error');
  }
}

void main() {
  group('AutomobilesState', () {
    late _FakeGetAutomobilesUseCase fakeUseCase;
    late ProviderContainer container;

    setUp(() {
      fakeUseCase = _FakeGetAutomobilesUseCase();
      container = ProviderContainer(
        overrides: [
          getAutomobilesUseCaseProvider.overrideWithValue(fakeUseCase),
        ],
      );
      addTearDown(container.dispose);
    });

    test('build fetches automobiles', () async {
      fakeUseCase.result = [
        GasLogFixtures.automobile(id: 1),
        GasLogFixtures.automobile(id: 2),
      ];

      // Read the future to trigger build
      final state = await container.read(automobilesStateProvider.future);
      expect(state, hasLength(2));
      expect(state[0].id, 1);
      expect(fakeUseCase.callCount, 1);
    });

    test('build returns empty list when no automobiles', () async {
      final state = await container.read(automobilesStateProvider.future);
      expect(state, isEmpty);
    });

    test('refresh reloads data', () async {
      fakeUseCase.result = [GasLogFixtures.automobile(id: 1)];
      await container.read(automobilesStateProvider.future);

      fakeUseCase.result = [
        GasLogFixtures.automobile(id: 1),
        GasLogFixtures.automobile(id: 2),
      ];
      await container.read(automobilesStateProvider.notifier).refresh();

      final state = container.read(automobilesStateProvider);
      expect(state.value, hasLength(2));
      expect(fakeUseCase.callCount, greaterThanOrEqualTo(2));
    });

    test('error state on failure', () async {
      final errorContainer = ProviderContainer(
        overrides: [
          getAutomobilesUseCaseProvider
              .overrideWithValue(_ErrorGetAutomobilesUseCase()),
        ],
      );

      // Listen for state changes and wait for error
      final states = <AsyncValue<List<Automobile>>>[];
      errorContainer.listen(automobilesStateProvider, (prev, next) {
        states.add(next);
      });

      // Wait for the async build to complete with error
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = errorContainer.read(automobilesStateProvider);
      expect(state.hasError, isTrue);

      errorContainer.dispose();
    });
  });
}
