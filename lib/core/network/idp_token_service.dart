import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/app_exceptions.dart';
import 'idp_config.dart';
import 'token_storage.dart';

class IdpTokenService {
  IdpTokenService({
    required TokenStorage tokenStorage,
    required IdpConfig config,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _config = config,
        _dio = dio ?? Dio();

  final TokenStorage _tokenStorage;
  final IdpConfig _config;
  final Dio _dio;

  /// Authenticate with email/password using ROPC grant.
  /// Used after Firebase login to obtain IDP tokens for API access.
  Future<void> authorize(String email, String password) async {
    try {
      final response = await _dio.post(
        _config.tokenEndpoint,
        data: {
          'grant_type': 'password',
          'client_id': _config.clientId,
          'client_secret': _config.clientSecret,
          'username': email,
          'password': password,
          'scope': _config.scopes,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      await _storeTokens(response.data);
    } on DioException {
      throw AuthTokenException.exchangeFailed();
    }
  }

  /// Refresh the access token using the stored refresh token.
  Future<void> refreshAccessToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      throw AuthTokenException.missingToken();
    }

    try {
      final response = await _dio.post(
        _config.tokenEndpoint,
        data: {
          'grant_type': 'refresh_token',
          'client_id': _config.clientId,
          'client_secret': _config.clientSecret,
          'refresh_token': refreshToken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      await _storeTokens(response.data);
    } on DioException {
      throw AuthTokenException.refreshFailed();
    }
  }

  /// Returns a valid access token, refreshing if necessary.
  Future<String> getValidAccessToken() async {
    if (await _tokenStorage.hasValidToken()) {
      final token = await _tokenStorage.getAccessToken();
      if (token != null) return token;
    }

    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken != null) {
      await refreshAccessToken();
      final token = await _tokenStorage.getAccessToken();
      if (token != null) return token;
    }

    throw AuthTokenException.missingToken();
  }

  /// Clear all stored tokens (on sign-out).
  Future<void> clearTokens() => _tokenStorage.clearTokens();

  Future<void> _storeTokens(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final expiresIn = data['expires_in'] as int;
    final expiry = DateTime.now().add(Duration(seconds: expiresIn));

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiry: expiry,
    );
  }
}

final idpTokenServiceProvider = Provider<IdpTokenService>(
  (ref) => IdpTokenService(
    tokenStorage: ref.watch(tokenStorageProvider),
    config: IdpConfig.development,
  ),
);
