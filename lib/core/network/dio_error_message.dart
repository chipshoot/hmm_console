import 'package:dio/dio.dart';

/// Extracts a human-friendly message from any error thrown by the Dio
/// client. For successful HTTP failures (4xx/5xx) the API's response
/// body — typically `{"errors": ["..."]}` from `ApiBadRequestResponse`
/// or a `{"message": "..."}` shape — is preferred over the SDK's
/// generic `DioException` toString. Network errors fall back to a
/// short connectivity description.
String dioErrorMessage(Object error) {
  if (error is DioException) {
    final response = error.response;
    if (response != null) {
      final body = response.data;
      final fromBody = _extractFromBody(body);
      if (fromBody != null && fromBody.isNotEmpty) return fromBody;
      return 'HTTP ${response.statusCode ?? '?'}';
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out',
      DioExceptionType.receiveTimeout => 'Server took too long to respond',
      DioExceptionType.sendTimeout => 'Upload timed out',
      DioExceptionType.connectionError =>
        'Cannot reach the server. Check your network and that the API is running.',
      DioExceptionType.cancel => 'Request cancelled',
      _ => error.message ?? 'Network error',
    };
  }
  return error.toString();
}

String? _extractFromBody(dynamic body) {
  if (body is String) return body.isEmpty ? null : body;
  if (body is Map<String, dynamic>) {
    // ApiBadRequestResponse: { "errors": ["..."], ... }
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors.map((e) => e.toString()).join('; ');
    }
    if (body['message'] is String) return body['message'] as String;
    if (body['errorMessage'] is String) return body['errorMessage'] as String;
    if (body['title'] is String) return body['title'] as String;
    if (body['detail'] is String) return body['detail'] as String;
  }
  return null;
}
