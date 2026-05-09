class ApiCoverageItem {
  const ApiCoverageItem({
    required this.type,
    this.limit = 0,
    this.deductible = 0,
    this.currency,
  });

  final String type;
  final double limit;
  final double deductible;
  final String? currency;

  factory ApiCoverageItem.fromJson(Map<String, dynamic> json) {
    return ApiCoverageItem(
      type: json['type'] as String? ?? '',
      limit: (json['limit'] as num?)?.toDouble() ?? 0,
      deductible: (json['deductible'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'limit': limit,
        'deductible': deductible,
        if (currency != null) 'currency': currency,
      };
}
