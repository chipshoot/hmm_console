import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/entities/discount_info.dart';

void main() {
  group('DiscountInfo', () {
    test('stores discountId and amount', () {
      const info = DiscountInfo(discountId: 3, amount: 5.25);
      expect(info.discountId, 3);
      expect(info.amount, 5.25);
    });
  });
}
