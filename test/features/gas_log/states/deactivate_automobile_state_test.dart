import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/states/deactivate_automobile_state.dart';
import 'package:hmm_console/features/gas_log/usecases/deactivate_automobile_usecase.dart';
import 'package:hmm_console/features/gas_log/usecases/get_automobiles_usecase.dart';

class _FakeDeactivateAutomobileUseCase implements DeactivateAutomobileUseCase {
  int? lastId;

  @override
  Future<void> call(int id) async {
    lastId = id;
  }
}

class _ErrorDeactivateAutomobileUseCase implements DeactivateAutomobileUseCase {
  @override
  Future<void> call(int id) async {
    throw Exception('Deactivate failed');
  }
}

class _FakeGetAutomobilesUseCase implements GetAutomobilesUseCase {
  @override
  Future<List<Automobile>> call() async => [];
}

void main() {
  group('DeactivateAutomobileState', () {
    late _FakeDeactivateAutomobileUseCase fakeUseCase;
    late ProviderContainer container;

    setUp(() {
      fakeUseCase = _FakeDeactivateAutomobileUseCase();
      container = ProviderContainer(
        overrides: [
          deactivateAutomobileUseCaseProvider.overrideWithValue(fakeUseCase),
          getAutomobilesUseCaseProvider
              .overrideWithValue(_FakeGetAutomobilesUseCase()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('deactivate delegates to use case with correct id', () async {
      await container
          .read(deactivateAutomobileStateProvider.notifier)
          .deactivate(42);

      expect(fakeUseCase.lastId, 42);
    });

    test('deactivate sets loading then data state', () async {
      final states = <AsyncValue<void>>[];
      container.listen(deactivateAutomobileStateProvider, (prev, next) {
        states.add(next);
      });

      await container
          .read(deactivateAutomobileStateProvider.notifier)
          .deactivate(42);

      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.hasValue, isTrue);
    });

    test('error state on failure', () async {
      final errorContainer = ProviderContainer(
        overrides: [
          deactivateAutomobileUseCaseProvider
              .overrideWithValue(_ErrorDeactivateAutomobileUseCase()),
          getAutomobilesUseCaseProvider
              .overrideWithValue(_FakeGetAutomobilesUseCase()),
        ],
      );
      addTearDown(errorContainer.dispose);

      await errorContainer
          .read(deactivateAutomobileStateProvider.notifier)
          .deactivate(42);

      final state = errorContainer.read(deactivateAutomobileStateProvider);
      expect(state.hasError, isTrue);
    });
  });
}
