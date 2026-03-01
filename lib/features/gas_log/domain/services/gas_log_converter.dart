import '../../../settings/domain/gas_log_settings.dart';
import '../../presentation/models/gas_log_display_model.dart';
import '../entities/gas_log.dart';
import 'unit_converter.dart';

extension GasLogConversion on GasLog {
  GasLogDisplayModel toDisplayModel(
    GasLogSettings settings, {
    double exchangeRate = 1.0,
  }) {
    final targetDist = settings.distanceUnit.apiValue;
    final targetFuel = settings.fuelUnit.apiValue;

    return GasLogDisplayModel(
      original: this,
      odometer: UnitConverter.convertDistance(odometer, odometerUnit, targetDist),
      distance: UnitConverter.convertDistance(distance, distanceUnit, targetDist),
      fuel: UnitConverter.convertVolume(fuel, fuelUnit, targetFuel),
      totalPrice: UnitConverter.convertCurrency(totalPrice, exchangeRate),
      unitPrice: UnitConverter.convertCurrency(unitPrice, exchangeRate),
      fuelEfficiency: UnitConverter.convertFuelEfficiency(
        fuelEfficiency,
        distanceUnit,
        targetDist,
        fuelUnit,
        targetFuel,
      ),
      distanceLabel: settings.distanceUnit.label,
      fuelLabel: settings.fuelUnit.label,
      currencySymbol: settings.currency.symbol,
      date: date,
      stationName: stationName,
    );
  }
}
