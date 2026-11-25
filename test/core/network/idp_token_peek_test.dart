import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  late MockTokenStorage storage;
  late IdpTokenService service;

  setUp(() {
    storage = MockTokenStorage();
    final dio = Dio();
    // No routes: any network call fails the test.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          fail('unexpected network call to ${o.uri}');
        },
      ),
    );
    service = IdpTokenService(tokenStorage: storage, config: _config, dio: dio);
  });

  test('peekStoredSub decodes an expired token without refreshing', () async {
    final past = DateTime.now().subtract(const Duration(hours: 2));
    await storage.saveTokens(
      accessToken: _jwt({
        'sub': 'S1',
        'email': 'e@x.y',
        'exp': past.millisecondsSinceEpoch ~/ 1000,
      }),
      refreshToken: 'r',
      expiry: past,
    );
    expect(await service.peekStoredSub(), 'S1');
    expect(await service.peekStoredEmail(), 'e@x.y');
  });

  test('peek returns null with no token', () async {
    expect(await service.peekStoredSub(), isNull);
    expect(await service.peekStoredEmail(), isNull);
  });

  test('peek returns null when the claim is missing', () async {
    await storage.saveTokens(
      accessToken: _jwt({'name': 'x'}),
      refreshToken: 'r',
      expiry: DateTime.now(),
    );
    expect(await service.peekStoredSub(), isNull);
  });

  test('an undecodable token reads as no token (it never becomes '
      'decodable)', () async {
    await storage.saveTokens(
      accessToken: 'garbage',
      refreshToken: 'r',
      expiry: DateTime.now(),
    );
    expect(await service.peekStoredSub(), isNull);
    expect(await service.peekStoredEmail(), isNull);
  });

  test(
    'a token whose payload is not a JSON object reads as no token',
    () async {
      await storage.saveTokens(
        accessToken: 'a.${base64Url.encode(utf8.encode('[1]'))}.c',
        refreshToken: 'r',
        expiry: DateTime.now(),
      );
      expect(await service.peekStoredSub(), isNull);
    },
  );

  test('a storage read failure throws TokenPeekException', () async {
    final broken = IdpTokenService(
      tokenStorage: _ThrowingStorage(),
      config: _config,
      dio: Dio(),
    );
    await expectLater(
      broken.peekStoredSub(),
      throwsA(isA<TokenPeekException>()),
    );
  });

  test('hasHmmSession true only with a refresh token', () async {
    expect(await service.hasHmmSession(), isFalse);
    await storage.saveTokens(
      accessToken: _jwt({'sub': 'S'}),
      refreshToken: 'r',
      expiry: DateTime.now(),
    );
    expect(await service.hasHmmSession(), isTrue);
    await storage.clearTokens();
    expect(await service.hasHmmSession(), isFalse);
  });
}

class _ThrowingStorage extends MockTokenStorage {
  @override
  Future<String?> getAccessToken() async =>
      throw Exception('keychain unavailable');
}
