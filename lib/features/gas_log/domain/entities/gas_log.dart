/// Domain model for Gas Log - used in UI and business logic
class GasLog {
  final String? id;
  final String odometer;
  final double distance;
  final double gas;
  final double price;
  final DateTime date;
  final String? gasStation;
  final String? comment;

  GasLog({
    this.id,
    required this.odometer,
    required this.distance,
    required this.gas,
    required this.price,
    required this.date,
    this.gasStation,
    this.comment,
  });

  GasLog copyWith({
    String? id,
    String? odometer,
    double? distance,
    double? gas,
    double? price,
    DateTime? date,
    String? gasStation,
    String? comment,
  }) {
    return GasLog(
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

  @override
  String toString() {
    return 'GasLog(id: $id, odometer: $odometer, distance: $distance, gas: $gas, price: $price, date: $date, gasStation: $gasStation, comment: $comment)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GasLog &&
        other.id == id &&
        other.odometer == odometer &&
        other.distance == distance &&
        other.gas == gas &&
        other.price == price &&
        other.date == date &&
        other.gasStation == gasStation &&
        other.comment == comment;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      odometer,
      distance,
      gas,
      price,
      date,
      gasStation,
      comment,
    );
  }
}
