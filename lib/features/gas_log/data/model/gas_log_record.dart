import 'package:hive_ce/hive.dart';

part 'gas_log_record.g.dart';

@HiveType(typeId: 0)
class GasLogRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String odometer;

  @HiveField(2)
  final double distance;

  @HiveField(3)
  final double gas;

  @HiveField(4)
  final double price;

  @HiveField(5)
  final DateTime date;

  @HiveField(6)
  final String? gasStation;

  @HiveField(7)
  final String? comment;

  GasLogRecord({
    required this.id,
    required this.odometer,
    required this.distance,
    required this.gas,
    required this.price,
    required this.date,
    this.gasStation = '',
    this.comment = '',
  });

  GasLogRecord copyWith({
    String? id,
    String? odometer,
    double? distance,
    double? gas,
    double? price,
    DateTime? date,
    String? gasStation,
    String? comment,
  }) {
    return GasLogRecord(
      id: id ?? this.id,
      odometer: odometer ?? this.odometer,
      distance: distance ?? this.distance,
      gas: gas ?? this.gas,
      price: price ?? this.price,
      date: date ?? this.date,
      gasStation: gasStation ?? this.gasStation,
      comment: comment ?? this.comment,
    );
  }
}
