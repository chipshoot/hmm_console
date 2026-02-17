import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../states/gas_logs_state.dart';
import '../usecases/delete_gas_log_usecase.dart';

class DeleteGasLogState extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> delete(int autoId, int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(deleteGasLogUseCaseProvider).call(autoId, id);
      ref.read(gasLogsStateProvider.notifier).refresh();
      return true;
    });
  }
}

final deleteGasLogStateProvider =
    AsyncNotifierProvider<DeleteGasLogState, bool>(
  () => DeleteGasLogState(),
);
