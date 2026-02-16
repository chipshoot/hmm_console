import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/api_automobile.dart';
import '../models/api_automobile_for_create.dart';
import '../models/api_automobile_for_update.dart';

class AutomobileRemoteDataSource {
  AutomobileRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ApiAutomobile>> getAutomobiles() async {
    try {
      final response = await _apiClient.dio.get('/automobiles');
      final jsonList = response.data as List<dynamic>;
      return jsonList
          .map((e) => ApiAutomobile.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // Backend returns 404 when no automobiles exist — treat as empty list
      if (e.response?.statusCode == 404) {
        return [];
      }
      rethrow;
    }
  }

  Future<ApiAutomobile> getAutomobileById(int id) async {
    final response = await _apiClient.dio.get('/automobiles/$id');
    return ApiAutomobile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ApiAutomobile> createAutomobile(ApiAutomobileForCreate dto) async {
    final response = await _apiClient.dio.post(
      '/automobiles',
      data: dto.toJson(),
    );
    return ApiAutomobile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateAutomobile(int id, ApiAutomobileForUpdate dto) async {
    await _apiClient.dio.put(
      '/automobiles/$id',
      data: dto.toJson(),
    );
  }
}

final automobileRemoteDataSourceProvider =
    Provider<AutomobileRemoteDataSource>(
  (ref) => AutomobileRemoteDataSource(ref.watch(apiClientProvider)),
);
