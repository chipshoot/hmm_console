import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/api_geo_address.dart';

class GeocodingRemoteDataSource {
  GeocodingRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<ApiGeoAddress> reverseGeocode(
      double latitude, double longitude) async {
    final response = await _apiClient.dio.get(
      '/geocoding/reverse',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return ApiGeoAddress.fromJson(response.data as Map<String, dynamic>);
  }
}

final geocodingRemoteDataSourceProvider =
    Provider<GeocodingRemoteDataSource>(
  (ref) => GeocodingRemoteDataSource(ref.watch(apiClientProvider)),
);
