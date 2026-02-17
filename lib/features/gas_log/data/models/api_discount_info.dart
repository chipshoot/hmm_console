class ApiDiscountInfo {
  final int discountId;
  final double amount;

  const ApiDiscountInfo({required this.discountId, required this.amount});

  factory ApiDiscountInfo.fromJson(Map<String, dynamic> json) {
    return ApiDiscountInfo(
      discountId: json['discountId'] as int,
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'discountId': discountId,
        'amount': amount,
      };
}
