class GasStation {
  final int? id;
  final String name;
  final String? address;
  final String? city;
  final bool isActive;

  const GasStation({
    this.id,
    required this.name,
    this.address,
    this.city,
    this.isActive = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GasStation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => name;
}
