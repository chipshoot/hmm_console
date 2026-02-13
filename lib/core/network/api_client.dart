import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'idp_token_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

class ApiClient {
  ApiClient(this.dio);

  final Dio dio;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenService = ref.watch(idpTokenServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.development.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Order: logging → auth → error
  dio.interceptors.addAll([
    LoggingInterceptor(),
    AuthInterceptor(tokenService),
    ErrorInterceptor(),
  ]);

  return ApiClient(dio);
});
