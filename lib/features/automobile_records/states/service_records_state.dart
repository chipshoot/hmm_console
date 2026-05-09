import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/repository_providers.dart';
import '../domain/entities/service_record.dart';
import '_records_automobile_id_provider.dart';

class ServiceRecordsState extends AsyncNotifier<List<ServiceRecord>> {
  @override
  Future<List<ServiceRecord>> build() async {
    final autoId = ref.watch(recordsAutomobileIdProvider);
    if (autoId == null) return [];
    return ref.watch(serviceRecordRepositoryModeProvider).getRecords(autoId);
  }

  Future<void> refresh() async {
    final autoId = ref.read(recordsAutomobileIdProvider);
    if (autoId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(serviceRecordRepositoryModeProvider).getRecords(autoId),
    );
  }
}

final serviceRecordsStateProvider =
    AsyncNotifierProvider<ServiceRecordsState, List<ServiceRecord>>(
  () => ServiceRecordsState(),
);
