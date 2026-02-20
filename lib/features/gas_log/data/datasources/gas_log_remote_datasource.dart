import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/pagination.dart';
import '../models/api_gas_log.dart';
import '../models/api_gas_log_for_creation.dart';
import '../models/api_gas_log_for_update.dart';

class GasLogRemoteDataSource {
  GasLogRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResponse<ApiGasLog>> getGasLogs(
    int autoId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/automobiles/$autoId/gaslogs',
        queryParameters: {'pageNumber': page, 'pageSize': pageSize},
      );

      final jsonList = response.data as List<dynamic>;
      final items = jsonList
          .map((e) => ApiGasLog.fromJson(e as Map<String, dynamic>))
          .toList();

      final paginationHeader = response.headers.value('x-pagination');
      final meta = paginationHeader != null
          ? PaginationMeta.fromHeader(paginationHeader)
          : PaginationMeta(
              totalCount: items.length,
              pageSize: pageSize,
              currentPage: page,
              totalPages: 1,
            );

      return PaginatedResponse(items: items, meta: meta);
    } on DioException catch (e) {
      // Backend returns 404 when no gas logs exist — treat as empty list
      if (e.response?.statusCode == 404) {
        return PaginatedResponse(
          items: [],
          meta: PaginationMeta(
            totalCount: 0,
            pageSize: pageSize,
            currentPage: page,
            totalPages: 0,
          ),
        );
      }
      rethrow;
    }
  }

  Future<ApiGasLog> getGasLogById(int autoId, int id) async {
    final response =
        await _apiClient.dio.get('/automobiles/$autoId/gaslogs/$id');
    return ApiGasLog.fromJson(_unwrapResponse(response.data));
  }

  Future<ApiGasLog> createGasLog(
    int autoId,
    ApiGasLogForCreation dto,
  ) async {
    final response = await _apiClient.dio.post(
      '/automobiles/$autoId/gaslogs',
      data: dto.toJson(),
    );
    return ApiGasLog.fromJson(_unwrapResponse(response.data));
  }

  Future<ApiGasLog> updateGasLog(
    int autoId,
    int id,
    ApiGasLogForUpdate dto,
  ) async {
    final response = await _apiClient.dio.put(
      '/automobiles/$autoId/gaslogs/$id',
      data: dto.toJson(),
    );
    return ApiGasLog.fromJson(_unwrapResponse(response.data));
  }

  Future<void> deleteGasLog(int autoId, int id) async {
    await _apiClient.dio.delete('/automobiles/$autoId/gaslogs/$id');
  }

  /// Unwraps the backend's result filter response format.
  /// Single-item endpoints return { "value": { ...fields... }, "links": [...] }
  /// where the value object uses PascalCase keys (from ExpandoObject).
  /// This extracts the value and normalizes keys to camelCase.
  Map<String, dynamic> _unwrapResponse(dynamic data) {
    final map = data as Map<String, dynamic>;
    // Extract from { "value": {...}, "links": [...] } wrapper if present
    final value = map['value'] as Map<String, dynamic>? ?? map;
    // Normalize PascalCase keys to camelCase
    return value.map((key, v) {
      final camelKey = key.isNotEmpty
          ? key[0].toLowerCase() + key.substring(1)
          : key;
      return MapEntry(camelKey, v);
    });
  }
}

final gasLogRemoteDataSourceProvider = Provider<GasLogRemoteDataSource>(
  (ref) => GasLogRemoteDataSource(ref.watch(apiClientProvider)),
);
