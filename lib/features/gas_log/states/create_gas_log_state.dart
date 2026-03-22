import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/gas_log.dart';
import '../states/automobiles_state.dart';
import '../states/gas_logs_state.dart';
import '../states/gas_stations_state.dart';
import '../usecases/create_gas_log_usecase.dart';
import '../usecases/create_history_gas_log_usecase.dart';

class CreateGasLogState extends AsyncNotifier<GasLog?> {
  @override
  GasLog? build() => null;

  Future<void> create(int autoId, GasLog gasLog,
      {bool isHistorical = false}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      var logToCreate = gasLog;

      // If station name is provided but no station ID, resolve or create station
      if (gasLog.stationName != null &&
          gasLog.stationName!.isNotEmpty &&
          gasLog.stationId == null) {
        final station = await ref
            .read(gasStationsStateProvider.notifier)
            .getOrCreateStation(gasLog.stationName!);
        logToCreate = gasLog.copyWith(stationId: station.id);
      }

      final GasLog created;
      if (isHistorical) {
        created = await ref
            .read(createHistoryGasLogUseCaseProvider)
            .call(autoId, logToCreate);
      } else {
        created = await ref
            .read(createGasLogUseCaseProvider)
            .call(autoId, logToCreate);
        // Real-time creation updates automobile meter on backend; refresh local state
        ref.read(automobilesStateProvider.notifier).refresh();
      }

      ref.read(gasLogsStateProvider.notifier).refresh();
      return created;
    });
  }
}

final createGasLogStateProvider =
    AsyncNotifierProvider<CreateGasLogState, GasLog?>(
  () => CreateGasLogState(),
);
