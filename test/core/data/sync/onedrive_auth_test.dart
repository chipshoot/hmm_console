import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/onedrive_config.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Unit-test coverage for [OneDriveAuth] — the OAuth 2.0 + PKCE flow that
/// replaced `flutter_appauth` after its iOS bridge was confirmed to drop the
/// ASWebAuthenticationSession callback on iOS 18.5 + 26.4.
///
/// The native `FlutterWebAuth2.authenticate` call is mocked via the injected
/// [WebAuthRunner] typedef, so no simulator / device is required. The /token
/// POST is mocked via http_mock_adapter against a real [Dio] instance pinned
/// to the same login.microsoftonline.com base, so we exercise the real
/// request body + content-type that production sends.
void main() {
  const tokenEndpoint =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';

  late _FakeSecureStorage storage;
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    storage = _FakeSecureStorage();
    // Bare dio — no baseUrl so http_mock_adapter matches the absolute URL
    // we POST to (Microsoft's /token endpoint). Mirrors api_sync_provider's
    // approach but inverted: production OneDriveAuth uses absolute URLs.
    dio = Dio();
    adapter = DioAdapter(dio: dio);
  });

  /// Build a OneDriveAuth wired to the fake storage + mock dio with a runner
  /// the test supplies. The runner is what stands in for the real
  /// ASWebAuthenticationSession sheet.
  OneDriveAuth buildAuth(WebAuthRunner runner) {
    return OneDriveAuth(
      dio: dio,
      storage: storage,
      webAuthRunner: runner,
    );
  }

  // =========================================================================
  // PKCE & authorize-URL construction
  // =========================================================================
  group('authorize URL & PKCE', () {
    test('passes a well-formed Microsoft authorize URL to the runner',
        () async {
      Uri? capturedUri;
      String? capturedScheme;
      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        capturedUri = Uri.parse(url);
        capturedScheme = callbackUrlScheme;
        // Synthesize the eventual Microsoft callback so signIn() proceeds
        // to the /token leg (we don't care about that side-effect here —
        // we're only asserting on the authorize URL).
        final state = capturedUri!.queryParameters['state']!;
        return Future.value(
          '${OneDriveConfig.redirectUri}?code=stub-code&state=$state',
        );
      });
      _stubTokenSuccess(adapter);

      await auth.signIn();

      expect(capturedUri, isNotNull);
      expect(
        '${capturedUri!.scheme}://${capturedUri!.host}${capturedUri!.path}',
        'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      );
      final q = capturedUri!.queryParameters;
      expect(q['client_id'], OneDriveConfig.clientId);
      expect(q['response_type'], 'code');
      expect(q['response_mode'], 'query');
      expect(q['redirect_uri'], OneDriveConfig.redirectUri);
      expect(q['scope'], OneDriveConfig.scopes.join(' '));
      expect(q['code_challenge_method'], 'S256');
      expect(q['prompt'], 'select_account');
      expect(q['state'], isNotEmpty);
      expect(q['code_challenge'], isNotEmpty);
      // Callback scheme is the bare scheme, not the full URI.
      expect(capturedScheme, Uri.parse(OneDriveConfig.redirectUri).scheme);
    });

    test('code_challenge is base64url(SHA-256(code_verifier)) without padding',
        () async {
      // To verify this we capture the verifier (sent to /token) and the
      // challenge (in the authorize URL) and recompute the SHA-256
      // round-trip manually.
      //
      // We grab the verifier via a dio interceptor rather than the adapter's
      // body matcher because dio runs its form-url-encoded transformer
      // *before* the adapter inspects the request, so by then the Map has
      // already been flattened to a string. The interceptor fires earlier,
      // while the request body is still a Map.
      Uri? capturedAuthorize;
      String? capturedVerifier;
      dio.interceptors.add(
        InterceptorsWrapper(onRequest: (options, handler) {
          if (options.data is Map &&
              (options.data as Map).containsKey('code_verifier')) {
            capturedVerifier = (options.data as Map)['code_verifier'] as String?;
          }
          handler.next(options);
        }),
      );

      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        capturedAuthorize = Uri.parse(url);
        final state = capturedAuthorize!.queryParameters['state']!;
        return Future.value(
          '${OneDriveConfig.redirectUri}?code=stub-code&state=$state',
        );
      });
      _stubTokenSuccess(adapter);

      await auth.signIn();

      expect(capturedVerifier, isNotNull,
          reason: 'code_verifier must be POSTed to /token');
      final challenge = capturedAuthorize!.queryParameters['code_challenge']!;
      // The challenge must be base64url(sha256(verifier)) with padding
      // stripped — RFC 7636 §4.2.
      final expectedChallenge = base64Url
          .encode(sha256.convert(utf8.encode(capturedVerifier!)).bytes)
          .replaceAll('=', '');
      expect(challenge, expectedChallenge);
      // Sanity: padding really is gone.
      expect(challenge.endsWith('='), isFalse);
    });

    test('state is unique per sign-in attempt', () async {
      final states = <String>{};
      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        final state = Uri.parse(url).queryParameters['state']!;
        states.add(state);
        return Future.value(
          '${OneDriveConfig.redirectUri}?code=c&state=$state',
        );
      });
      _stubTokenSuccess(adapter, times: 3);

      await auth.signIn();
      await auth.signIn();
      await auth.signIn();

      expect(states.length, 3,
          reason: 'each authorize call must generate a fresh state');
    });
  });

  // =========================================================================
  // signIn — happy path
  // =========================================================================
  group('signIn happy path', () {
    test('exchanges code for tokens and persists access + refresh + expiry',
        () async {
      final auth = buildAuth(_replayRunnerWithStubCode());
      _stubTokenSuccess(adapter);

      await auth.signIn();

      expect(await storage.read(key: 'onedrive_access_token'), 'AT-1');
      expect(await storage.read(key: 'onedrive_refresh_token'), 'RT-1');
      final expiryStr = await storage.read(key: 'onedrive_token_expiry');
      expect(expiryStr, isNotNull);
      final expiry = DateTime.parse(expiryStr!);
      // expires_in: 3600s → expiry ~= now + 1h. Generous bounds because the
      // test process clock isn't injected.
      final delta = expiry.difference(DateTime.now().toUtc());
      expect(delta.inMinutes, inInclusiveRange(59, 61));
    });

    test('after signIn, hasToken returns true', () async {
      final auth = buildAuth(_replayRunnerWithStubCode());
      _stubTokenSuccess(adapter);

      expect(await auth.hasToken(), isFalse);
      await auth.signIn();
      expect(await auth.hasToken(), isTrue);
    });
  });

  // =========================================================================
  // signIn — callback validation errors
  // =========================================================================
  group('signIn callback validation', () {
    test('throws on state mismatch (CSRF guard)', () async {
      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        // Return a callback with a DIFFERENT state than the one in the URL.
        return Future.value(
          '${OneDriveConfig.redirectUri}?code=c&state=NOT_THE_ORIGINAL',
        );
      });

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<OneDriveAuthException>().having(
            (e) => e.message,
            'message',
            contains('state mismatch'),
          ),
        ),
      );
    });

    test("surfaces Microsoft's error + error_description from callback",
        () async {
      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        return Future.value(
          '${OneDriveConfig.redirectUri}'
          '?error=access_denied&error_description=User+refused+consent',
        );
      });

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<OneDriveAuthException>()
              .having((e) => e.message, 'message', contains('access_denied'))
              .having(
                  (e) => e.message, 'message', contains('User refused consent')),
        ),
      );
    });

    test('throws when callback URL has no code parameter', () async {
      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        final state = Uri.parse(url).queryParameters['state']!;
        // Missing `code` — same state to make sure THIS is the error we hit,
        // not the state-mismatch one above.
        return Future.value('${OneDriveConfig.redirectUri}?state=$state');
      });

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<OneDriveAuthException>().having(
            (e) => e.message,
            'message',
            contains('missing authorization code'),
          ),
        ),
      );
    });
  });

  // =========================================================================
  // signIn — exception mapping
  // =========================================================================
  group('signIn exception mapping', () {
    test('PlatformException(CANCELED) → "Sign-in was cancelled"', () async {
      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        throw PlatformException(code: 'CANCELED', message: 'user cancelled');
      });

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<OneDriveAuthException>().having(
            (e) => e.message,
            'message',
            'Sign-in was cancelled.',
          ),
        ),
      );
    });

    test('other PlatformException → "Browser auth failed: ..."', () async {
      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        throw PlatformException(code: 'BAD_THING', message: 'something broke');
      });

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<OneDriveAuthException>().having(
            (e) => e.message,
            'message',
            contains('Browser auth failed'),
          ),
        ),
      );
    });

    test('DioException from /token → wrapped with Microsoft\'s body', () async {
      final auth = buildAuth(_replayRunnerWithStubCode());
      // Microsoft returns 400 with this body for an invalid grant.
      adapter.onPost(
        tokenEndpoint,
        (server) => server.reply(
          400,
          {'error': 'invalid_grant', 'error_description': 'Code expired'},
        ),
        data: Matchers.any,
      );

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<OneDriveAuthException>()
              .having((e) => e.message, 'message', contains('400'))
              .having(
                  (e) => e.message, 'message', contains('invalid_grant')),
        ),
      );
    });

    test('unknown exception is wrapped, not swallowed', () async {
      final auth = buildAuth(({required url, required callbackUrlScheme}) {
        throw StateError('something unexpected from the platform');
      });

      await expectLater(
        auth.signIn(),
        throwsA(
          isA<OneDriveAuthException>().having(
            (e) => e.message,
            'message',
            contains('Unexpected OAuth error'),
          ),
        ),
      );
    });
  });

  // =========================================================================
  // getAccessToken — expiry-driven cache vs refresh
  // =========================================================================
  group('getAccessToken', () {
    test('returns cached token when expiry is well in the future', () async {
      final auth = OneDriveAuth(
        dio: dio,
        storage: storage,
        webAuthRunner: ({required url, required callbackUrlScheme}) =>
            throw StateError('runner must not be called'),
      );
      // Manually pre-seed storage with a token that won't expire for an hour.
      await _seedTokens(
        storage,
        access: 'CACHED-AT',
        refresh: 'RT-CACHED',
        expiry: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      expect(await auth.getAccessToken(), 'CACHED-AT');
    });

    test('refreshes when expiry is inside the 60-second safety margin',
        () async {
      final auth = buildAuth(
        ({required url, required callbackUrlScheme}) =>
            throw StateError('runner must not be called on refresh'),
      );
      await _seedTokens(
        storage,
        access: 'OLD-AT',
        refresh: 'OLD-RT',
        // 30 s out — inside the 60-second safety margin → must refresh.
        expiry: DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );
      adapter.onPost(
        tokenEndpoint,
        (server) => server.reply(200, _validTokenBody(
          accessToken: 'NEW-AT',
          refreshToken: 'NEW-RT',
        )),
        data: Matchers.any,
      );

      expect(await auth.getAccessToken(), 'NEW-AT');
      expect(await storage.read(key: 'onedrive_access_token'), 'NEW-AT');
      expect(await storage.read(key: 'onedrive_refresh_token'), 'NEW-RT');
    });

    test('returns null when no refresh token is stored', () async {
      final auth = buildAuth(
        ({required url, required callbackUrlScheme}) =>
            throw StateError('runner must not be called'),
      );

      expect(await auth.getAccessToken(), isNull);
    });

    test('clears storage when refresh POST fails (e.g. revoked token)',
        () async {
      final auth = buildAuth(
        ({required url, required callbackUrlScheme}) =>
            throw StateError('runner must not be called'),
      );
      await _seedTokens(
        storage,
        access: 'OLD-AT',
        refresh: 'REVOKED-RT',
        expiry: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      adapter.onPost(
        tokenEndpoint,
        (server) => server.reply(
          400,
          {'error': 'invalid_grant', 'error_description': 'Token revoked'},
        ),
        data: Matchers.any,
      );

      expect(await auth.getAccessToken(), isNull);
      expect(await storage.read(key: 'onedrive_access_token'), isNull);
      expect(await storage.read(key: 'onedrive_refresh_token'), isNull);
      expect(await storage.read(key: 'onedrive_token_expiry'), isNull);
    });

    test('refresh that omits refresh_token preserves the old one', () async {
      // Microsoft does usually rotate the refresh_token, but the spec
      // allows it to be omitted on refresh — in that case we must keep
      // using the existing one.
      final auth = buildAuth(
        ({required url, required callbackUrlScheme}) =>
            throw StateError('runner must not be called'),
      );
      await _seedTokens(
        storage,
        access: 'OLD-AT',
        refresh: 'PRESERVED-RT',
        expiry: DateTime.now().toUtc().subtract(const Duration(seconds: 5)),
      );
      adapter.onPost(
        tokenEndpoint,
        (server) => server.reply(200, {
          'access_token': 'NEW-AT',
          // no refresh_token field
          'expires_in': 3600,
          'token_type': 'Bearer',
        }),
        data: Matchers.any,
      );

      expect(await auth.getAccessToken(), 'NEW-AT');
      expect(await storage.read(key: 'onedrive_refresh_token'),
          'PRESERVED-RT');
    });
  });

  // =========================================================================
  // signOut + hasToken
  // =========================================================================
  group('signOut & hasToken', () {
    test('signOut clears all three storage keys', () async {
      final auth = buildAuth(
        ({required url, required callbackUrlScheme}) =>
            throw StateError('runner must not be called'),
      );
      await _seedTokens(
        storage,
        access: 'AT',
        refresh: 'RT',
        expiry: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      await auth.signOut();

      expect(await storage.read(key: 'onedrive_access_token'), isNull);
      expect(await storage.read(key: 'onedrive_refresh_token'), isNull);
      expect(await storage.read(key: 'onedrive_token_expiry'), isNull);
    });

    test('hasToken false when refresh_token is absent', () async {
      final auth = buildAuth(
        ({required url, required callbackUrlScheme}) =>
            throw StateError('runner must not be called'),
      );
      expect(await auth.hasToken(), isFalse);
    });

    test('hasToken false when refresh_token is empty string', () async {
      final auth = buildAuth(
        ({required url, required callbackUrlScheme}) =>
            throw StateError('runner must not be called'),
      );
      await storage.write(key: 'onedrive_refresh_token', value: '');
      expect(await auth.hasToken(), isFalse);
    });
  });
}

// ===========================================================================
// Helpers
// ===========================================================================

/// Returns a runner that replays the state from the authorize URL back into
/// a synthetic callback. Used by happy-path tests that focus on the /token
/// leg rather than callback validation.
WebAuthRunner _replayRunnerWithStubCode({String code = 'stub-code'}) {
  return ({required String url, required String callbackUrlScheme}) {
    final state = Uri.parse(url).queryParameters['state']!;
    return Future.value(
      '${OneDriveConfig.redirectUri}?code=$code&state=$state',
    );
  };
}

/// Stubs the /token POST to return a valid token body. `times` lets a single
/// stub satisfy several sequential signIn() calls (state-uniqueness test).
/// `data: Matchers.any` mirrors the project's existing http_mock_adapter
/// convention (see test/core/data/vault/api_vault_store_test.dart) — the
/// default FullHttpRequestMatcher also tries to match the request body,
/// which doesn't fit cleanly here because production form-encodes a Map.
void _stubTokenSuccess(DioAdapter adapter, {int times = 1}) {
  for (var i = 0; i < times; i++) {
    adapter.onPost(
      'https://login.microsoftonline.com/common/oauth2/v2.0/token',
      (server) => server.reply(200, _validTokenBody()),
      data: Matchers.any,
    );
  }
}

Map<String, dynamic> _validTokenBody({
  String accessToken = 'AT-1',
  String refreshToken = 'RT-1',
  int expiresIn = 3600,
}) =>
    {
      'token_type': 'Bearer',
      'scope': OneDriveConfig.scopes.join(' '),
      'expires_in': expiresIn,
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };

Future<void> _seedTokens(
  _FakeSecureStorage storage, {
  required String access,
  required String refresh,
  required DateTime expiry,
}) async {
  await storage.write(key: 'onedrive_access_token', value: access);
  await storage.write(key: 'onedrive_refresh_token', value: refresh);
  await storage.write(
    key: 'onedrive_token_expiry',
    value: expiry.toUtc().toIso8601String(),
  );
}

/// In-memory `FlutterSecureStorage` so tests don't touch platform channels.
/// Mirrors the existing `test/helpers/mock_token_storage.dart` pattern but
/// targets `FlutterSecureStorage` directly because `OneDriveAuth` owns its
/// own storage handle (not the project's wider `TokenStorage` abstraction).
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage() : super();
  final Map<String, String?> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}
