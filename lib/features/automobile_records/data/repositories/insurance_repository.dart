import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auto_insurance_policy.dart';
import '../datasources/insurance_remote_datasource.dart';
import '../mappers/automobile_records_api_mapper.dart';

abstract interface class IInsuranceRepository {
  Future<List<AutoInsurancePolicy>> getPolicies(int autoId);
  Future<AutoInsurancePolicy?> getActivePolicy(int autoId);
  Future<AutoInsurancePolicy> getPolicyById(int autoId, int id);
  Future<AutoInsurancePolicy> createPolicy(int autoId, AutoInsurancePolicy p);
  Future<void> updatePolicy(int autoId, int id, AutoInsurancePolicy p);
  Future<void> deletePolicy(int autoId, int id);
}

class _InsuranceApiRepository implements IInsuranceRepository {
  _InsuranceApiRepository(this._remote);

  final InsuranceRemoteDataSource _remote;

  @override
  Future<List<AutoInsurancePolicy>> getPolicies(int autoId) async {
    final apiList = await _remote.getPolicies(autoId);
    return apiList.map(AutomobileRecordsApiMapper.insuranceFromApi).toList();
  }

  @override
  Future<AutoInsurancePolicy?> getActivePolicy(int autoId) async {
    final api = await _remote.getActivePolicy(autoId);
    return api == null
        ? null
        : AutomobileRecordsApiMapper.insuranceFromApi(api);
  }

  @override
  Future<AutoInsurancePolicy> getPolicyById(int autoId, int id) async {
    final api = await _remote.getPolicyById(autoId, id);
    return AutomobileRecordsApiMapper.insuranceFromApi(api);
  }

  @override
  Future<AutoInsurancePolicy> createPolicy(
      int autoId, AutoInsurancePolicy p) async {
    final dto = AutomobileRecordsApiMapper.insuranceToCreate(p);
    final api = await _remote.createPolicy(autoId, dto);
    return AutomobileRecordsApiMapper.insuranceFromApi(api);
  }

  @override
  Future<void> updatePolicy(int autoId, int id, AutoInsurancePolicy p) async {
    final dto = AutomobileRecordsApiMapper.insuranceToUpdate(p);
    await _remote.updatePolicy(autoId, id, dto);
  }

  @override
  Future<void> deletePolicy(int autoId, int id) =>
      _remote.deletePolicy(autoId, id);
}

final insuranceRepositoryProvider = Provider<IInsuranceRepository>(
  (ref) =>
      _InsuranceApiRepository(ref.watch(insuranceRemoteDataSourceProvider)),
);
