import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/gas_log.dart';
import '../states/gas_logs_state.dart';
import '../usecases/create_gas_log_usecase.dart';

class CreateGasLogState extends AsyncNotifier<GasLog?> {
  @override
  GasLog? build() => null;

  Future<void> create(int autoId, GasLog gasLog) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final created =
          await ref.read(createGasLogUseCaseProvider).call(autoId, gasLog);
      ref.read(gasLogsStateProvider.notifier).refresh();
      return created;
    });
  }
}

final createGasLogStateProvider =
    AsyncNotifierProvider<CreateGasLogState, GasLog?>(
  () => CreateGasLogState(),
);
