import 'dart:io' show Platform;

class ApiConfig {
  const ApiConfig({required this.baseUrl});

  final String baseUrl;

  static const production = ApiConfig(
    baseUrl: 'https://api.homemademessage.com/api/v1',
  );

  static final development = ApiConfig(
    baseUrl: 'http://$_devHost:5010/api/v1',
  );

  static String get _devHost => Platform.isAndroid ? '10.0.2.2' : 'localhost';
}
