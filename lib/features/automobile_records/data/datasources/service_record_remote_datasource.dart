import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/api_service_record.dart';
import '../models/api_service_record_for_create.dart';
import '../models/api_service_record_for_update.dart';
import '_response_unwrap.dart';

class ServiceRecordRemoteDataSource {
  ServiceRecordRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ApiServiceRecord>> getRecords(int autoId) async {
    try {
      final response =
          await _apiClient.dio.get('/automobiles/$autoId/services');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => ApiServiceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<ApiServiceRecord> getRecordById(int autoId, int id) async {
    final response =
        await _apiClient.dio.get('/automobiles/$autoId/services/$id');
    return ApiServiceRecord.fromJson(unwrapApiEnvelope(response.data));
  }

  Future<ApiServiceRecord> createRecord(
      int autoId, ApiServiceRecordForCreate dto) async {
    final response = await _apiClient.dio.post(
      '/automobiles/$autoId/services',
      data: dto.toJson(),
    );
    return ApiServiceRecord.fromJson(unwrapApiEnvelope(response.data));
  }

  Future<void> updateRecord(
      int autoId, int id, ApiServiceRecordForUpdate dto) async {
    await _apiClient.dio.put(
      '/automobiles/$autoId/services/$id',
      data: dto.toJson(),
    );
  }

  Future<void> deleteRecord(int autoId, int id) async {
    await _apiClient.dio.delete('/automobiles/$autoId/services/$id');
  }
}

final serviceRecordRemoteDataSourceProvider =
    Provider<ServiceRecordRemoteDataSource>(
  (ref) => ServiceRecordRemoteDataSource(ref.watch(apiClientProvider)),
);
