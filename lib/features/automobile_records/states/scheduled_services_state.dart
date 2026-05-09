import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../domain/entities/auto_scheduled_service.dart';
import '_records_automobile_id_provider.dart';

class ScheduledServicesState extends AsyncNotifier<List<AutoScheduledService>> {
  @override
  Future<List<AutoScheduledService>> build() async {
    final autoId = ref.watch(recordsAutomobileIdProvider);
    if (autoId == null) return [];
    return ref.watch(scheduledServiceRepositoryModeProvider).getSchedules(autoId);
  }

  Future<void> refresh() async {
    final autoId = ref.read(recordsAutomobileIdProvider);
    if (autoId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(scheduledServiceRepositoryModeProvider).getSchedules(autoId),
    );
  }
}

final scheduledServicesStateProvider =
    AsyncNotifierProvider<ScheduledServicesState, List<AutoScheduledService>>(
  () => ScheduledServicesState(),
);

class SoonestScheduledServiceState
    extends AsyncNotifier<AutoScheduledService?> {
  @override
  Future<AutoScheduledService?> build() async {
    final autoId = ref.watch(recordsAutomobileIdProvider);
    if (autoId == null) return null;
    return ref.watch(scheduledServiceRepositoryModeProvider).getSoonest(autoId);
  }

  Future<void> refresh() async {
    final autoId = ref.read(recordsAutomobileIdProvider);
    if (autoId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(scheduledServiceRepositoryModeProvider).getSoonest(autoId),
    );
  }
}

final soonestScheduledServiceStateProvider =
    AsyncNotifierProvider<SoonestScheduledServiceState, AutoScheduledService?>(
  () => SoonestScheduledServiceState(),
);
