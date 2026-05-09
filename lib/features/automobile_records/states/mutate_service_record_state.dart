import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/service_record_repository.dart';
import '../domain/entities/service_record.dart';
import 'service_records_state.dart';

class MutateServiceRecordState extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<ServiceRecord?> create(int autoId, ServiceRecord record) async {
    state = const AsyncValue.loading();
    ServiceRecord? created;
    state = await AsyncValue.guard(() async {
      created = await ref
          .read(serviceRecordRepositoryProvider)
          .createRecord(autoId, record);
    });
    if (state.hasValue) _invalidate();
    return created;
  }

  Future<void> edit(int autoId, int id, ServiceRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref
        .read(serviceRecordRepositoryProvider)
        .updateRecord(autoId, id, record));
    if (state.hasValue) _invalidate();
  }

  Future<void> delete(int autoId, int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() =>
        ref.read(serviceRecordRepositoryProvider).deleteRecord(autoId, id));
    if (state.hasValue) _invalidate();
  }

  void _invalidate() {
    ref.invalidate(serviceRecordsStateProvider);
  }
}

final mutateServiceRecordStateProvider =
    AsyncNotifierProvider<MutateServiceRecordState, void>(
  () => MutateServiceRecordState(),
);
