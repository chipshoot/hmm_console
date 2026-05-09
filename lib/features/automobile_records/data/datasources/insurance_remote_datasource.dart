import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/api_auto_insurance_policy.dart';
import '../models/api_auto_insurance_policy_for_create.dart';
import '../models/api_auto_insurance_policy_for_update.dart';
import '_response_unwrap.dart';

class InsuranceRemoteDataSource {
  InsuranceRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ApiAutoInsurancePolicy>> getPolicies(int autoId) async {
    try {
      final response = await _apiClient.dio
          .get('/automobiles/$autoId/insurance-policies');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => ApiAutoInsurancePolicy.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<ApiAutoInsurancePolicy?> getActivePolicy(int autoId) async {
    try {
      final response = await _apiClient.dio
          .get('/automobiles/$autoId/insurance-policies/active');
      return ApiAutoInsurancePolicy.fromJson(unwrapApiEnvelope(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ApiAutoInsurancePolicy> getPolicyById(int autoId, int id) async {
    final response =
        await _apiClient.dio.get('/automobiles/$autoId/insurance-policies/$id');
    return ApiAutoInsurancePolicy.fromJson(unwrapApiEnvelope(response.data));
  }

  Future<ApiAutoInsurancePolicy> createPolicy(
      int autoId, ApiAutoInsurancePolicyForCreate dto) async {
    final response = await _apiClient.dio.post(
      '/automobiles/$autoId/insurance-policies',
      data: dto.toJson(),
    );
    return ApiAutoInsurancePolicy.fromJson(unwrapApiEnvelope(response.data));
  }

  Future<void> updatePolicy(
      int autoId, int id, ApiAutoInsurancePolicyForUpdate dto) async {
    await _apiClient.dio.put(
      '/automobiles/$autoId/insurance-policies/$id',
      data: dto.toJson(),
    );
  }

  Future<void> deletePolicy(int autoId, int id) async {
    await _apiClient.dio.delete('/automobiles/$autoId/insurance-policies/$id');
  }
}

final insuranceRemoteDataSourceProvider =
    Provider<InsuranceRemoteDataSource>(
  (ref) => InsuranceRemoteDataSource(ref.watch(apiClientProvider)),
);
