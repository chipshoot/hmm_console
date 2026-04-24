import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'onedrive_config.dart';

class OneDriveAuthException implements Exception {
  const OneDriveAuthException(this.message);
  final String message;
  @override
  String toString() => 'OneDriveAuthException: $message';
}

/// OAuth 2.0 + PKCE flow against Microsoft identity platform.
///
/// Tokens live in `flutter_secure_storage` (Keychain on iOS/macOS, Keystore on
/// Android). Access token is refreshed automatically via `getAccessToken` when
/// it expires within a minute.
///
/// Registration + redirect URI setup: `docs/cloud_storage_setup.md` §1.
class OneDriveAuth {
  OneDriveAuth({
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? storage,
  })  : _appAuth = appAuth ?? const FlutterAppAuth(),
        _storage = storage ?? const FlutterSecureStorage();

  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'onedrive_access_token';
  static const _refreshTokenKey = 'onedrive_refresh_token';
  static const _expiryKey = 'onedrive_token_expiry';

  Future<bool> hasToken() async {
    final token = await _storage.read(key: _refreshTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> signIn() async {
    if (!OneDriveConfig.isConfigured) {
      throw const OneDriveAuthException(
        'OneDrive client ID is not set. Rebuild with '
        '--dart-define=ONEDRIVE_CLIENT_ID=<your-app-id> after registering '
        'the app (see docs/cloud_storage_setup.md §1).',
      );
    }
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          OneDriveConfig.clientId,
          OneDriveConfig.redirectUri,
          discoveryUrl: OneDriveConfig.discoveryUrl,
          scopes: OneDriveConfig.scopes,
        ),
      );
      await _persist(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiry: result.accessTokenExpirationDateTime,
      );
    } on FlutterAppAuthUserCancelledException {
      throw const OneDriveAuthException('Sign-in was cancelled.');
    } on FlutterAppAuthPlatformException catch (e) {
      throw OneDriveAuthException(
        'OAuth flow failed: ${e.message ?? e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiryKey);
  }

  /// Returns a valid access token, refreshing if needed. Null when the user
  /// is not signed in or refresh has failed (cleared credentials).
  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    final expiryRaw = await _storage.read(key: _expiryKey);
    if (token != null && token.isNotEmpty && expiryRaw != null) {
      final expiry = DateTime.tryParse(expiryRaw);
      // 60-second safety margin so an in-flight request doesn't 401 mid-flight.
      if (expiry != null &&
          expiry.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 1)))) {
        return token;
      }
    }
    return _refresh();
  }

  Future<String?> _refresh() async {
    if (!OneDriveConfig.isConfigured) return null;
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final result = await _appAuth.token(
        TokenRequest(
          OneDriveConfig.clientId,
          OneDriveConfig.redirectUri,
          discoveryUrl: OneDriveConfig.discoveryUrl,
          refreshToken: refreshToken,
          scopes: OneDriveConfig.scopes,
        ),
      );
      await _persist(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken ?? refreshToken,
        expiry: result.accessTokenExpirationDateTime,
      );
      return result.accessToken;
    } on FlutterAppAuthPlatformException {
      // Refresh token revoked or expired — drop local state so the user
      // is prompted to sign in again on the next attempt.
      await signOut();
      return null;
    }
  }

  Future<void> _persist({
    required String? accessToken,
    required String? refreshToken,
    required DateTime? expiry,
  }) async {
    if (accessToken == null) {
      throw const OneDriveAuthException('Auth response missing access_token.');
    }
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (expiry != null) {
      await _storage.write(
        key: _expiryKey,
        value: expiry.toUtc().toIso8601String(),
      );
    }
  }
}

final oneDriveAuthProvider = Provider<OneDriveAuth>((ref) => OneDriveAuth());

/// Reactive "is the user signed in to OneDrive?" signal for the UI.
/// Invalidate this after calling `signIn`/`signOut` to refresh consumers.
final oneDriveAuthStateProvider = FutureProvider<bool>((ref) {
  return ref.watch(oneDriveAuthProvider).hasToken();
});
