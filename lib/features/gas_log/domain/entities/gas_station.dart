class GasStation {
  final int? id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? zipCode;
  final String? description;
  final bool isActive;

  const GasStation({
    this.id,
    required this.name,
    this.address,
    this.city,
    this.state,
    this.country,
    this.zipCode,
    this.description,
    this.isActive = true,
  });

  GasStation copyWith({
    int? id,
    String? name,
    String? address,
    String? city,
    String? state,
    String? country,
    String? zipCode,
    String? description,
    bool? isActive,
  }) {
    return GasStation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      zipCode: zipCode ?? this.zipCode,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

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
