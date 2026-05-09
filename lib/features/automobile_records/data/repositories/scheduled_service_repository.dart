import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auto_scheduled_service.dart';
import '../datasources/scheduled_service_remote_datasource.dart';
import '../mappers/automobile_records_api_mapper.dart';

abstract interface class IScheduledServiceRepository {
  Future<List<AutoScheduledService>> getSchedules(int autoId);
  Future<AutoScheduledService?> getSoonest(int autoId);
  Future<AutoScheduledService> getScheduleById(int autoId, int id);
  Future<AutoScheduledService> createSchedule(
      int autoId, AutoScheduledService s);
  Future<void> updateSchedule(int autoId, int id, AutoScheduledService s);
  Future<void> deleteSchedule(int autoId, int id);
}

class _ScheduledServiceApiRepository implements IScheduledServiceRepository {
  _ScheduledServiceApiRepository(this._remote);

  final ScheduledServiceRemoteDataSource _remote;

  @override
  Future<List<AutoScheduledService>> getSchedules(int autoId) async {
    final apiList = await _remote.getSchedules(autoId);
    return apiList.map(AutomobileRecordsApiMapper.scheduleFromApi).toList();
  }

  @override
  Future<AutoScheduledService?> getSoonest(int autoId) async {
    final api = await _remote.getSoonest(autoId);
    return api == null
        ? null
        : AutomobileRecordsApiMapper.scheduleFromApi(api);
  }

  @override
  Future<AutoScheduledService> getScheduleById(int autoId, int id) async {
    final api = await _remote.getScheduleById(autoId, id);
    return AutomobileRecordsApiMapper.scheduleFromApi(api);
  }

  @override
  Future<AutoScheduledService> createSchedule(
      int autoId, AutoScheduledService s) async {
    final dto = AutomobileRecordsApiMapper.scheduleToCreate(s);
    final api = await _remote.createSchedule(autoId, dto);
    return AutomobileRecordsApiMapper.scheduleFromApi(api);
  }

  @override
  Future<void> updateSchedule(
      int autoId, int id, AutoScheduledService s) async {
    final dto = AutomobileRecordsApiMapper.scheduleToUpdate(s);
    await _remote.updateSchedule(autoId, id, dto);
  }

  @override
  Future<void> deleteSchedule(int autoId, int id) =>
      _remote.deleteSchedule(autoId, id);
}

final scheduledServiceRepositoryProvider =
    Provider<IScheduledServiceRepository>(
  (ref) => _ScheduledServiceApiRepository(
      ref.watch(scheduledServiceRemoteDataSourceProvider)),
);
