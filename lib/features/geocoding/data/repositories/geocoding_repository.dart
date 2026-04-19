import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/geo_address.dart';
import '../datasources/geocoding_remote_datasource.dart';
import '../models/api_geo_address.dart';

abstract interface class IGeocodingRepository {
  Future<GeoAddress> reverseGeocode(double latitude, double longitude);
}

class _GeocodingApiRepository implements IGeocodingRepository {
  _GeocodingApiRepository(this._remoteDataSource);

  final GeocodingRemoteDataSource _remoteDataSource;

  @override
  Future<GeoAddress> reverseGeocode(double latitude, double longitude) async {
    final api = await _remoteDataSource.reverseGeocode(latitude, longitude);
    return _fromApi(api);
  }

  static GeoAddress _fromApi(ApiGeoAddress api) {
    return GeoAddress(
      street: api.street,
      city: api.city,
      state: api.state,
      country: api.country,
      zipCode: api.zipCode,
      formattedAddress: api.formattedAddress,
      latitude: api.latitude,
      longitude: api.longitude,
    );
  }
}

final geocodingRepositoryProvider = Provider<IGeocodingRepository>(
  (ref) => _GeocodingApiRepository(
      ref.watch(geocodingRemoteDataSourceProvider)),
);
