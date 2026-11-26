import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Logs `method host status ms` only. Never headers, bodies or full URLs.
class LlmLoggingInterceptor extends Interceptor {
  static const _startKey = 'llm.startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }

  void _log(RequestOptions o, int? status) {
    final start = o.extra[_startKey] as int?;
    final ms = start == null
        ? 0
        : DateTime.now().millisecondsSinceEpoch - start;
    debugPrint('llm ${o.method} ${o.uri.host} ${status ?? '-'} ${ms}ms');
  }
}

/// A Dio dedicated to AI providers: no auth interceptor (the Hmm access token
/// must never reach a provider) and never the Hmm API client.
final llmDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );
  dio.interceptors.add(LlmLoggingInterceptor());
  return dio;
});
