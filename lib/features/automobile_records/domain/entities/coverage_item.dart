/// Single coverage line on an auto insurance policy (e.g. Liability,
/// Collision, Comprehensive). Stored as nested JSON inside the policy's
/// HmmNote on the backend; on the client it's a plain value object.
class CoverageItem {
  const CoverageItem({
    required this.type,
    required this.limit,
    this.deductible = 0,
    this.currency = 'CAD',
  });

  final String type;
  final double limit;
  final double deductible;
  final String currency;

  CoverageItem copyWith({
    String? type,
    double? limit,
    double? deductible,
    String? currency,
  }) {
    return CoverageItem(
      type: type ?? this.type,
      limit: limit ?? this.limit,
      deductible: deductible ?? this.deductible,
      currency: currency ?? this.currency,
    );
  }
}
