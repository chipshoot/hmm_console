import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/exceptions/app_exceptions.dart';
import 'package:hmm_console/core/network/interceptors/error_interceptor.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    dio.interceptors.add(ErrorInterceptor());
  });

  AppException? extractAppException(DioException e) {
    return e.error as AppException?;
  }

  group('ErrorInterceptor', () {
    test('maps connection timeout to NetworkException.timeout', () async {
      adapter.onGet(
        '/test',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/test'),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        final appEx = extractAppException(e);
        expect(appEx, isA<NetworkException>());
        expect(appEx!.code, 'TIMEOUT');
      }
    });

    test('maps connection error to NetworkException.noConnection', () async {
      adapter.onGet(
        '/test',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/test'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        final appEx = extractAppException(e);
        expect(appEx, isA<NetworkException>());
        expect(appEx!.code, 'NO_CONNECTION');
      }
    });

    test('maps cancel to NetworkException.cancelled', () async {
      adapter.onGet(
        '/test',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/test'),
            type: DioExceptionType.cancel,
          ),
        ),
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        final appEx = extractAppException(e);
        expect(appEx, isA<NetworkException>());
        expect(appEx!.code, 'CANCELLED');
      }
    });

    test('maps 404 bad response to ApiException', () async {
      adapter.onGet(
        '/test',
        (server) => server.reply(404, {
          'title': 'Not Found',
          'detail': 'Resource not found',
        }),
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        final appEx = extractAppException(e);
        expect(appEx, isA<ApiException>());
        final apiEx = appEx as ApiException;
        expect(apiEx.statusCode, 404);
        expect(apiEx.code, 'NOT_FOUND');
        expect(apiEx.message, 'Resource not found');
      }
    });

    test('parses RFC 7807 validation errors', () async {
      adapter.onPost(
        '/test',
        (server) => server.reply(400, {
          'title': 'Validation Error',
          'detail': 'One or more validation errors occurred',
          'errors': {
            'email': ['Invalid email format'],
            'name': ['Name is required'],
          },
        }),
        data: Matchers.any,
      );

      try {
        await dio.post('/test', data: {});
        fail('Should have thrown');
      } on DioException catch (e) {
        final appEx = extractAppException(e);
        expect(appEx, isA<ApiException>());
        final apiEx = appEx as ApiException;
        expect(apiEx.statusCode, 400);
        expect(apiEx.validationErrors['email'], ['Invalid email format']);
        expect(apiEx.validationErrors['name'], ['Name is required']);
      }
    });

    test('handles non-JSON error response', () async {
      adapter.onGet(
        '/test',
        (server) => server.reply(500, 'Internal Server Error'),
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        final appEx = extractAppException(e);
        expect(appEx, isA<ApiException>());
        final apiEx = appEx as ApiException;
        expect(apiEx.statusCode, 500);
        expect(apiEx.code, 'SERVER_ERROR');
      }
    });

    test('uses title when detail is empty in RFC 7807', () async {
      adapter.onGet(
        '/test',
        (server) => server.reply(403, {
          'title': 'Forbidden',
          'detail': '',
        }),
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        final appEx = extractAppException(e);
        expect(appEx, isA<ApiException>());
        final apiEx = appEx as ApiException;
        expect(apiEx.message, 'Forbidden');
      }
    });
  });
}
