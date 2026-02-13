import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Creates a [Dio] instance with a [DioAdapter] attached for request mocking.
(Dio, DioAdapter) createMockDio() {
  final dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
  final adapter = DioAdapter(dio: dio);
  return (dio, adapter);
}
