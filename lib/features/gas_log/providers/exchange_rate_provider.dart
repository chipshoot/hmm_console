import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/idp_token_service.dart';
import '../../auth/presentation/hmm_sign_in_sheet.dart';
import '../data/datasources/exchange_rate_remote_datasource.dart';

typedef CurrencyPair = ({String from, String to});

final exchangeRateProvider = FutureProvider.family<double, CurrencyPair>(
  retry: (count, error) {
    // Signing in is the fix; retrying would keep the provider loading forever.
    if (error is HmmSignInRequired) return null;
    return ProviderContainer.defaultRetry(count, error);
  },
  (ref, pair) async {
    ref.keepAlive();

    if (pair.from == pair.to) return 1.0;

    if (!await ref.read(idpTokenServiceProvider).hasHmmSession()) {
      throw const HmmSignInRequired();
    }

    final datasource = ref.watch(exchangeRateRemoteDataSourceProvider);
    return datasource.getExchangeRate(pair.from, pair.to);
  },
);
