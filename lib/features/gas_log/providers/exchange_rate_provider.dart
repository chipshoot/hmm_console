import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/exchange_rate_remote_datasource.dart';

typedef CurrencyPair = ({String from, String to});

final exchangeRateProvider =
    FutureProvider.family<double, CurrencyPair>((ref, pair) async {
  ref.keepAlive();

  if (pair.from == pair.to) return 1.0;

  final datasource = ref.watch(exchangeRateRemoteDataSourceProvider);
  return datasource.getExchangeRate(pair.from, pair.to);
});
