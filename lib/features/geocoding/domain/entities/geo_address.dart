class GeoAddress {
  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final String? zipCode;
  final String? formattedAddress;
  final double latitude;
  final double longitude;

  const GeoAddress({
    this.street,
    this.city,
    this.state,
    this.country,
    this.zipCode,
    this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });
}
