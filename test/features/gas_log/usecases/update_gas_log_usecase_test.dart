import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/gas_log/data/repositories/gas_log_api_repository.dart';
import 'package:hmm_console/features/gas_log/data/repositories/i_gas_log_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/usecases/update_gas_log_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeGasLogRepository implements IGasLogRepository {
  int? updatedAutoId;
  int? updatedId;
  GasLog? updatedLog;

  @override
  Future<GasLog> updateGasLog(int autoId, int id, GasLog gasLog) async {
    updatedAutoId = autoId;
    updatedId = id;
    updatedLog = gasLog;
    return gasLog;
  }

  @override
  Future<PaginatedResponse<GasLog>> getGasLogs(int autoId,
          {int page = 1, int pageSize = 20}) =>
      throw UnimplementedError();
  @override
  Future<GasLog> getGasLogById(int autoId, int id) =>
      throw UnimplementedError();
  @override
  Future<GasLog> createGasLog(int autoId, GasLog gasLog) =>
      throw UnimplementedError();
  @override
  Future<void> deleteGasLog(int autoId, int id) =>
      throw UnimplementedError();
}

void main() {
  group('UpdateGasLogUseCase', () {
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
      final input = GasLogFixtures.gasLog();
      final useCase = container.read(updateGasLogUseCaseProvider);
      final result = await useCase.call(42, 1, input);

      expect(result.id, input.id);
      expect(fakeRepo.updatedAutoId, 42);
      expect(fakeRepo.updatedId, 1);
      expect(fakeRepo.updatedLog, isNotNull);
    });
  });
}
