import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/presentation/hmm_sign_in_sheet.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/gas_log/data/datasources/exchange_rate_remote_datasource.dart';
import 'package:hmm_console/features/gas_log/providers/exchange_rate_provider.dart';

class _FakeIdp implements IdpTokenService {
  int checks = 0;
  bool session = false;
  @override
  Future<bool> hasHmmSession() async {
    checks++;
    return session;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeRates implements ExchangeRateRemoteDataSource {
  @override
  Future<double> getExchangeRate(String from, String to) async => 1.25;
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

  test('a cached HmmSignInRequired clears on Hmm login and returns on '
      'sign-out', () async {
    final idp = _FakeIdp();
    final c = ProviderContainer(
      overrides: [
        idpTokenServiceProvider.overrideWithValue(idp),
        exchangeRateRemoteDataSourceProvider.overrideWithValue(_FakeRates()),
      ],
    );
    addTearDown(c.dispose);
    const pair = (from: 'USD', to: 'CAD');
    final sub = c.listen(exchangeRateProvider(pair), (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      c.read(exchangeRateProvider(pair).future),
      throwsA(isA<HmmSignInRequired>()),
    );

    // Signed in elsewhere (any screen's login sets the current user).
    idp.session = true;
    c
        .read(currentUserProvider.notifier)
        .setUser(const CurrentUserDataModel(uid: 'u1', email: 'a@b.c'));
    expect(await c.read(exchangeRateProvider(pair).future), 1.25);

    // Signed out.
    idp.session = false;
    c.read(currentUserProvider.notifier).setUser(null);
    await expectLater(
      c.read(exchangeRateProvider(pair).future),
      throwsA(isA<HmmSignInRequired>()),
    );
  });
}
