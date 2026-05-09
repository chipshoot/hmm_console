import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/scheduled_service_repository.dart';
import '../domain/entities/auto_scheduled_service.dart';
import 'scheduled_services_state.dart';

class MutateScheduledServiceState extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AutoScheduledService?> create(
      int autoId, AutoScheduledService schedule) async {
    state = const AsyncValue.loading();
    AutoScheduledService? created;
    state = await AsyncValue.guard(() async {
      created = await ref
          .read(scheduledServiceRepositoryProvider)
          .createSchedule(autoId, schedule);
    });
    if (state.hasValue) _invalidate();
    return created;
  }

  Future<void> edit(int autoId, int id, AutoScheduledService schedule) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref
        .read(scheduledServiceRepositoryProvider)
        .updateSchedule(autoId, id, schedule));
    if (state.hasValue) _invalidate();
  }

  Future<void> delete(int autoId, int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref
        .read(scheduledServiceRepositoryProvider)
        .deleteSchedule(autoId, id));
    if (state.hasValue) _invalidate();
  }

  void _invalidate() {
    ref.invalidate(scheduledServicesStateProvider);
    ref.invalidate(soonestScheduledServiceStateProvider);
  }
}

final mutateScheduledServiceStateProvider =
    AsyncNotifierProvider<MutateScheduledServiceState, void>(
  () => MutateScheduledServiceState(),
);
