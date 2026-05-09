import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/api_auto_scheduled_service.dart';
import '../models/api_auto_scheduled_service_for_create.dart';
import '../models/api_auto_scheduled_service_for_update.dart';
import '_response_unwrap.dart';

class ScheduledServiceRemoteDataSource {
  ScheduledServiceRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ApiAutoScheduledService>> getSchedules(int autoId) async {
    try {
      final response =
          await _apiClient.dio.get('/automobiles/$autoId/scheduled-services');
      final list = response.data as List<dynamic>;
      return list
          .map((e) =>
              ApiAutoScheduledService.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<ApiAutoScheduledService?> getSoonest(int autoId) async {
    try {
      final response = await _apiClient.dio
          .get('/automobiles/$autoId/scheduled-services/soonest');
      return ApiAutoScheduledService.fromJson(unwrapApiEnvelope(response.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ApiAutoScheduledService> getScheduleById(int autoId, int id) async {
    final response = await _apiClient.dio
        .get('/automobiles/$autoId/scheduled-services/$id');
    return ApiAutoScheduledService.fromJson(unwrapApiEnvelope(response.data));
  }

  Future<ApiAutoScheduledService> createSchedule(
      int autoId, ApiAutoScheduledServiceForCreate dto) async {
    final response = await _apiClient.dio.post(
      '/automobiles/$autoId/scheduled-services',
      data: dto.toJson(),
    );
    return ApiAutoScheduledService.fromJson(unwrapApiEnvelope(response.data));
  }

  Future<void> updateSchedule(
      int autoId, int id, ApiAutoScheduledServiceForUpdate dto) async {
    await _apiClient.dio.put(
      '/automobiles/$autoId/scheduled-services/$id',
      data: dto.toJson(),
    );
  }

  Future<void> deleteSchedule(int autoId, int id) async {
    await _apiClient.dio
        .delete('/automobiles/$autoId/scheduled-services/$id');
  }
}

final scheduledServiceRemoteDataSourceProvider =
    Provider<ScheduledServiceRemoteDataSource>(
  (ref) => ScheduledServiceRemoteDataSource(ref.watch(apiClientProvider)),
);
