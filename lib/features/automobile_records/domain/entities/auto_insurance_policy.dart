import 'coverage_item.dart';

/// Auto insurance policy attached to a vehicle. Mirrors the backend
/// `AutoInsurancePolicy` note entity served from
/// `/v1/automobiles/{autoId}/insurance-policies`.
class AutoInsurancePolicy {
  const AutoInsurancePolicy({
    required this.id,
    required this.automobileId,
    required this.provider,
    required this.policyNumber,
    required this.effectiveDate,
    required this.expiryDate,
    required this.premium,
    this.currency = 'CAD',
    this.deductible,
    this.coverage = const [],
    this.notes,
    this.isActive = true,
    this.createdDate,
    this.lastModifiedDate,
  });

  final int id;
  final int automobileId;
  final String provider;
  final String policyNumber;
  final DateTime effectiveDate;
  final DateTime expiryDate;
  final double premium;
  final String currency;
  final double? deductible;
  final List<CoverageItem> coverage;
  final String? notes;
  final bool isActive;
  final DateTime? createdDate;
  final DateTime? lastModifiedDate;

  bool get isCurrentlyActive {
    final now = DateTime.now().toUtc();
    return isActive &&
        effectiveDate.isBefore(now.add(const Duration(milliseconds: 1))) &&
        expiryDate.isAfter(now);
  }
}
