import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/app_exceptions.dart';
import 'idp_config.dart';
import 'jwt_utils.dart';
import 'token_storage.dart';

/// Reading the stored access token from secure storage failed (not: no
/// token, nor an undecodable one). It may succeed later, so callers that
/// persist something derived from the token must not fall back.
class TokenPeekException implements Exception {
  const TokenPeekException(this.cause);
  final Object cause;

  @override
  String toString() => 'TokenPeekException($cause)';
}

/// Result of [IdpTokenService.checkSession] at app start.
enum SessionCheck {
  /// A usable access token is stored (possibly just refreshed).
  signedIn,

  /// A session is stored but the IdP could not be reached to refresh it.
  /// It is kept, and the user treated as signed in.
  offline,

  /// No session, or the IdP refused the refresh token.
  signedOut,
}

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
  ///
  /// [beforeStore] runs with the decoded claims before any token is saved; if
  /// it throws, nothing is stored and the error propagates.
  Future<Map<String, dynamic>> authorize(
    String email,
    String password, {
    Future<void> Function(Map<String, dynamic> claims)? beforeStore,
  }) async {
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

      final accessToken = response.data['access_token'] as String;
      final claims = decodeJwtPayload(accessToken);
      if (beforeStore != null) await beforeStore(claims);
      await _storeTokens(response.data);
      _sessionChanges.add(null);
      return claims;
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
  ///
  /// Concurrent callers share one IdP request: the IdP rotates refresh
  /// tokens, so a second request with the old token would be refused and
  /// would wrongly end the session.
  ///
  /// Throws [AuthTokenException.refreshUnreachable] when the IdP cannot be
  /// reached or fails on its side (the session is kept), and
  /// [AuthTokenException.refreshFailed] when it refuses the refresh token —
  /// in which case the session is ended: tokens cleared, the session marked
  /// expired, and [sessionEnded] notified.
  Future<void> refreshAccessToken() =>
      _inflightRefresh ??= _refresh().whenComplete(() => _inflightRefresh = null);

  Future<void>? _inflightRefresh;

  Future<void> _refresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      throw AuthTokenException.missingToken();
    }

    final Response<dynamic> response;
    try {
      response = await _dio.post(
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
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        await _endSession(refreshToken);
        return;
      }
      throw AuthTokenException.refreshUnreachable();
    }

    // A rejected refresh (revoked token, 400 invalid_grant) can arrive as a
    // non-throwing response carrying an error body. _storeTokens would
    // then crash on the missing access_token with a bare TypeError, which
    // is not something callers can catch as an auth failure.
    final data = response.data;
    if (response.statusCode == 400 || response.statusCode == 401) {
      await _endSession(refreshToken);
      return;
    }
    if (response.statusCode != 200 ||
        data is! Map ||
        data['access_token'] is! String) {
      throw AuthTokenException.refreshFailed();
    }
    await _storeTokens(Map<String, dynamic>.from(data));
  }

  /// The IdP refused [sentToken]. Unless another refresh already stored a
  /// newer pair (then this refusal is stale and the session is fine), clear
  /// the session, remember it expired, notify, and throw refreshFailed.
  Future<void> _endSession(String sentToken) async {
    if (await _tokenStorage.getRefreshToken() != sentToken) return;
    final email = await _peekClaimOrNull('email');
    await _tokenStorage.clearTokens();
    await _tokenStorage.markSessionExpired(email);
    _sessionEnded.add(null);
    _sessionChanges.add(null);
    throw AuthTokenException.refreshFailed();
  }

  Future<String?> _peekClaimOrNull(String name) async {
    try {
      return await _peekClaim(name);
    } on TokenPeekException {
      return null;
    }
  }

  final _sessionEnded = StreamController<void>.broadcast();
  final _sessionChanges = StreamController<void>.broadcast();

  /// Fires when the IdP refused the refresh token and the session was ended.
  Stream<void> get sessionEnded => _sessionEnded.stream;

  /// Fires whenever the stored session or its expired flag changes (sign-in,
  /// sign-out, session ended, expired notice dismissed).
  Stream<void> get sessionChanges => _sessionChanges.stream;

  /// Decides at app start whether the stored Hmm session is usable.
  ///
  /// A valid access token is signed in. An expired one is refreshed first;
  /// if the IdP cannot be reached within [timeout], the session is kept and
  /// the user let in ([SessionCheck.offline]) — later API calls refresh it.
  /// Only a refused refresh token, or no session at all, is signed out.
  Future<SessionCheck> checkSession({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (await _tokenStorage.hasValidToken()) return SessionCheck.signedIn;
    if (await _tokenStorage.getRefreshToken() == null) {
      return SessionCheck.signedOut;
    }
    try {
      await refreshAccessToken().timeout(timeout);
      return SessionCheck.signedIn;
    } on TimeoutException {
      return SessionCheck.offline;
    } on AuthTokenException {
      return await hasHmmSession()
          ? SessionCheck.offline
          : SessionCheck.signedOut;
    }
  }

  /// The user acknowledged the "session expired" notice.
  Future<void> dismissExpiredSession() async {
    await _tokenStorage.clearSessionExpired();
    _sessionChanges.add(null);
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

  /// `sub` of the stored access token, expired or not. Never refreshes and
  /// never touches the network; null when no decodable token is stored.
  /// Throws [TokenPeekException] when secure storage cannot be read.
  Future<String?> peekStoredSub() => _peekClaim('sub');

  /// `email` of the stored access token, same rules as [peekStoredSub].
  Future<String?> peekStoredEmail() => _peekClaim('email');

  /// True when a refresh token is stored (a Hmm session exists, even if its
  /// access token has expired).
  Future<bool> hasHmmSession() async =>
      await _tokenStorage.getRefreshToken() != null;

  /// Null when no token is stored, it lacks the claim, or it cannot be
  /// decoded (a corrupt token never becomes decodable, so it counts as no
  /// token). Throws [TokenPeekException] only when reading secure storage
  /// fails, which may succeed later: callers must not persist a fallback.
  Future<String?> _peekClaim(String name) async {
    final String? token;
    try {
      token = await _tokenStorage.getAccessToken();
    } catch (e) {
      throw TokenPeekException(e);
    }
    if (token == null) return null;
    final Object? value;
    try {
      value = decodeJwtPayload(token)[name];
    } catch (_) {
      return null;
    }
    return value is String && value.isNotEmpty ? value : null;
  }

  /// Clear all stored tokens (on sign-out).
  Future<void> clearTokens() async {
    await _tokenStorage.clearTokens();
    _sessionChanges.add(null);
  }

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
