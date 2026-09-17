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

      // Parse OAuth error response for meaningful messages.
      //
      // The IDP's CustomResourceOwnerPasswordValidator distinguishes failure
      // cases by setting `error_description` to one of:
      //   - "invalid_username_or_password"  (bad credentials)
      //   - "email_not_confirmed"           (password OK, account unverified)
      //   - "account_locked"                (too many failed attempts)
      // We map each to a typed AuthTokenException so the UI can present the
      // right next-step (sign-in retry vs verify-email vs wait/contact).
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final error = data['error'] as String?;
        final errorDescription = data['error_description'] as String?;

        if (error == 'invalid_grant') {
          switch (errorDescription) {
            case 'email_not_confirmed':
              throw AuthTokenException.emailNotConfirmed();
            case 'account_locked':
              throw AuthTokenException.accountLocked();
            case 'invalid_username_or_password':
            default:
              throw AuthTokenException.invalidCredentials();
          }
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

  /// Re-issues an email-verification link for an account that hasn't been
  /// confirmed yet. Fire-and-forget from the UI's perspective: the IDP returns
  /// 200 with the same generic body whether or not the email matches a real
  /// unconfirmed account (no enumeration leak). Network errors are swallowed
  /// — the user can simply tap "Resend email" again if their connection
  /// blipped, and there's nothing actionable to surface otherwise.
  Future<void> resendConfirmation({required String email}) async {
    try {
      await _dio.post(
        _config.resendConfirmationEndpoint,
        data: {'email': email},
        options: Options(contentType: Headers.jsonContentType),
      );
    } on DioException {
      // Intentionally swallowed.
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

      // A rejected refresh (revoked token, 400 invalid_grant) can arrive as a
      // non-throwing response carrying an error body. _storeTokens would
      // then crash on the missing access_token with a bare TypeError, which
      // is not something callers can catch as an auth failure.
      final data = response.data;
      if (response.statusCode != 200 ||
          data is! Map ||
          data['access_token'] is! String) {
        throw AuthTokenException.refreshFailed();
      }
      await _storeTokens(Map<String, dynamic>.from(data));
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

  /// Decode claims from the stored access token, refreshing it first if it
  /// has expired.
  ///
  /// Returns null only when the user is genuinely signed out: no tokens at
  /// all, or a refresh token the IdP rejects. It used to return null the
  /// moment the ACCESS token was past its lifetime, without ever trying the
  /// refresh token beside it — so an app restart with a stale token told
  /// OneDrive sync "no authenticated Hmm user" about a user who was signed
  /// in. getValidAccessToken() already knew how to refresh; this path just
  /// never used it.
  Future<Map<String, dynamic>?> getStoredClaims() async {
    try {
      return decodeJwtPayload(await getValidAccessToken());
    } on AuthTokenException {
      // Missing token, or refresh refused: signed out. Null is the honest
      // answer and callers already treat it as "no user" — this must not
      // become a throw on the sync path.
      return null;
    }
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

const _apiEnv = String.fromEnvironment('API_ENV', defaultValue: 'development');

final idpTokenServiceProvider = Provider<IdpTokenService>(
  (ref) => IdpTokenService(
    tokenStorage: ref.watch(tokenStorageProvider),
    config: _apiEnv == 'production' ? IdpConfig.production : IdpConfig.development,
  ),
);
