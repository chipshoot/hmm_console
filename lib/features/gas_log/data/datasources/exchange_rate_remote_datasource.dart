import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

class ExchangeRateRemoteDataSource {
  ExchangeRateRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<double> getExchangeRate(String from, String to) async {
    if (from == to) return 1.0;

    final response = await _apiClient.dio.get(
      '/currency/exchange-rate',
      queryParameters: {'from': from, 'to': to},
    );

    final data = response.data as Map<String, dynamic>;
    return (data['rate'] as num).toDouble();
  }
}

final exchangeRateRemoteDataSourceProvider =
    Provider<ExchangeRateRemoteDataSource>(
  (ref) => ExchangeRateRemoteDataSource(ref.watch(apiClientProvider)),
);
