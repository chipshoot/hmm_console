import 'api_coverage_item.dart';

class ApiAutoInsurancePolicy {
  const ApiAutoInsurancePolicy({
    required this.id,
    required this.automobileId,
    required this.provider,
    required this.policyNumber,
    required this.effectiveDate,
    required this.expiryDate,
    this.premium = 0,
    this.currency,
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
  final String? currency;
  final double? deductible;
  final List<ApiCoverageItem> coverage;
  final String? notes;
  final bool isActive;
  final DateTime? createdDate;
  final DateTime? lastModifiedDate;

  factory ApiAutoInsurancePolicy.fromJson(Map<String, dynamic> json) {
    return ApiAutoInsurancePolicy(
      id: json['id'] as int,
      automobileId: json['automobileId'] as int? ?? 0,
      provider: json['provider'] as String? ?? '',
      policyNumber: json['policyNumber'] as String? ?? '',
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      premium: (json['premium'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String?,
      deductible: (json['deductible'] as num?)?.toDouble(),
      coverage: (json['coverage'] as List<dynamic>?)
              ?.map((e) => ApiCoverageItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      notes: json['notes'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'] as String)
          : null,
      lastModifiedDate: json['lastModifiedDate'] != null
          ? DateTime.parse(json['lastModifiedDate'] as String)
          : null,
    );
  }
}
