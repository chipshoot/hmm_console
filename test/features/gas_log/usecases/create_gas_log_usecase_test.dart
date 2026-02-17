import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmm_console/core/network/pagination.dart';
import 'package:hmm_console/features/gas_log/data/repositories/gas_log_api_repository.dart';
import 'package:hmm_console/features/gas_log/data/repositories/i_gas_log_repository.dart';
import 'package:hmm_console/features/gas_log/domain/entities/gas_log.dart';
import 'package:hmm_console/features/gas_log/usecases/create_gas_log_usecase.dart';

import '../helpers/gas_log_fixtures.dart';

class _FakeGasLogRepository implements IGasLogRepository {
  GasLog? createdLog;
  int? createdAutoId;

  @override
  Future<GasLog> createGasLog(int autoId, GasLog gasLog) async {
    createdAutoId = autoId;
    createdLog = gasLog;
    return gasLog.copyWith(id: 99);
  }

  @override
  Future<PaginatedResponse<GasLog>> getGasLogs(int autoId,
          {int page = 1, int pageSize = 20}) =>
      throw UnimplementedError();
  @override
  Future<GasLog> getGasLogById(int autoId, int id) =>
      throw UnimplementedError();
  @override
  Future<GasLog> updateGasLog(int autoId, int id, GasLog gasLog) =>
      throw UnimplementedError();
  @override
  Future<void> deleteGasLog(int autoId, int id) =>
      throw UnimplementedError();
}

void main() {
  group('CreateGasLogUseCase', () {
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

    test('creates gas log and returns it with ID', () async {
      final input = GasLogFixtures.gasLog(id: null);
      final useCase = container.read(createGasLogUseCaseProvider);
      final result = await useCase.call(42, input);

      expect(result.id, 99);
      expect(fakeRepo.createdAutoId, 42);
      expect(fakeRepo.createdLog?.automobileId, input.automobileId);
    });
  });
}
