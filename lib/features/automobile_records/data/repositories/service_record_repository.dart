import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/service_record.dart';
import '../datasources/service_record_remote_datasource.dart';
import '../mappers/automobile_records_api_mapper.dart';

abstract interface class IServiceRecordRepository {
  Future<List<ServiceRecord>> getRecords(int autoId);
  Future<ServiceRecord> getRecordById(int autoId, int id);
  Future<ServiceRecord> createRecord(int autoId, ServiceRecord r);
  Future<void> updateRecord(int autoId, int id, ServiceRecord r);
  Future<void> deleteRecord(int autoId, int id);
}

class _ServiceRecordApiRepository implements IServiceRecordRepository {
  _ServiceRecordApiRepository(this._remote);

  final ServiceRecordRemoteDataSource _remote;

  @override
  Future<List<ServiceRecord>> getRecords(int autoId) async {
    final apiList = await _remote.getRecords(autoId);
    return apiList.map(AutomobileRecordsApiMapper.serviceFromApi).toList();
  }

  @override
  Future<ServiceRecord> getRecordById(int autoId, int id) async {
    final api = await _remote.getRecordById(autoId, id);
    return AutomobileRecordsApiMapper.serviceFromApi(api);
  }

  @override
  Future<ServiceRecord> createRecord(int autoId, ServiceRecord r) async {
    final dto = AutomobileRecordsApiMapper.serviceToCreate(r);
    final api = await _remote.createRecord(autoId, dto);
    return AutomobileRecordsApiMapper.serviceFromApi(api);
  }

  @override
  Future<void> updateRecord(int autoId, int id, ServiceRecord r) async {
    final dto = AutomobileRecordsApiMapper.serviceToUpdate(r);
    await _remote.updateRecord(autoId, id, dto);
  }

  @override
  Future<void> deleteRecord(int autoId, int id) =>
      _remote.deleteRecord(autoId, id);
}

final serviceRecordRepositoryProvider = Provider<IServiceRecordRepository>(
  (ref) => _ServiceRecordApiRepository(
      ref.watch(serviceRecordRemoteDataSourceProvider)),
);
