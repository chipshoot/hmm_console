import '../../../../core/data/attachments/attachment_ref.dart';
import '../../../../core/data/attachments/attachment_ref_codec.dart';

class ApiAutomobileForUpdate {
  final String? color;
  final String? plate;
  final int meterReading;
  final String? ownershipStatus;
  final bool isActive;
  final DateTime? soldDate;
  final int? soldMeterReading;
  final double? soldPrice;
  final DateTime? registrationExpiryDate;
  final DateTime? insuranceExpiryDate;
  final String? insuranceProvider;
  final String? insurancePolicyNumber;
  final DateTime? lastServiceDate;
  final int? lastServiceMeterReading;
  final DateTime? nextServiceDueDate;
  final int? nextServiceDueMeterReading;
  final String? notes;

  // Attachments — null primaryImage means "clear the photo"; an
  // empty images list clears the gallery. Server only persists
  // vault-kind refs.
  final AttachmentRef? primaryImage;
  final List<AttachmentRef> images;

  const ApiAutomobileForUpdate({
    this.color,
    this.plate,
    this.meterReading = 0,
    this.ownershipStatus,
    this.isActive = true,
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
    this.primaryImage,
    this.images = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'color': color,
      'plate': plate,
      'meterReading': meterReading,
      'ownershipStatus': ownershipStatus,
      'isActive': isActive,
      if (soldDate != null) 'soldDate': soldDate!.toIso8601String(),
      'soldMeterReading': soldMeterReading,
      'soldPrice': soldPrice,
      if (registrationExpiryDate != null)
        'registrationExpiryDate': registrationExpiryDate!.toIso8601String(),
      if (insuranceExpiryDate != null)
        'insuranceExpiryDate': insuranceExpiryDate!.toIso8601String(),
      'insuranceProvider': insuranceProvider,
      'insurancePolicyNumber': insurancePolicyNumber,
      if (lastServiceDate != null)
        'lastServiceDate': lastServiceDate!.toIso8601String(),
      'lastServiceMeterReading': lastServiceMeterReading,
      if (nextServiceDueDate != null)
        'nextServiceDueDate': nextServiceDueDate!.toIso8601String(),
      'nextServiceDueMeterReading': nextServiceDueMeterReading,
      'notes': notes,
      // Attachments — always emit both keys (even when null /
      // empty) so the server treats an absent ref as an explicit
      // clear, not a partial update.
      'primaryImage':
          primaryImage == null ? null : AttachmentRefCodec.toJson(primaryImage!),
      'images':
          images.map(AttachmentRefCodec.toJson).toList(growable: false),
    };
  }
}
