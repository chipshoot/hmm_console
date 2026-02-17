class ApiAutomobile {
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

  const ApiAutomobile({
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

  factory ApiAutomobile.fromJson(Map<String, dynamic> json) {
    return ApiAutomobile(
      id: json['id'] as int,
      vin: json['vin'] as String?,
      maker: json['maker'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      trim: json['trim'] as String?,
      year: json['year'] as int? ?? 0,
      color: json['color'] as String?,
      plate: json['plate'] as String?,
      engineType: json['engineType'] as String?,
      fuelType: json['fuelType'] as String?,
      fuelTankCapacity: (json['fuelTankCapacity'] as num?)?.toDouble() ?? 0,
      cityMPG: (json['cityMPG'] as num?)?.toDouble() ?? 0,
      highwayMPG: (json['highwayMPG'] as num?)?.toDouble() ?? 0,
      combinedMPG: (json['combinedMPG'] as num?)?.toDouble() ?? 0,
      meterReading: json['meterReading'] as int? ?? 0,
      purchaseMeterReading: json['purchaseMeterReading'] as int?,
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.parse(json['purchaseDate'] as String)
          : null,
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      ownershipStatus: json['ownershipStatus'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      soldDate: json['soldDate'] != null
          ? DateTime.parse(json['soldDate'] as String)
          : null,
      soldMeterReading: json['soldMeterReading'] as int?,
      soldPrice: (json['soldPrice'] as num?)?.toDouble(),
      registrationExpiryDate: json['registrationExpiryDate'] != null
          ? DateTime.parse(json['registrationExpiryDate'] as String)
          : null,
      insuranceExpiryDate: json['insuranceExpiryDate'] != null
          ? DateTime.parse(json['insuranceExpiryDate'] as String)
          : null,
      insuranceProvider: json['insuranceProvider'] as String?,
      insurancePolicyNumber: json['insurancePolicyNumber'] as String?,
      lastServiceDate: json['lastServiceDate'] != null
          ? DateTime.parse(json['lastServiceDate'] as String)
          : null,
      lastServiceMeterReading: json['lastServiceMeterReading'] as int?,
      nextServiceDueDate: json['nextServiceDueDate'] != null
          ? DateTime.parse(json['nextServiceDueDate'] as String)
          : null,
      nextServiceDueMeterReading: json['nextServiceDueMeterReading'] as int?,
      notes: json['notes'] as String?,
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'] as String)
          : null,
      lastModifiedDate: json['lastModifiedDate'] != null
          ? DateTime.parse(json['lastModifiedDate'] as String)
          : null,
    );
  }
}
