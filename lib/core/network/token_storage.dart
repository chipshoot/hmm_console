import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'hmm_access_token';
  static const _refreshTokenKey = 'hmm_refresh_token';
  static const _expiryKey = 'hmm_token_expiry';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _expiryKey, value: expiry.toIso8601String()),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<DateTime?> getExpiry() async {
    final value = await _storage.read(key: _expiryKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null) return false;
    final expiry = await getExpiry();
    if (expiry == null) return false;
    // Valid if token expires more than 60 seconds from now
    return expiry.isAfter(DateTime.now().add(const Duration(seconds: 60)));
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiryKey),
    ]);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(),
);
