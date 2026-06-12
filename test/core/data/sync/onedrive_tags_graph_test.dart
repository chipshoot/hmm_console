import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late _FakeOneDriveAuth auth;

  setUp(() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
    auth = _FakeOneDriveAuth();
  });

  OneDriveGraphClient client() =>
      OneDriveGraphClient(auth, () async => 'SUB-1', dio: dio);

  test('getTags returns the decoded body on 200', () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/tags.json:/content',
      (server) => server.reply(200, {
        'version': 1,
        'tags': [
          {'name': 'work', 'last_modified': '2026-05-01T00:00:00Z',
           'deleted': false}
        ],
      }),
    );
    final doc = await client().getTags();
    expect(doc, isNotNull);
    expect((doc!['tags'] as List).length, 1);
  });

  test('getTags returns null when tags.json is absent (404)', () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/tags.json:/content',
      (server) => server.reply(404, null),
    );
    expect(await client().getTags(), isNull);
  });

  test('putTags PUTs the document to the user-scoped tags.json', () async {
    Map<String, dynamic>? captured;
    adapter.onPut(
      '/me/drive/special/approot:/users/SUB-1/tags.json:/content',
      (server) => server.reply(200, {'ok': true}),
      data: Matchers.any,
    );
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'PUT' &&
          options.path.endsWith('tags.json:/content') &&
          options.data is Map) {
        captured = options.data as Map<String, dynamic>;
      }
      handler.next(options);
    }));

    await client().putTags({'version': 1, 'tags': const []});
    expect(captured, isNotNull);
    expect(captured!['version'], 1);
  });
}

/// Bypasses the real OneDriveAuth — tests don't need actual MS tokens; the
/// graph client only cares that getAccessToken() returns SOMETHING so its
/// auth interceptor doesn't reject the request. Subclassing rather than
/// implementing avoids having to fake the (large) constructor surface.
class _FakeOneDriveAuth extends OneDriveAuth {
  _FakeOneDriveAuth() : super(storage: _NoopSecureStorage());

  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<bool> hasToken() async => true;
}

/// In-memory FlutterSecureStorage so the parent OneDriveAuth constructor's
/// default Keychain calls don't fire under `flutter test`.
class _NoopSecureStorage extends FlutterSecureStorage {
  _NoopSecureStorage() : super();
  final _data = <String, String?>{};

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
    _data[key] = value;
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
