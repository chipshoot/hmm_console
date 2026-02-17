import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/data/models/api_discount_info.dart';

void main() {
  group('ApiDiscountInfo', () {
    test('fromJson creates correct instance', () {
      final info =
          ApiDiscountInfo.fromJson({'discountId': 5, 'amount': 2.50});
      expect(info.discountId, 5);
      expect(info.amount, 2.50);
    });

    test('toJson produces correct map', () {
      const info = ApiDiscountInfo(discountId: 3, amount: 1.25);
      final json = info.toJson();
      expect(json, {'discountId': 3, 'amount': 1.25});
    });

    test('fromJson handles integer amount', () {
      final info = ApiDiscountInfo.fromJson({'discountId': 1, 'amount': 4});
      expect(info.amount, 4.0);
    });
  });
}
