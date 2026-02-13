import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/exceptions/app_exceptions.dart';

void main() {
  group('AppException hierarchy', () {
    test('all exception types extend sealed AppException', () {
      expect(const AppFirebaseException('code', 'msg'), isA<AppException>());
      expect(const UnknownException(), isA<AppException>());
      expect(NetworkException.noConnection(), isA<AppException>());
      expect(
        const ApiException('code', 'msg', statusCode: 400),
        isA<AppException>(),
      );
      expect(AuthTokenException.exchangeFailed(), isA<AppException>());
    });

    test('toString includes message', () {
      const e = AppFirebaseException('AUTH', 'test message');
      expect(e.toString(), contains('test message'));
    });
  });

  group('NetworkException', () {
    test('noConnection() has correct code and message', () {
      final e = NetworkException.noConnection();
      expect(e.code, 'NO_CONNECTION');
      expect(e.message, 'No internet connection');
    });

    test('timeout() has correct code and message', () {
      final e = NetworkException.timeout();
      expect(e.code, 'TIMEOUT');
      expect(e.message, 'Request timed out');
    });

    test('cancelled() has correct code and message', () {
      final e = NetworkException.cancelled();
      expect(e.code, 'CANCELLED');
      expect(e.message, 'Request was cancelled');
    });
  });

  group('ApiException', () {
    test('fromStatusCode maps 400 to BAD_REQUEST', () {
      final e = ApiException.fromStatusCode(400, 'Bad request');
      expect(e.code, 'BAD_REQUEST');
      expect(e.statusCode, 400);
    });

    test('fromStatusCode maps 401 to UNAUTHORIZED', () {
      final e = ApiException.fromStatusCode(401, 'Unauthorized');
      expect(e.code, 'UNAUTHORIZED');
      expect(e.statusCode, 401);
    });

    test('fromStatusCode maps 403 to FORBIDDEN', () {
      final e = ApiException.fromStatusCode(403, 'Forbidden');
      expect(e.code, 'FORBIDDEN');
      expect(e.statusCode, 403);
    });

    test('fromStatusCode maps 404 to NOT_FOUND', () {
      final e = ApiException.fromStatusCode(404, 'Not found');
      expect(e.code, 'NOT_FOUND');
      expect(e.statusCode, 404);
    });

    test('fromStatusCode maps 409 to CONFLICT', () {
      final e = ApiException.fromStatusCode(409, 'Conflict');
      expect(e.code, 'CONFLICT');
      expect(e.statusCode, 409);
    });

    test('fromStatusCode maps 500 to SERVER_ERROR', () {
      final e = ApiException.fromStatusCode(500, 'Server error');
      expect(e.code, 'SERVER_ERROR');
      expect(e.statusCode, 500);
    });

    test('fromStatusCode maps 503 to SERVER_ERROR', () {
      final e = ApiException.fromStatusCode(503, 'Unavailable');
      expect(e.code, 'SERVER_ERROR');
      expect(e.statusCode, 503);
    });

    test('fromStatusCode maps unknown status to HTTP_<code>', () {
      final e = ApiException.fromStatusCode(418, "I'm a teapot");
      expect(e.code, 'HTTP_418');
      expect(e.statusCode, 418);
    });

    test('fromStatusCode preserves validation errors', () {
      final errors = {
        'email': ['Invalid email format'],
        'name': ['Name is required', 'Name too short'],
      };
      final e = ApiException.fromStatusCode(400, 'Validation failed', errors);
      expect(e.validationErrors, errors);
    });

    test('fromStatusCode defaults validationErrors to empty map', () {
      final e = ApiException.fromStatusCode(400, 'Bad request');
      expect(e.validationErrors, isEmpty);
    });
  });

  group('AuthTokenException', () {
    test('exchangeFailed() has correct code', () {
      final e = AuthTokenException.exchangeFailed();
      expect(e.code, 'TOKEN_EXCHANGE_FAILED');
    });

    test('refreshFailed() has correct code', () {
      final e = AuthTokenException.refreshFailed();
      expect(e.code, 'TOKEN_REFRESH_FAILED');
    });

    test('expired() has correct code', () {
      final e = AuthTokenException.expired();
      expect(e.code, 'TOKEN_EXPIRED');
    });

    test('missingToken() has correct code', () {
      final e = AuthTokenException.missingToken();
      expect(e.code, 'MISSING_TOKEN');
    });
  });
}
