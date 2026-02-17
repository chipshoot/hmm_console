import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/providers/selected_automobile_provider.dart';
import 'package:hmm_console/features/gas_log/states/create_gas_log_state.dart';
import 'package:hmm_console/features/gas_log/usecases/create_gas_log_usecase.dart';
import 'package:hmm_console/features/gas_log/usecases/get_gas_logs_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeCreateGasLogUseCase implements CreateGasLogUseCase {
  GasLog? lastInput;
  int? lastAutoId;

  @override
  Future<GasLog> call(int autoId, GasLog gasLog) async {
    lastAutoId = autoId;
    lastInput = gasLog;
    return gasLog.copyWith(id: 99);
  }
}

class _FakeGetGasLogsUseCase implements GetGasLogsUseCase {
  @override
  Future<PaginatedResponse<GasLog>> call(
    int autoId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return PaginatedResponse(
      items: [],
      meta: PaginationMeta(
        totalCount: 0,
        pageSize: pageSize,
        currentPage: page,
        totalPages: 1,
      ),
    );
  }
}

void main() {
  group('CreateGasLogState', () {
    late _FakeCreateGasLogUseCase fakeCreateUseCase;
    late ProviderContainer container;

    setUp(() {
      fakeCreateUseCase = _FakeCreateGasLogUseCase();
      container = ProviderContainer(
        overrides: [
          createGasLogUseCaseProvider.overrideWithValue(fakeCreateUseCase),
          getGasLogsUseCaseProvider
              .overrideWithValue(_FakeGetGasLogsUseCase()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('initial state is null', () {
      final state = container.read(createGasLogStateProvider);
      expect(state.value, isNull);
    });

    test('create delegates to use case and returns created gas log', () async {
      final input = GasLogFixtures.gasLog(id: null);
      await container.read(createGasLogStateProvider.notifier).create(42, input);

      final state = container.read(createGasLogStateProvider);
      expect(state.value?.id, 99);
      expect(fakeCreateUseCase.lastAutoId, 42);
      expect(fakeCreateUseCase.lastInput, isNotNull);
    });

    test('create sets loading then data state', () async {
      final states = <AsyncValue<GasLog?>>[];
      container.listen(createGasLogStateProvider, (prev, next) {
        states.add(next);
      });

      await container
          .read(createGasLogStateProvider.notifier)
          .create(42, GasLogFixtures.gasLog(id: null));

      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.hasValue, isTrue);
    });
  });
}
