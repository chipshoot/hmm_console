class ApiGasStation {
  final int id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? description;
  final bool isActive;

  const ApiGasStation({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.description,
    this.isActive = true,
  });

  factory ApiGasStation.fromJson(Map<String, dynamic> json) {
    return ApiGasStation(
      id: json['Id'] as int? ?? json['id'] as int,
      name: json['Name'] as String? ?? json['name'] as String,
      address: json['Address'] as String? ?? json['address'] as String?,
      city: json['City'] as String? ?? json['city'] as String?,
      state: json['State'] as String? ?? json['state'] as String?,
      zipCode: json['ZipCode'] as String? ?? json['zipCode'] as String?,
      description:
          json['Description'] as String? ?? json['description'] as String?,
      isActive: json['IsActive'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        'isActive': isActive,
      };
}
