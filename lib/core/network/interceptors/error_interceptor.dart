import 'package:dio/dio.dart';

import '../../exceptions/app_exceptions.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = _mapToAppException(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
      ),
    );
  }

  AppException _mapToAppException(DioException err) {
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        NetworkException.timeout(),
      DioExceptionType.connectionError => NetworkException.noConnection(),
      DioExceptionType.cancel => NetworkException.cancelled(),
      DioExceptionType.badResponse => _mapBadResponse(err),
      _ => const UnknownException(),
    };
  }

  AppException _mapBadResponse(DioException err) {
    final statusCode = err.response?.statusCode ?? 0;
    final data = err.response?.data;

    // Try to parse RFC 7807 Problem Details
    if (data is Map<String, dynamic>) {
      final title = data['title'] as String? ?? '';
      final detail = data['detail'] as String? ?? '';
      final message = detail.isNotEmpty ? detail : title;
      final errors = _parseValidationErrors(data['errors']);
      return ApiException.fromStatusCode(statusCode, message, errors);
    }

    return ApiException.fromStatusCode(
      statusCode,
      err.message ?? 'Request failed with status $statusCode',
    );
  }

  Map<String, List<String>>? _parseValidationErrors(dynamic errors) {
    if (errors is! Map<String, dynamic>) return null;

    final result = <String, List<String>>{};
    for (final entry in errors.entries) {
      if (entry.value is List) {
        result[entry.key] =
            (entry.value as List).map((e) => e.toString()).toList();
      }
    }
    return result.isEmpty ? null : result;
  }
}
