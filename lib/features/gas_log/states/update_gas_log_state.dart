import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/gas_log.dart';
import '../states/gas_logs_state.dart';
import '../usecases/update_gas_log_usecase.dart';

class UpdateGasLogState extends AsyncNotifier<GasLog?> {
  @override
  GasLog? build() => null;

  Future<void> updateGasLog(int autoId, int id, GasLog gasLog) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updated = await ref
          .read(updateGasLogUseCaseProvider)
          .call(autoId, id, gasLog);
      ref.read(gasLogsStateProvider.notifier).refresh();
      return updated;
    });
  }
}

final updateGasLogStateProvider =
    AsyncNotifierProvider<UpdateGasLogState, GasLog?>(
  () => UpdateGasLogState(),
);
