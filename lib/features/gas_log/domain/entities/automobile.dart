import '../../../../core/data/attachments/attachment_ref.dart';

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

  /// Append-only history of changes to the normally-immutable identity
  /// fields (VIN / maker / brand / model / trim / year / engine / fuel).
  /// Populated only when the edit screen's hidden long-press unlock has
  /// been confirmed. Persisted alongside the rest of the vehicle's
  /// content blob.
  final List<AutomobileAuditEntry> auditLog;

  /// Headline photo of the vehicle. Read-through projection of the
  /// owning note's `attachments` column — `Automobile` doesn't store
  /// its own attachment bytes, the note does. `null` means no photo.
  ///
  /// Disjoint with [images]: a photo lives in this slot OR in
  /// [images], never both (enforced by NoteAttachments).
  final AttachmentRef? primaryImage;

  /// Additional photos / files attached to the vehicle's note.
  /// Read-through projection of the owning note's `attachments`
  /// column. Empty list means no extras.
  final List<AttachmentRef> images;

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
    this.auditLog = const [],
    this.primaryImage,
    this.images = const [],
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

/// One row of the [Automobile.auditLog]. Records a change to a
/// normally-immutable identity field — captured by the hidden
/// long-press-to-unlock flow on the edit screen.
class AutomobileAuditEntry {
  const AutomobileAuditEntry({
    required this.timestamp,
    required this.field,
    required this.oldValue,
    required this.newValue,
    this.actor,
  });

  final DateTime timestamp;

  /// Lower-case identifier of the field that changed (`vin`, `maker`,
  /// `brand`, `model`, `trim`, `year`, `engineType`, `fuelType`).
  final String field;

  final String? oldValue;
  final String? newValue;

  /// `accountName` of the signed-in user at the time of the change
  /// (= IdP JWT `sub`). Optional so legacy entries that pre-date the
  /// audit feature deserialize cleanly.
  final String? actor;
}
