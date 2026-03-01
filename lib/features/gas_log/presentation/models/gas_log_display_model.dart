import '../../domain/entities/gas_log.dart';

class GasLogDisplayModel {
  final GasLog original;
  final double odometer;
  final double distance;
  final double fuel;
  final double totalPrice;
  final double unitPrice;
  final double fuelEfficiency;
  final String distanceLabel;
  final String fuelLabel;
  final String currencySymbol;
  final DateTime date;
  final String? stationName;

  const GasLogDisplayModel({
    required this.original,
    required this.odometer,
    required this.distance,
    required this.fuel,
    required this.totalPrice,
    required this.unitPrice,
    required this.fuelEfficiency,
    required this.distanceLabel,
    required this.fuelLabel,
    required this.currencySymbol,
    required this.date,
    this.stationName,
  });
}
