// Reported: after a restart, OneDrive sync failed with "no authenticated Hmm
// user (sub claim missing)" even though the user was signed in.
//
// The sync sub-resolver calls getStoredClaims(), which gave up the moment
// the access token was past its lifetime — it never tried the refresh token
// sitting right beside it. getValidAccessToken() DID refresh, but nobody on
// the sync path called it. So an app restart with an expired access token
// reported "nobody signed in" to a user who was.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/idp_config.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';

import '../../helpers/mock_token_storage.dart';

/// An unsigned JWT whose payload carries [claims]. The service only decodes
/// the payload, so the signature segment can be anything.
String jwtWith(Map<String, dynamic> claims) {
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

void main() {
  late MockTokenStorage storage;
  late Dio dio;
  var refreshCalls = 0;

  setUp(() {
    storage = MockTokenStorage();
    refreshCalls = 0;
    dio = Dio();
    // Stand in for the IdP: answer a refresh_token grant with a fresh token.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      final data = o.data;
      if (data is Map && data['grant_type'] == 'refresh_token') {
        refreshCalls++;
        h.resolve(Response(
          requestOptions: o,
          statusCode: 200,
          data: {
            'access_token': jwtWith({'sub': 'user-42'}),
            'refresh_token': 'refresh-2',
            'expires_in': 3600,
          },
        ));
        return;
      }
      h.reject(DioException(requestOptions: o, message: 'unexpected request'));
    }));
  });

  IdpTokenService service() =>
      IdpTokenService(tokenStorage: storage, config: _config, dio: dio);

  test('an EXPIRED access token with a refresh token still yields claims',
      () async {
    await storage.saveTokens(
      accessToken: jwtWith({'sub': 'user-42'}),
      refreshToken: 'refresh-1',
      expiry: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    final claims = await service().getStoredClaims();

    expect(claims?['sub'], 'user-42',
        reason: 'a refresh token was available and must be used');
    expect(refreshCalls, 1);
  });

  test('a still-valid token is used as-is, without a refresh round-trip',
      () async {
    await storage.saveTokens(
      accessToken: jwtWith({'sub': 'user-42'}),
      refreshToken: 'refresh-1',
      expiry: DateTime.now().add(const Duration(hours: 1)),
    );

    final claims = await service().getStoredClaims();

    expect(claims?['sub'], 'user-42');
    expect(refreshCalls, 0, reason: 'no need to refresh a valid token');
  });

  test('with NO tokens at all it returns null, not a throw', () async {
    // Genuinely signed out. The sync path reads null as "no user", which is
    // the right answer here — it must not become an exception.
    expect(await service().getStoredClaims(), isNull);
    expect(refreshCalls, 0);
  });

  test('an expired token whose refresh FAILS returns null, not a throw',
      () async {
    dio.interceptors.clear();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) => h.resolve(
        Response(requestOptions: o, statusCode: 400, data: {'error': 'x'}))));
    await storage.saveTokens(
      accessToken: jwtWith({'sub': 'user-42'}),
      refreshToken: 'refresh-dead',
      expiry: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    // The refresh token was revoked server-side: now the user really is
    // signed out, and null is the honest answer.
    expect(await service().getStoredClaims(), isNull);
  });
}
