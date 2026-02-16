class ApiAutomobileForCreate {
  final String vin;
  final String maker;
  final String brand;
  final String model;
  final String? trim;
  final int year;
  final String? color;
  final String plate;
  final String engineType;
  final String fuelType;
  final double fuelTankCapacity;
  final double cityMPG;
  final double highwayMPG;
  final double combinedMPG;
  final int meterReading;
  final int? purchaseMeterReading;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String ownershipStatus;
  final DateTime? registrationExpiryDate;
  final DateTime? insuranceExpiryDate;
  final String? insuranceProvider;
  final String? insurancePolicyNumber;
  final String? notes;

  const ApiAutomobileForCreate({
    required this.vin,
    required this.maker,
    required this.brand,
    required this.model,
    this.trim,
    this.year = 0,
    this.color,
    required this.plate,
    required this.engineType,
    required this.fuelType,
    this.fuelTankCapacity = 0,
    this.cityMPG = 0,
    this.highwayMPG = 0,
    this.combinedMPG = 0,
    this.meterReading = 0,
    this.purchaseMeterReading,
    this.purchaseDate,
    this.purchasePrice,
    this.ownershipStatus = 'Owned',
    this.registrationExpiryDate,
    this.insuranceExpiryDate,
    this.insuranceProvider,
    this.insurancePolicyNumber,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'vin': vin,
      'maker': maker,
      'brand': brand,
      'model': model,
      if (trim != null) 'trim': trim,
      'year': year,
      if (color != null) 'color': color,
      'plate': plate,
      'engineType': engineType,
      'fuelType': fuelType,
      'fuelTankCapacity': fuelTankCapacity,
      'cityMPG': cityMPG,
      'highwayMPG': highwayMPG,
      'combinedMPG': combinedMPG,
      'meterReading': meterReading,
      if (purchaseMeterReading != null)
        'purchaseMeterReading': purchaseMeterReading,
      if (purchaseDate != null)
        'purchaseDate': purchaseDate!.toIso8601String(),
      if (purchasePrice != null) 'purchasePrice': purchasePrice,
      'ownershipStatus': ownershipStatus,
      if (registrationExpiryDate != null)
        'registrationExpiryDate': registrationExpiryDate!.toIso8601String(),
      if (insuranceExpiryDate != null)
        'insuranceExpiryDate': insuranceExpiryDate!.toIso8601String(),
      if (insuranceProvider != null) 'insuranceProvider': insuranceProvider,
      if (insurancePolicyNumber != null)
        'insurancePolicyNumber': insurancePolicyNumber,
      if (notes != null) 'notes': notes,
    };
  }
}
