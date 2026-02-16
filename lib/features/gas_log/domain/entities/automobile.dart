class Automobile {
  final int id;

  // Core Identification
  final String? vin;
  final String? maker;
  final String? brand;
  final String? model;
  final String? trim;
  final int year;
  final String? color;
  final String? plate;

  // Fuel & Engine
  final String? engineType;
  final String? fuelType;
  final double fuelTankCapacity;
  final double cityMPG;
  final double highwayMPG;
  final double combinedMPG;

  // Meter/Odometer
  final int meterReading;
  final int? purchaseMeterReading;

  // Ownership
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? ownershipStatus;

  // Status
  final bool isActive;
  final DateTime? soldDate;
  final int? soldMeterReading;
  final double? soldPrice;

  // Registration & Insurance
  final DateTime? registrationExpiryDate;
  final DateTime? insuranceExpiryDate;
  final String? insuranceProvider;
  final String? insurancePolicyNumber;

  // Maintenance
  final DateTime? lastServiceDate;
  final int? lastServiceMeterReading;
  final DateTime? nextServiceDueDate;
  final int? nextServiceDueMeterReading;

  // Metadata
  final String? notes;
  final DateTime? createdDate;
  final DateTime? lastModifiedDate;

  const Automobile({
    required this.id,
    this.vin,
    this.maker,
    this.brand,
    this.model,
    this.trim,
    required this.year,
    this.color,
    this.plate,
    this.engineType,
    this.fuelType,
    this.fuelTankCapacity = 0,
    this.cityMPG = 0,
    this.highwayMPG = 0,
    this.combinedMPG = 0,
    required this.meterReading,
    this.purchaseMeterReading,
    this.purchaseDate,
    this.purchasePrice,
    this.ownershipStatus,
    required this.isActive,
    this.soldDate,
    this.soldMeterReading,
    this.soldPrice,
    this.registrationExpiryDate,
    this.insuranceExpiryDate,
    this.insuranceProvider,
    this.insurancePolicyNumber,
    this.lastServiceDate,
    this.lastServiceMeterReading,
    this.nextServiceDueDate,
    this.nextServiceDueMeterReading,
    this.notes,
    this.createdDate,
    this.lastModifiedDate,
  });

  String get displayName {
    final parts = <String>[
      if (year > 0) '$year',
      if (maker != null && maker!.isNotEmpty) maker!,
      if (brand != null && brand!.isNotEmpty) brand!,
      if (model != null && model!.isNotEmpty) model!,
    ];
    return parts.isNotEmpty ? parts.join(' ') : 'Vehicle #$id';
  }
}
