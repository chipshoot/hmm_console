import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/states/delete_gas_log_state.dart';
import 'package:hmm_console/features/gas_log/usecases/delete_gas_log_usecase.dart';
import 'package:hmm_console/features/gas_log/usecases/get_gas_logs_usecase.dart';

class _FakeDeleteGasLogUseCase implements DeleteGasLogUseCase {
  int? lastAutoId;
  int? lastId;

  @override
  Future<void> call(int autoId, int id) async {
    lastAutoId = autoId;
    lastId = id;
  }
}

class _ErrorDeleteGasLogUseCase implements DeleteGasLogUseCase {
  @override
  Future<void> call(int autoId, int id) async {
    throw Exception('Delete failed');
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
  group('DeleteGasLogState', () {
    late _FakeDeleteGasLogUseCase fakeDeleteUseCase;
    late ProviderContainer container;

    setUp(() {
      fakeDeleteUseCase = _FakeDeleteGasLogUseCase();
      container = ProviderContainer(
        overrides: [
          deleteGasLogUseCaseProvider.overrideWithValue(fakeDeleteUseCase),
          getGasLogsUseCaseProvider
              .overrideWithValue(_FakeGetGasLogsUseCase()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('initial state is false', () {
      final state = container.read(deleteGasLogStateProvider);
      expect(state.value, isFalse);
    });

    test('delete delegates to use case and returns true', () async {
      await container.read(deleteGasLogStateProvider.notifier).delete(42, 7);

      final state = container.read(deleteGasLogStateProvider);
      expect(state.value, isTrue);
      expect(fakeDeleteUseCase.lastAutoId, 42);
      expect(fakeDeleteUseCase.lastId, 7);
    });

    test('delete sets loading then data state', () async {
      final states = <AsyncValue<bool>>[];
      container.listen(deleteGasLogStateProvider, (prev, next) {
        states.add(next);
      });

      await container.read(deleteGasLogStateProvider.notifier).delete(42, 7);

      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.value, isTrue);
    });

    test('error state on failure', () async {
      final errorContainer = ProviderContainer(
        overrides: [
          deleteGasLogUseCaseProvider
              .overrideWithValue(_ErrorDeleteGasLogUseCase()),
          getGasLogsUseCaseProvider
              .overrideWithValue(_FakeGetGasLogsUseCase()),
        ],
      );
      addTearDown(errorContainer.dispose);

      await errorContainer
          .read(deleteGasLogStateProvider.notifier)
          .delete(42, 7);

      final state = errorContainer.read(deleteGasLogStateProvider);
      expect(state.hasError, isTrue);
    });
  });
}
