import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gas_station.dart';
import '../datasources/gas_station_remote_datasource.dart';
import '../models/api_gas_station.dart';

abstract interface class IGasStationRepository {
  Future<List<GasStation>> getGasStations();
  Future<GasStation> createGasStation(String name);
}

class _GasStationApiRepository implements IGasStationRepository {
  _GasStationApiRepository(this._remoteDataSource);

  final GasStationRemoteDataSource _remoteDataSource;

  @override
  Future<List<GasStation>> getGasStations() async {
    final apiList = await _remoteDataSource.getGasStations();
    return apiList
        .map((api) => GasStation(
              id: api.id,
              name: api.name,
              address: api.address,
              city: api.city,
              isActive: api.isActive,
            ))
        .toList();
  }

  @override
  Future<GasStation> createGasStation(String name) async {
    final api = await _remoteDataSource.createGasStation(
      ApiGasStation(id: 0, name: name),
    );
    return GasStation(
      id: api.id,
      name: api.name,
      address: api.address,
      city: api.city,
      isActive: api.isActive,
    );
  }
}

final gasStationRepositoryProvider = Provider<IGasStationRepository>(
  (ref) => _GasStationApiRepository(
      ref.watch(gasStationRemoteDataSourceProvider)),
);
