import 'package:hmm_console/core/network/token_storage.dart';

/// In-memory implementation of [TokenStorage] for testing.
/// Avoids dependency on FlutterSecureStorage platform channels.
class MockTokenStorage extends TokenStorage {
  MockTokenStorage() : super(null);

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiry;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiry = expiry;
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<DateTime?> getExpiry() async => _expiry;

  @override
  Future<bool> hasValidToken() async {
    if (_accessToken == null || _expiry == null) return false;
    return _expiry!.isAfter(DateTime.now().add(const Duration(seconds: 60)));
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _expiry = null;
  }
}
