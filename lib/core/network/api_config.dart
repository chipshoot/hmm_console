class ApiConfig {
  const ApiConfig({required this.baseUrl});

  final String baseUrl;

  static const production = ApiConfig(
    baseUrl: 'https://api.homemademessage.com/api/v1',
  );

  static const development = ApiConfig(
    baseUrl: 'https://localhost:5010/api/v1',
  );
}
