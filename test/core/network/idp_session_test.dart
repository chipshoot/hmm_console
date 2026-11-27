// A registered user's Hmm session must survive an expired access token
// (refresh it), survive being offline (keep it), and end cleanly only when
// the IdP refuses the refresh token — clearing the stored tokens, recording
// that the session expired, and telling listeners.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/exceptions/app_exceptions.dart';
import 'package:hmm_console/core/network/idp_config.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';

import '../../helpers/mock_token_storage.dart';

String _jwt(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'none'})}.${seg(claims)}.sig';
}

const _config = IdpConfig(
  authority: 'https://idp.test',
  clientId: 'hmm.mobile',
  clientSecret: '',
  scopes: 'openid',
);

/// How the fake IdP answers a refresh_token grant.
enum _Idp { ok, rejected, offline, serverError, slow }

void main() {
  late MockTokenStorage storage;
  late Dio dio;
  late _Idp idp;
  late int refreshCalls;
  Future<void> Function()? duringRefresh;

  setUp(() {
    storage = MockTokenStorage();
    idp = _Idp.ok;
    refreshCalls = 0;
    duringRefresh = null;
    dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      final data = o.data;
      if (data is! Map || data['grant_type'] != 'refresh_token') {
        h.reject(DioException(requestOptions: o, message: 'unexpected'));
        return;
      }
      refreshCalls++;
      await duringRefresh?.call();
      switch (idp) {
        case _Idp.ok:
          await Future<void>.delayed(const Duration(milliseconds: 10));
          h.resolve(Response(requestOptions: o, statusCode: 200, data: {
            'access_token': _jwt({'sub': 'user-42', 'email': 'me@x.com'}),
            'refresh_token': 'refresh-2',
            'expires_in': 3600,
          }));
        case _Idp.rejected:
          h.reject(DioException(
            requestOptions: o,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: o,
              statusCode: 400,
              data: {'error': 'invalid_grant'},
            ),
          ));
        case _Idp.offline:
          h.reject(DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ));
        case _Idp.serverError:
          h.reject(DioException(
            requestOptions: o,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: o, statusCode: 503),
          ));
        case _Idp.slow:
          await Future<void>.delayed(const Duration(seconds: 1));
          h.reject(DioException(
            requestOptions: o,
            type: DioExceptionType.connectionTimeout,
          ));
      }
    }));
  });

  IdpTokenService service() =>
      IdpTokenService(tokenStorage: storage, config: _config, dio: dio);

  Future<void> seedExpired() => storage.saveTokens(
        accessToken: _jwt({'sub': 'user-42', 'email': 'me@x.com'}),
        refreshToken: 'refresh-1',
        expiry: DateTime.now().subtract(const Duration(minutes: 5)),
      );

  group('checkSession', () {
    test('a valid access token is signed in without calling the IdP',
        () async {
      await storage.saveTokens(
        accessToken: _jwt({'sub': 'user-42'}),
        refreshToken: 'refresh-1',
        expiry: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(await service().checkSession(), SessionCheck.signedIn);
      expect(refreshCalls, 0);
    });

    test('an expired access token is refreshed, not sent to login', () async {
      await seedExpired();
      expect(await service().checkSession(), SessionCheck.signedIn);
      expect(refreshCalls, 1);
      expect(await storage.getRefreshToken(), 'refresh-2');
    });

    test('no stored session is signed out and not marked expired', () async {
      expect(await service().checkSession(), SessionCheck.signedOut);
      expect(await storage.getExpiredSession(), isNull);
    });

    test('offline keeps the session and lets the user in', () async {
      await seedExpired();
      idp = _Idp.offline;
      expect(await service().checkSession(), SessionCheck.offline);
      expect(await storage.getRefreshToken(), 'refresh-1');
      expect(await storage.getExpiredSession(), isNull);
    });

    test('an IdP server error keeps the session', () async {
      await seedExpired();
      idp = _Idp.serverError;
      expect(await service().checkSession(), SessionCheck.offline);
      expect(await storage.getRefreshToken(), 'refresh-1');
    });

    test('a slow IdP times out as offline', () async {
      await seedExpired();
      idp = _Idp.slow;
      expect(
        await service().checkSession(
          timeout: const Duration(milliseconds: 50),
        ),
        SessionCheck.offline,
      );
      expect(await storage.getRefreshToken(), 'refresh-1');
    });

    test('a refused refresh token ends the session', () async {
      await seedExpired();
      idp = _Idp.rejected;
      final s = service();
      final ended = expectLater(s.sessionEnded, emits(anything));
      expect(await s.checkSession(), SessionCheck.signedOut);
      await ended;
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getExpiredSession(), 'me@x.com');
    });
  });

  group('refreshAccessToken', () {
    test('concurrent refreshes share one IdP call', () async {
      await seedExpired();
      final s = service();
      await Future.wait([
        s.refreshAccessToken(),
        s.refreshAccessToken(),
        s.getValidAccessToken(),
      ]);
      expect(refreshCalls, 1);
    });

    test('offline throws an AuthTokenException and keeps the tokens',
        () async {
      await seedExpired();
      idp = _Idp.offline;
      await expectLater(
        service().refreshAccessToken(),
        throwsA(isA<AuthTokenException>()),
      );
      expect(await storage.getRefreshToken(), 'refresh-1');
    });

    test('a refusal after the token was already rotated keeps the session',
        () async {
      await seedExpired();
      idp = _Idp.rejected;
      // Another refresh stored a new pair while this request was in flight.
      duringRefresh = () => storage.saveTokens(
            accessToken: _jwt({'sub': 'user-42'}),
            refreshToken: 'refresh-rotated',
            expiry: DateTime.now().add(const Duration(hours: 1)),
          );
      await service().refreshAccessToken();
      expect(await storage.getRefreshToken(), 'refresh-rotated');
      expect(await storage.getExpiredSession(), isNull);
    });

    test('getStoredClaims stays null (no throw) when offline', () async {
      await seedExpired();
      idp = _Idp.offline;
      expect(await service().getStoredClaims(), isNull);
    });
  });

  group('expired flag', () {
    test('signing in again clears it', () async {
      await storage.markSessionExpired('me@x.com');
      await storage.saveTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiry: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(await storage.getExpiredSession(), isNull);
    });

    test('a deliberate sign-out clears it', () async {
      await storage.markSessionExpired('me@x.com');
      await service().clearTokens();
      expect(await storage.getExpiredSession(), isNull);
    });

    test('dismissExpiredSession clears it and notifies', () async {
      await storage.markSessionExpired('me@x.com');
      final s = service();
      final changed = expectLater(s.sessionChanges, emits(anything));
      await s.dismissExpiredSession();
      await changed;
      expect(await storage.getExpiredSession(), isNull);
    });
  });
}
