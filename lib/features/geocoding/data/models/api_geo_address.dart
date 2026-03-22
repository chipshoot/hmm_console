class ApiGeoAddress {
  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final String? zipCode;
  final String? formattedAddress;
  final double latitude;
  final double longitude;

  const ApiGeoAddress({
    this.street,
    this.city,
    this.state,
    this.country,
    this.zipCode,
    this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory ApiGeoAddress.fromJson(Map<String, dynamic> json) {
    return ApiGeoAddress(
      street: json['Street'] as String? ?? json['street'] as String?,
      city: json['City'] as String? ?? json['city'] as String?,
      state: json['State'] as String? ?? json['state'] as String?,
      country: json['Country'] as String? ?? json['country'] as String?,
      zipCode: json['ZipCode'] as String? ?? json['zipCode'] as String?,
      formattedAddress: json['FormattedAddress'] as String? ??
          json['formattedAddress'] as String?,
      latitude: (json['Latitude'] as num?)?.toDouble() ??
          (json['latitude'] as num).toDouble(),
      longitude: (json['Longitude'] as num?)?.toDouble() ??
          (json['longitude'] as num).toDouble(),
    );
  }
}
