import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gas_station.dart';
import '../datasources/gas_station_remote_datasource.dart';
import '../models/api_gas_station.dart';

abstract interface class IGasStationRepository {
  Future<List<GasStation>> getGasStations();
  Future<GasStation> createGasStation(GasStation station);
  Future<GasStation> updateGasStation(int id, GasStation station);
  Future<void> deleteGasStation(int id);
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
    final api = await _remoteDataSource.createGasStation(_toApi(station));
    return _fromApi(api);
  }

  @override
  Future<GasStation> updateGasStation(int id, GasStation station) async {
    final api = await _remoteDataSource.updateGasStation(id, _toApi(station));
    return _fromApi(api);
  }

  @override
  Future<void> deleteGasStation(int id) async {
    await _remoteDataSource.deleteGasStation(id);
  }

  static ApiGasStation _toApi(GasStation station) {
    return ApiGasStation(
      id: station.id ?? 0,
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
      latitude: api.latitude,
      longitude: api.longitude,
      isActive: api.isActive,
    );
  }
}

final gasStationRepositoryProvider = Provider<IGasStationRepository>(
  (ref) => _GasStationApiRepository(
      ref.watch(gasStationRemoteDataSourceProvider)),
);
