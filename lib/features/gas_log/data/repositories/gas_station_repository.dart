import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gas_station.dart';
import '../datasources/gas_station_remote_datasource.dart';
import '../models/api_gas_station.dart';

abstract interface class IGasStationRepository {
  Future<List<GasStation>> getGasStations();
  Future<GasStation> createGasStation(GasStation station);
}

class _GasStationApiRepository implements IGasStationRepository {
  _GasStationApiRepository(this._remoteDataSource);

  final GasStationRemoteDataSource _remoteDataSource;

  @override
  Future<List<GasStation>> getGasStations() async {
    final apiList = await _remoteDataSource.getGasStations();
    return apiList.map(_fromApi).toList();
  }

  @override
  Future<GasStation> createGasStation(GasStation station) async {
    final api = await _remoteDataSource.createGasStation(
      ApiGasStation(
        id: 0,
        name: station.name,
        address: station.address,
        city: station.city,
        state: station.state,
        country: station.country,
        zipCode: station.zipCode,
        description: station.description,
      ),
    );
    return _fromApi(api);
  }

  static GasStation _fromApi(ApiGasStation api) {
    return GasStation(
      id: api.id,
      name: api.name,
      address: api.address,
      city: api.city,
      state: api.state,
      country: api.country,
      zipCode: api.zipCode,
      description: api.description,
      isActive: api.isActive,
    );
  }
}

final gasStationRepositoryProvider = Provider<IGasStationRepository>(
  (ref) => _GasStationApiRepository(
      ref.watch(gasStationRemoteDataSourceProvider)),
);
