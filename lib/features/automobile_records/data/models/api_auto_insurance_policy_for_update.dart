import 'api_coverage_item.dart';

class ApiAutoInsurancePolicyForUpdate {
  const ApiAutoInsurancePolicyForUpdate({
    this.provider,
    this.policyNumber,
    this.effectiveDate,
    this.expiryDate,
    this.premium,
    this.currency,
    this.deductible,
    this.coverage,
    this.notes,
    this.isActive,
  });

  final String? provider;
  final String? policyNumber;
  final DateTime? effectiveDate;
  final DateTime? expiryDate;
  final double? premium;
  final String? currency;
  final double? deductible;
  final List<ApiCoverageItem>? coverage;
  final String? notes;
  final bool? isActive;

  Map<String, dynamic> toJson() => {
        if (provider != null) 'provider': provider,
        if (policyNumber != null) 'policyNumber': policyNumber,
        if (effectiveDate != null)
          'effectiveDate': effectiveDate!.toUtc().toIso8601String(),
        if (expiryDate != null)
          'expiryDate': expiryDate!.toUtc().toIso8601String(),
        if (premium != null) 'premium': premium,
        if (currency != null) 'currency': currency,
        if (deductible != null) 'deductible': deductible,
        if (coverage != null)
          'coverage': coverage!.map((c) => c.toJson()).toList(),
        if (notes != null) 'notes': notes,
        if (isActive != null) 'isActive': isActive,
      };
}
