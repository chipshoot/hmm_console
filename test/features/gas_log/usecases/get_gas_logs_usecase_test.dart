import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/gas_log/data/repositories/gas_log_api_repository.dart';
import 'package:hmm_console/features/gas_log/data/repositories/i_gas_log_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/usecases/get_gas_logs_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeGasLogRepository implements IGasLogRepository {
  List<GasLog> logs = [];
  int? lastAutoId;
  int? lastPage;
  int? lastPageSize;

  @override
  Future<PaginatedResponse<GasLog>> getGasLogs(
    int autoId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    lastAutoId = autoId;
    lastPage = page;
    lastPageSize = pageSize;
    return PaginatedResponse(
      items: logs,
      meta: PaginationMeta(
        totalCount: logs.length,
        pageSize: pageSize,
        currentPage: page,
        totalPages: 1,
      ),
    );
  }

  @override
  Future<GasLog> getGasLogById(int autoId, int id) =>
      throw UnimplementedError();
  @override
  Future<GasLog> createGasLog(int autoId, GasLog gasLog) =>
      throw UnimplementedError();
  @override
  Future<GasLog> updateGasLog(int autoId, int id, GasLog gasLog) =>
      throw UnimplementedError();
  @override
  Future<void> deleteGasLog(int autoId, int id) =>
      throw UnimplementedError();
}

void main() {
  group('GetGasLogsUseCase', () {
    late _FakeGasLogRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = _FakeGasLogRepository();
      container = ProviderContainer(
        overrides: [
          gasLogRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
    });

    test('delegates to repository with correct parameters', () async {
      fakeRepo.logs = [GasLogFixtures.gasLog()];

      final useCase = container.read(getGasLogsUseCaseProvider);
      final result = await useCase.call(42, page: 2, pageSize: 10);

      expect(result.items, hasLength(1));
      expect(fakeRepo.lastAutoId, 42);
      expect(fakeRepo.lastPage, 2);
      expect(fakeRepo.lastPageSize, 10);
    });

    test('uses default page and pageSize', () async {
      final useCase = container.read(getGasLogsUseCaseProvider);
      await useCase.call(42);

      expect(fakeRepo.lastPage, 1);
      expect(fakeRepo.lastPageSize, 20);
    });
  });
}
