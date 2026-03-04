import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/api_gas_station.dart';

class GasStationRemoteDataSource {
  GasStationRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ApiGasStation>> getGasStations() async {
    try {
      final response =
          await _apiClient.dio.get('/automobiles/gasstations');
      final jsonList = response.data as List<dynamic>;
      return jsonList
          .map((e) => ApiGasStation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      rethrow;
    }
  }

  Future<ApiGasStation> createGasStation(ApiGasStation station) async {
    final response = await _apiClient.dio.post(
      '/automobiles/gasstations',
      data: station.toJson(),
    );
    return ApiGasStation.fromJson(_unwrapResponse(response.data));
  }

  Future<ApiGasStation> updateGasStation(int id, ApiGasStation station) async {
    await _apiClient.dio.put(
      '/automobiles/gasstations/$id',
      data: station.toJson(),
    );
    // Backend returns 204 No Content — return the input with the known id
    return ApiGasStation(
      id: id,
      name: station.name,
      address: station.address,
      city: station.city,
      state: station.state,
      country: station.country,
      zipCode: station.zipCode,
      description: station.description,
      latitude: station.latitude,
      longitude: station.longitude,
      isActive: station.isActive,
    );
  }

  /// Unwraps the backend's result filter response format.
  /// Single-item endpoints return { "value": { ...fields... }, "links": [...] }
  /// where the value object uses PascalCase keys (from ExpandoObject).
  /// This extracts the value and normalizes keys to camelCase.
  Map<String, dynamic> _unwrapResponse(dynamic data) {
    final map = data as Map<String, dynamic>;
    final value = map['value'] as Map<String, dynamic>? ?? map;
    return value.map((key, v) {
      final camelKey =
          key.isNotEmpty ? key[0].toLowerCase() + key.substring(1) : key;
      return MapEntry(camelKey, v);
    });
  }

  Future<void> deleteGasStation(int id) async {
    await _apiClient.dio.delete('/automobiles/gasstations/$id');
  }
}

final gasStationRemoteDataSourceProvider =
    Provider<GasStationRemoteDataSource>(
  (ref) => GasStationRemoteDataSource(ref.watch(apiClientProvider)),
);
