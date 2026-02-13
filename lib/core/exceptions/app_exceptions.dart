sealed class AppException implements Exception {
  const AppException(this.code, this.message);

  final String message;
  final String code;

  @override
  String toString() => 'AppException: $message';
}

class AppFirebaseException extends AppException {
  const AppFirebaseException(super.code, super.message);
}

class UnknownException extends AppException {
  const UnknownException() : super('UNKNOWN', 'An unknown error occurred');
}

class NetworkException extends AppException {
  const NetworkException(super.code, super.message);

  factory NetworkException.noConnection() =>
      const NetworkException('NO_CONNECTION', 'No internet connection');

  factory NetworkException.timeout() =>
      const NetworkException('TIMEOUT', 'Request timed out');

  factory NetworkException.cancelled() =>
      const NetworkException('CANCELLED', 'Request was cancelled');
}

class ApiException extends AppException {
  const ApiException(
    super.code,
    super.message, {
    this.statusCode = 0,
    this.validationErrors = const {},
  });

  final int statusCode;
  final Map<String, List<String>> validationErrors;

  factory ApiException.fromStatusCode(
    int statusCode,
    String message, [
    Map<String, List<String>>? validationErrors,
  ]) {
    final code = switch (statusCode) {
      400 => 'BAD_REQUEST',
      401 => 'UNAUTHORIZED',
      403 => 'FORBIDDEN',
      404 => 'NOT_FOUND',
      409 => 'CONFLICT',
      >= 500 => 'SERVER_ERROR',
      _ => 'HTTP_$statusCode',
    };
    return ApiException(
      code,
      message,
      statusCode: statusCode,
      validationErrors: validationErrors ?? const {},
    );
  }
}

class AuthTokenException extends AppException {
  const AuthTokenException(super.code, super.message);

  factory AuthTokenException.exchangeFailed() =>
      const AuthTokenException('TOKEN_EXCHANGE_FAILED', 'Token exchange failed');

  factory AuthTokenException.refreshFailed() =>
      const AuthTokenException('TOKEN_REFRESH_FAILED', 'Token refresh failed');

  factory AuthTokenException.expired() =>
      const AuthTokenException('TOKEN_EXPIRED', 'Token has expired');

  factory AuthTokenException.missingToken() =>
      const AuthTokenException('MISSING_TOKEN', 'No token available');
}
