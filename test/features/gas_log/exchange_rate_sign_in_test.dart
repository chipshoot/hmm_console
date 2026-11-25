import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/presentation/hmm_sign_in_sheet.dart';
import 'package:hmm_console/features/gas_log/providers/exchange_rate_provider.dart';

class _FakeIdp implements IdpTokenService {
  int checks = 0;
  @override
  Future<bool> hasHmmSession() async {
    checks++;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test(
    'different currencies without a session throw HmmSignInRequired',
    () async {
      final c = ProviderContainer(
        overrides: [idpTokenServiceProvider.overrideWithValue(_FakeIdp())],
      );
      addTearDown(c.dispose);
      await expectLater(
        c.read(exchangeRateProvider((from: 'USD', to: 'CAD')).future),
        throwsA(isA<HmmSignInRequired>()),
      );
    },
  );

  test('same currency returns 1.0 without a session check', () async {
    final idp = _FakeIdp();
    final c = ProviderContainer(
      overrides: [idpTokenServiceProvider.overrideWithValue(idp)],
    );
    addTearDown(c.dispose);
    expect(
      await c.read(exchangeRateProvider((from: 'CAD', to: 'CAD')).future),
      1.0,
    );
    expect(idp.checks, 0);
  });
}
