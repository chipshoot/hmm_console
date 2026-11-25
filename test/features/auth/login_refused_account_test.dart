import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/network/idp_config.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/core/network/token_storage.dart';
import 'package:hmm_console/features/auth/data/data.dart';
import 'package:hmm_console/features/auth/states/login_state.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_token_storage.dart';

String _jwt(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'none'})}.${seg(claims)}.sig';
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.sub);
  final String sub;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'access_token': _jwt({'sub': sub, 'email': '$sub@x.com'}),
      'refresh_token': 'r',
      'expires_in': 3600,
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _FixedMode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.cloudApi;
  @override
  Future<void> setMode(DataMode mode) async => state = mode;
}

Future<(MockTokenStorage, List<bool>, ProviderContainer)> _login(
  String linkedSub,
) async {
  SharedPreferences.setMockInitialValues({
    'hmm.linkedHmmSub': linkedSub,
    'hmm.linkedHmmEmail': 'z@x.com',
  });
  final storage = MockTokenStorage();
  final dio = Dio()..httpClientAdapter = _Adapter('sub-b');
  final service = IdpTokenService(
    tokenStorage: storage,
    config: const IdpConfig(
      authority: 'https://idp.test',
      clientId: 'c',
      clientSecret: '',
      scopes: 'openid',
    ),
    dio: dio,
  );
  final db = HmmDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final c = ProviderContainer(
    overrides: [
      hmmDatabaseProvider.overrideWithValue(db),
      idpTokenServiceProvider.overrideWithValue(service),
      tokenStorageProvider.overrideWithValue(storage),
      dataModeProvider.overrideWith(() => _FixedMode()),
    ],
  );
  addTearDown(c.dispose);

  final emitted = <bool>[];
  final sub = c
      .read(authRepositoryProvider)
      .isUserAuthenticated()
      .listen(emitted.add);
  addTearDown(sub.cancel);

  await c.read(loginStateProvider.notifier).loginWithEmailPassword('b', 'p');
  await Future<void>.delayed(Duration.zero);

  return (storage, emitted, c);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a refused account stores no tokens and emits no true', () async {
    final (storage, emitted, c) = await _login('sub-z');
    expect(c.read(loginStateProvider).error, isA<OtherHmmAccountException>());
    expect(await storage.getAccessToken(), isNull);
    expect(emitted, isNot(contains(true)));
  });

  test('the linked account stores tokens and emits true', () async {
    final (storage, emitted, c) = await _login('sub-b');
    expect(c.read(loginStateProvider).value, isTrue);
    expect(await storage.getAccessToken(), isNotNull);
    expect(emitted, contains(true));
  });
}
