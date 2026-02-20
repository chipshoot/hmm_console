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
    return ApiGasStation.fromJson(response.data as Map<String, dynamic>);
  }
}

final gasStationRemoteDataSourceProvider =
    Provider<GasStationRemoteDataSource>(
  (ref) => GasStationRemoteDataSource(ref.watch(apiClientProvider)),
);
