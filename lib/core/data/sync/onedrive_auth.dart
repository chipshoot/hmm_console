import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'onedrive_config.dart';

class OneDriveAuthException implements Exception {
  const OneDriveAuthException(this.message);
  final String message;
  @override
  String toString() => 'OneDriveAuthException: $message';
}

/// OAuth 2.0 + PKCE flow against Microsoft identity platform.
///
/// We hand-roll the flow on top of `flutter_web_auth_2` rather than using
/// `flutter_appauth`. The AppAuth-iOS bridge silently drops the
/// ASWebAuthenticationSession callback on both iOS 18 and iOS 26 (verified
/// in the simulator: Microsoft redirected to `com.homemademessage.hmm://`,
/// LaunchServices identified the app as the handler, but the Dart Future
/// from `_appAuth.authorize()` never completed). `flutter_web_auth_2` is a
/// thin shim around `ASWebAuthenticationSession` that returns the callback
/// URL straight to Dart; the `/token` POST below is then a plain dio call.
///
/// Tokens live in `flutter_secure_storage` (Keychain on iOS/macOS, Keystore
/// on Android). Access token is auto-refreshed via `getAccessToken` when it
/// expires within a minute.
///
/// Registration + redirect URI setup: `docs/cloud_storage_setup.md` §1.
class OneDriveAuth {
  OneDriveAuth({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'onedrive_access_token';
  static const _refreshTokenKey = 'onedrive_refresh_token';
  static const _expiryKey = 'onedrive_token_expiry';

  // Microsoft v2.0 endpoints. Hard-coded rather than fetched from the
  // OIDC discovery doc — saves a round-trip and these never change.
  static const _authorizeEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  static const _tokenEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';

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

    // PKCE: random verifier, SHA-256 challenge. Microsoft requires PKCE
    // for public clients (no client secret). State is independent random
    // bytes used to detect cross-site request forgery on the callback.
    final codeVerifier = _randomUrlSafe(64);
    final codeChallenge = _sha256UrlSafe(codeVerifier);
    final state = _randomUrlSafe(32);

    final authUrl = Uri.parse(_authorizeEndpoint).replace(queryParameters: {
      'client_id': OneDriveConfig.clientId,
      'response_type': 'code',
      'redirect_uri': OneDriveConfig.redirectUri,
      'response_mode': 'query',
      'scope': OneDriveConfig.scopes.join(' '),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      // Force account chooser to prevent silent reuse of a stale session.
      'prompt': 'select_account',
    }).toString();

    try {
      // ignore: avoid_print
      print('[OneDrive] step1=webauth start');
      // ASWebAuthenticationSession on iOS, Custom Tabs on Android. Returns
      // the full callback URL (e.g.
      // com.homemademessage.hmm://auth?code=...&state=...) once iOS captures
      // a navigation matching `callbackUrlScheme`.
      final resultUrl = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: _callbackScheme,
      );
      // ignore: avoid_print
      print('[OneDrive] step1=webauth done');

      final parsed = Uri.parse(resultUrl);
      final error = parsed.queryParameters['error'];
      if (error != null) {
        throw OneDriveAuthException(
          'OAuth error from Microsoft: $error '
          '(${parsed.queryParameters['error_description'] ?? 'no description'})',
        );
      }
      if (parsed.queryParameters['state'] != state) {
        throw const OneDriveAuthException(
          'OAuth state mismatch — possible CSRF, aborting.',
        );
      }
      final code = parsed.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const OneDriveAuthException(
          'OAuth callback missing authorization code.',
        );
      }

      // ignore: avoid_print
      print('[OneDrive] step2=token exchange start');
      final response = await _dio.post<Map<String, dynamic>>(
        _tokenEndpoint,
        data: {
          'client_id': OneDriveConfig.clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': OneDriveConfig.redirectUri,
          'code_verifier': codeVerifier,
          'scope': OneDriveConfig.scopes.join(' '),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      // ignore: avoid_print
      print('[OneDrive] step2=token done');

      await _persistTokenResponse(response.data);
    } on OneDriveAuthException {
      rethrow;
    } on PlatformException catch (e) {
      // flutter_web_auth_2 throws PlatformException(code: CANCELED) when
      // the user dismisses the sheet.
      if (e.code == 'CANCELED') {
        throw const OneDriveAuthException('Sign-in was cancelled.');
      }
      throw OneDriveAuthException(
        'Browser auth failed: ${e.message ?? e.code}',
      );
    } on DioException catch (e) {
      // Surface Microsoft's error body verbatim — it usually carries
      // `error_description` with actionable detail (wrong redirect, bad
      // scope, etc.).
      final body = e.response?.data;
      throw OneDriveAuthException(
        'Token exchange failed (${e.response?.statusCode}): ${body ?? e.message}',
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('[OneDrive] signIn unexpected: $e\n$st');
      throw OneDriveAuthException('Unexpected OAuth error: $e');
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
      final response = await _dio.post<Map<String, dynamic>>(
        _tokenEndpoint,
        data: {
          'client_id': OneDriveConfig.clientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'scope': OneDriveConfig.scopes.join(' '),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      await _persistTokenResponse(
        response.data,
        fallbackRefreshToken: refreshToken,
      );
      return response.data?['access_token'] as String?;
    } on DioException {
      // Refresh token revoked or expired — drop local state so the user
      // is prompted to sign in again on the next attempt.
      await signOut();
      return null;
    }
  }

  Future<void> _persistTokenResponse(
    Map<String, dynamic>? body, {
    String? fallbackRefreshToken,
  }) async {
    if (body == null) {
      throw const OneDriveAuthException('Empty token response.');
    }
    final accessToken = body['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const OneDriveAuthException('Token response missing access_token.');
    }
    final refreshToken =
        (body['refresh_token'] as String?) ?? fallbackRefreshToken;
    final expiresIn = body['expires_in'];
    final expiry = expiresIn is num
        ? DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()))
        : null;

    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (expiry != null) {
      await _storage.write(
        key: _expiryKey,
        value: expiry.toIso8601String(),
      );
    }
  }

  /// Derives the callback URL scheme from `OneDriveConfig.redirectUri`
  /// (e.g. `com.homemademessage.hmm` from `com.homemademessage.hmm://auth`).
  /// flutter_web_auth_2 needs the scheme alone, not the full URL.
  static String get _callbackScheme {
    final uri = Uri.parse(OneDriveConfig.redirectUri);
    return uri.scheme;
  }

  static String _randomUrlSafe(int bytes) {
    final random = Random.secure();
    final values = List<int>.generate(bytes, (_) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  static String _sha256UrlSafe(String input) {
    final digest = sha256.convert(utf8.encode(input));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}

final oneDriveAuthProvider = Provider<OneDriveAuth>((ref) => OneDriveAuth());

/// Reactive "is the user signed in to OneDrive?" signal for the UI.
/// Invalidate this after calling `signIn`/`signOut` to refresh consumers.
final oneDriveAuthStateProvider = FutureProvider<bool>((ref) {
  return ref.watch(oneDriveAuthProvider).hasToken();
});
