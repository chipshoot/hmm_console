import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/app_exceptions.dart';
import 'idp_config.dart';
import 'jwt_utils.dart';
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
  /// Returns decoded JWT claims from the access token.
  Future<Map<String, dynamic>> authorize(String email, String password) async {
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
      final accessToken = response.data['access_token'] as String;
      return decodeJwtPayload(accessToken);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw NetworkException.noConnection();
      }

      if (e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw NetworkException.timeout();
      }

      // Parse OAuth error response for meaningful messages
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final error = data['error'] as String?;
        final errorDescription = data['error_description'] as String?;

        if (error == 'invalid_grant') {
          throw AuthTokenException.invalidCredentials();
        }

        if (errorDescription != null && errorDescription.isNotEmpty) {
          throw AuthTokenException(
            error?.toUpperCase() ?? 'AUTH_ERROR',
            errorDescription,
          );
        }
      }

      // Map HTTP status codes to meaningful messages
      final statusCode = e.response?.statusCode;
      if (statusCode != null) {
        throw AuthTokenException.fromStatusCode(statusCode);
      }

      throw AuthTokenException.exchangeFailed();
    }
  }

  /// Register a new user via the IDP API.
  /// Returns the registration response or throws on failure.
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post(
        _config.registerEndpoint,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'confirmPassword': confirmPassword,
        },
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode == 400) {
        final data = e.response!.data;
        if (data is Map<String, dynamic> && data.containsKey('errors')) {
          final errors = data['errors'] as Map<String, dynamic>;
          final messages = errors.values
              .expand((v) => v is List ? v : [v])
              .map((e) => e.toString())
              .toList();
          throw ApiException.fromStatusCode(
            400,
            messages.join('. '),
          );
        }
      }
      throw const ApiException('REGISTRATION_FAILED', 'Registration failed');
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

  /// Decode claims from the stored access token, if valid.
  Future<Map<String, dynamic>?> getStoredClaims() async {
    if (!await _tokenStorage.hasValidToken()) return null;
    final token = await _tokenStorage.getAccessToken();
    if (token == null) return null;
    return decodeJwtPayload(token);
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
