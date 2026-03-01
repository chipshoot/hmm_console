import '../../../settings/domain/gas_log_units.dart';

class UnitConverter {
  UnitConverter._();

  static const double milesToKm = 1.609344;
  static const double gallonsToLiters = 3.785411784;

  static double convertDistance(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    final from = DistanceUnit.fromApiValue(fromUnit);
    final to = DistanceUnit.fromApiValue(toUnit);
    if (from == to) return value;

    return from == DistanceUnit.mile ? value * milesToKm : value / milesToKm;
  }

  static double convertVolume(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;

    final from = FuelUnit.fromApiValue(fromUnit);
    final to = FuelUnit.fromApiValue(toUnit);
    if (from == to) return value;

    return from == FuelUnit.gallon ? value * gallonsToLiters : value / gallonsToLiters;
  }

  static double convertFuelEfficiency(
    double value,
    String fromDistUnit,
    String toDistUnit,
    String fromFuelUnit,
    String toFuelUnit,
  ) {
    if (fromDistUnit == toDistUnit && fromFuelUnit == toFuelUnit) return value;

    // fuel efficiency = distance / volume
    final distFactor = _distanceFactor(fromDistUnit, toDistUnit);
    final volFactor = _volumeFactor(fromFuelUnit, toFuelUnit);

    return value * distFactor / volFactor;
  }

  static double convertCurrency(double value, double exchangeRate) {
    return value * exchangeRate;
  }

  static double _distanceFactor(String from, String to) {
    final f = DistanceUnit.fromApiValue(from);
    final t = DistanceUnit.fromApiValue(to);
    if (f == t) return 1.0;
    return f == DistanceUnit.mile ? milesToKm : 1.0 / milesToKm;
  }

  static double _volumeFactor(String from, String to) {
    final f = FuelUnit.fromApiValue(from);
    final t = FuelUnit.fromApiValue(to);
    if (f == t) return 1.0;
    return f == FuelUnit.gallon ? gallonsToLiters : 1.0 / gallonsToLiters;
  }
}
