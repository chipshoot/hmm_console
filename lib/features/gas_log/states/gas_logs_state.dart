import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/pagination.dart';
import '../domain/entities/gas_log.dart';
import '../providers/selected_automobile_provider.dart';
import '../usecases/get_gas_logs_usecase.dart';

class GasLogsData {
  final List<GasLog> items;
  final PaginationMeta? meta;

  const GasLogsData({this.items = const [], this.meta});

  bool get hasMore => meta?.hasNextPage ?? false;
  int get currentPage => meta?.currentPage ?? 0;
}

class GasLogsState extends AsyncNotifier<GasLogsData> {
  @override
  Future<GasLogsData> build() async {
    final autoId = ref.watch(selectedAutomobileIdProvider);
    if (autoId == null) return const GasLogsData();

    final response =
        await ref.watch(getGasLogsUseCaseProvider).call(autoId);
    return GasLogsData(items: response.items, meta: response.meta);
  }

  Future<void> loadNextPage() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;

    final autoId = ref.read(selectedAutomobileIdProvider);
    if (autoId == null) return;

    final nextPage = current.currentPage + 1;
    state = await AsyncValue.guard(() async {
      final response = await ref
          .read(getGasLogsUseCaseProvider)
          .call(autoId, page: nextPage);
      return GasLogsData(
        items: [...current.items, ...response.items],
        meta: response.meta,
      );
    });
  }

  Future<void> refresh() async {
    final autoId = ref.read(selectedAutomobileIdProvider);
    if (autoId == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response =
          await ref.read(getGasLogsUseCaseProvider).call(autoId);
      return GasLogsData(items: response.items, meta: response.meta);
    });
  }
}

final gasLogsStateProvider =
    AsyncNotifierProvider<GasLogsState, GasLogsData>(
  () => GasLogsState(),
);
