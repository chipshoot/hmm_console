import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/providers/selected_automobile_provider.dart';
import 'package:hmm_console/features/gas_log/states/gas_logs_state.dart';
import 'package:hmm_console/features/gas_log/usecases/get_gas_logs_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeGetGasLogsUseCase implements GetGasLogsUseCase {
  int callCount = 0;
  int? lastAutoId;
  int? lastPage;
  List<GasLog> items = [];
  PaginationMeta? meta;

  @override
  Future<PaginatedResponse<GasLog>> call(
    int autoId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    callCount++;
    lastAutoId = autoId;
    lastPage = page;
    return PaginatedResponse(
      items: items,
      meta: meta ??
          PaginationMeta(
            totalCount: items.length,
            pageSize: pageSize,
            currentPage: page,
            totalPages: 1,
          ),
    );
  }
}

void main() {
  group('GasLogsData', () {
    test('hasMore returns false when no meta', () {
      const data = GasLogsData();
      expect(data.hasMore, isFalse);
    });

    test('hasMore returns true when meta indicates next page', () {
      final data = GasLogsData(
        items: [GasLogFixtures.gasLog()],
        meta: const PaginationMeta(
          totalCount: 40,
          pageSize: 20,
          currentPage: 1,
          totalPages: 2,
        ),
      );
      expect(data.hasMore, isTrue);
    });

    test('currentPage defaults to 0 when no meta', () {
      const data = GasLogsData();
      expect(data.currentPage, 0);
    });
  });

  group('GasLogsState', () {
    late _FakeGetGasLogsUseCase fakeUseCase;
    late ProviderContainer container;

    setUp(() {
      fakeUseCase = _FakeGetGasLogsUseCase();
      container = ProviderContainer(
        overrides: [
          getGasLogsUseCaseProvider.overrideWithValue(fakeUseCase),
        ],
      );
      addTearDown(container.dispose);
    });

    test('build returns empty data when no automobile selected', () async {
      final data = await container.read(gasLogsStateProvider.future);
      expect(data.items, isEmpty);
      expect(data.meta, isNull);
      expect(fakeUseCase.callCount, 0);
    });

    test('build fetches gas logs when automobile is selected', () async {
      fakeUseCase.items = [GasLogFixtures.gasLog()];

      container.read(selectedAutomobileIdProvider.notifier).select(42);

      // Wait for the async rebuild
      await Future<void>.delayed(Duration.zero);
      final data = await container.read(gasLogsStateProvider.future);

      expect(data.items, hasLength(1));
      expect(fakeUseCase.lastAutoId, 42);
    });

    test('refresh reloads from first page', () async {
      fakeUseCase.items = [GasLogFixtures.gasLog()];
      container.read(selectedAutomobileIdProvider.notifier).select(42);
      await Future<void>.delayed(Duration.zero);
      await container.read(gasLogsStateProvider.future);

      fakeUseCase.items = [
        GasLogFixtures.gasLog(id: 1),
        GasLogFixtures.gasLog(id: 2),
      ];
      await container.read(gasLogsStateProvider.notifier).refresh();

      final data = container.read(gasLogsStateProvider).value;
      expect(data?.items, hasLength(2));
    });

    test('refresh does nothing when no automobile selected', () async {
      await container.read(gasLogsStateProvider.notifier).refresh();
      expect(fakeUseCase.callCount, 0);
    });

    test('loadNextPage appends items', () async {
      fakeUseCase.items = [GasLogFixtures.gasLog(id: 1)];
      fakeUseCase.meta = const PaginationMeta(
        totalCount: 2,
        pageSize: 1,
        currentPage: 1,
        totalPages: 2,
      );

      container.read(selectedAutomobileIdProvider.notifier).select(42);
      await Future<void>.delayed(Duration.zero);
      await container.read(gasLogsStateProvider.future);

      // Set up next page data
      fakeUseCase.items = [GasLogFixtures.gasLog(id: 2)];
      fakeUseCase.meta = const PaginationMeta(
        totalCount: 2,
        pageSize: 1,
        currentPage: 2,
        totalPages: 2,
      );

      await container.read(gasLogsStateProvider.notifier).loadNextPage();

      final data = container.read(gasLogsStateProvider).value;
      expect(data?.items, hasLength(2));
      expect(data?.items[0].id, 1);
      expect(data?.items[1].id, 2);
      expect(fakeUseCase.lastPage, 2);
    });

    test('loadNextPage does nothing when no more pages', () async {
      fakeUseCase.items = [GasLogFixtures.gasLog()];
      container.read(selectedAutomobileIdProvider.notifier).select(42);
      await Future<void>.delayed(Duration.zero);
      await container.read(gasLogsStateProvider.future);

      final countBefore = fakeUseCase.callCount;
      await container.read(gasLogsStateProvider.notifier).loadNextPage();
      expect(fakeUseCase.callCount, countBefore);
    });
  });
}
