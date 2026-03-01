import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/gas_log/data/repositories/gas_station_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_station.dart';
import 'package:hmm_console/features/gas_log/providers/selected_automobile_provider.dart';
import 'package:hmm_console/features/gas_log/states/update_gas_log_state.dart';
import 'package:hmm_console/features/gas_log/usecases/get_gas_logs_usecase.dart';
import 'package:hmm_console/features/gas_log/usecases/update_gas_log_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeUpdateGasLogUseCase implements UpdateGasLogUseCase {
  int? lastAutoId;
  int? lastId;
  GasLog? lastInput;

  @override
  Future<GasLog> call(int autoId, int id, GasLog gasLog) async {
    lastAutoId = autoId;
    lastId = id;
    lastInput = gasLog;
    return gasLog;
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

class _FakeGasStationRepository implements IGasStationRepository {
  @override
  Future<List<GasStation>> getGasStations() async => [];

  @override
  Future<GasStation> createGasStation(GasStation station) async =>
      station.copyWith(id: 10);

  @override
  Future<GasStation> updateGasStation(int id, GasStation station) async =>
      station;

  @override
  Future<void> deleteGasStation(int id) async {}
}

void main() {
  group('UpdateGasLogState', () {
    late _FakeUpdateGasLogUseCase fakeUpdateUseCase;
    late ProviderContainer container;

    setUp(() {
      fakeUpdateUseCase = _FakeUpdateGasLogUseCase();
      container = ProviderContainer(
        overrides: [
          updateGasLogUseCaseProvider.overrideWithValue(fakeUpdateUseCase),
          getGasLogsUseCaseProvider
              .overrideWithValue(_FakeGetGasLogsUseCase()),
          gasStationRepositoryProvider
              .overrideWithValue(_FakeGasStationRepository()),
        ],
      );
      // Set selected automobile so gasLogsState.refresh() works
      container.read(selectedAutomobileIdProvider.notifier).select(42);
      addTearDown(container.dispose);
    });

    test('initial state is null', () {
      final state = container.read(updateGasLogStateProvider);
      expect(state.value, isNull);
    });

    test('updateGasLog delegates to use case', () async {
      final input = GasLogFixtures.gasLog();
      await container
          .read(updateGasLogStateProvider.notifier)
          .updateGasLog(42, 1, input);

      final state = container.read(updateGasLogStateProvider);
      expect(state.value, isNotNull);
      expect(fakeUpdateUseCase.lastAutoId, 42);
      expect(fakeUpdateUseCase.lastId, 1);
    });

    test('updateGasLog sets loading then data state', () async {
      final states = <AsyncValue<GasLog?>>[];
      container.listen(updateGasLogStateProvider, (prev, next) {
        states.add(next);
      });

      await container
          .read(updateGasLogStateProvider.notifier)
          .updateGasLog(42, 1, GasLogFixtures.gasLog());

      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.hasValue, isTrue);
    });
  });
}
