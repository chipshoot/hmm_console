import 'api_coverage_item.dart';

class ApiAutoInsurancePolicyForCreate {
  const ApiAutoInsurancePolicyForCreate({
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
  });

  final String provider;
  final String policyNumber;
  final DateTime effectiveDate;
  final DateTime expiryDate;
  final double premium;
  final String currency;
  final double? deductible;
  final List<ApiCoverageItem> coverage;
  final String? notes;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'policyNumber': policyNumber,
        'effectiveDate': effectiveDate.toUtc().toIso8601String(),
        'expiryDate': expiryDate.toUtc().toIso8601String(),
        'premium': premium,
        'currency': currency,
        if (deductible != null) 'deductible': deductible,
        'coverage': coverage.map((c) => c.toJson()).toList(),
        if (notes != null) 'notes': notes,
        'isActive': isActive,
      };
}
