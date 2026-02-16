import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/automobile.dart';
import '../datasources/automobile_remote_datasource.dart';
import '../mappers/gas_log_api_mapper.dart';

abstract interface class IAutomobileRepository {
  Future<List<Automobile>> getAutomobiles();
  Future<Automobile> getAutomobileById(int id);
  Future<Automobile> createAutomobile(Automobile automobile);
  Future<void> updateAutomobile(int id, Automobile automobile);
  Future<void> deactivateAutomobile(int id);
}

class _AutomobileApiRepository implements IAutomobileRepository {
  _AutomobileApiRepository(this._remoteDataSource);

  final AutomobileRemoteDataSource _remoteDataSource;

  @override
  Future<List<Automobile>> getAutomobiles() async {
    final apiList = await _remoteDataSource.getAutomobiles();
    return apiList.map(GasLogApiMapper.automobileFromApi).toList();
  }

  @override
  Future<Automobile> getAutomobileById(int id) async {
    final api = await _remoteDataSource.getAutomobileById(id);
    return GasLogApiMapper.automobileFromApi(api);
  }

  @override
  Future<Automobile> createAutomobile(Automobile automobile) async {
    final dto = GasLogApiMapper.automobileToCreateDto(automobile);
    final api = await _remoteDataSource.createAutomobile(dto);
    return GasLogApiMapper.automobileFromApi(api);
  }

  @override
  Future<void> updateAutomobile(int id, Automobile automobile) async {
    final dto = GasLogApiMapper.automobileToUpdateDto(automobile);
    await _remoteDataSource.updateAutomobile(id, dto);
  }

  @override
  Future<void> deactivateAutomobile(int id) async {
    final current = await getAutomobileById(id);
    final deactivated = Automobile(
      id: current.id,
      vin: current.vin,
      maker: current.maker,
      brand: current.brand,
      model: current.model,
      trim: current.trim,
      year: current.year,
      color: current.color,
      plate: current.plate,
      engineType: current.engineType,
      fuelType: current.fuelType,
      fuelTankCapacity: current.fuelTankCapacity,
      cityMPG: current.cityMPG,
      highwayMPG: current.highwayMPG,
      combinedMPG: current.combinedMPG,
      meterReading: current.meterReading,
      purchaseMeterReading: current.purchaseMeterReading,
      purchaseDate: current.purchaseDate,
      purchasePrice: current.purchasePrice,
      ownershipStatus: current.ownershipStatus,
      isActive: false,
      soldDate: current.soldDate,
      soldMeterReading: current.soldMeterReading,
      soldPrice: current.soldPrice,
      registrationExpiryDate: current.registrationExpiryDate,
      insuranceExpiryDate: current.insuranceExpiryDate,
      insuranceProvider: current.insuranceProvider,
      insurancePolicyNumber: current.insurancePolicyNumber,
      lastServiceDate: current.lastServiceDate,
      lastServiceMeterReading: current.lastServiceMeterReading,
      nextServiceDueDate: current.nextServiceDueDate,
      nextServiceDueMeterReading: current.nextServiceDueMeterReading,
      notes: current.notes,
    );
    final dto = GasLogApiMapper.automobileToUpdateDto(deactivated);
    await _remoteDataSource.updateAutomobile(id, dto);
  }
}

final automobileRepositoryProvider = Provider<IAutomobileRepository>(
  (ref) =>
      _AutomobileApiRepository(ref.watch(automobileRemoteDataSourceProvider)),
);
