import 'package:dio/dio.dart';

import '../idp_token_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenService);

  final IdpTokenService _tokenService;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenService.getValidAccessToken();
      options.headers['Authorization'] = 'Bearer $token';
    } catch (_) {
      // Proceed without token — the server will return 401 if needed
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        await _tokenService.refreshAccessToken();
        final token = await _tokenService.getValidAccessToken();

        // Retry the original request with the new token
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $token';

        final response = await Dio().fetch(options);
        return handler.resolve(response);
      } catch (_) {
        // Refresh failed — propagate the original 401
      }
    }
    handler.next(err);
  }
}
