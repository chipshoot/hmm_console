import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:hmm_console/core/data/sync/onedrive_sync_provider.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/core/network/token_storage.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Coverage for the one-time legacy-data migration introduced in Phase A.
/// Drives [OneDriveSyncProvider.migrateLegacyIfNeeded] through every
/// branch — marker present (skip), no legacy data (mark + return),
/// legacy data present (copy + mark), per-user manifest already exists
/// (don't clobber).
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late OneDriveGraphClient graph;
  late OneDriveSyncProvider provider;
  late _FakeIdpTokenService tokenService;

  setUp(() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
    tokenService = _FakeIdpTokenService(sub: 'USER-A');
    graph = OneDriveGraphClient(
      _FakeOneDriveAuth(),
      () async => tokenService.subFromClaims(),
      dio: dio,
    );
    provider = OneDriveSyncProvider(
      _FakeOneDriveAuth(),
      graph,
      tokenService,
    );
  });

  test('returns 0 and does nothing when migration marker already exists',
      () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
      (server) => server.reply(200, {
        'migrated_at': '2026-05-01T00:00:00.000Z',
        'for_sub': 'PREVIOUSLY-MIGRATED',
        'copied_note_count': 12,
      }),
    );
    // No other stubs — if migration reaches any other endpoint the test
    // fails with "Could not find mocked route".

    final copied = await provider.migrateLegacyIfNeeded();
    expect(copied, equals(0));
  });

  test('returns 0 when no Hmm user is signed in (skip without writing marker)',
      () async {
    tokenService.sub = null;

    adapter.onGet(
      '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
      (server) => server.reply(404, null),
    );
    // No marker-WRITE stub: confirms migration doesn't write a marker
    // when sub is null (a later signed-in attempt must still get to
    // migrate).

    final copied = await provider.migrateLegacyIfNeeded();
    expect(copied, equals(0));
  });

  test('returns 0 + writes marker when no legacy data exists', () async {
    adapter
      ..onGet(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(404, null),
      )
      ..onGet(
        '/me/drive/special/approot:/manifest.json:/content',
        (server) => server.reply(404, null),
      )
      ..onPut(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      );

    final copied = await provider.migrateLegacyIfNeeded();
    expect(copied, equals(0));
  });

  test('copies all non-deleted legacy notes + manifest into user subtree',
      () async {
    final legacyManifestBody = {
      'version': 1,
      'generated_at': '2026-05-01T00:00:00.000Z',
      'device_id': 'legacy-device',
      'notes': [
        {
          'id': 'n-1',
          'updated_at': '2026-05-01T00:00:00.000Z',
          'deleted': false,
        },
        {
          'id': 'n-2',
          'updated_at': '2026-05-02T00:00:00.000Z',
          'deleted': false,
        },
        {
          // Deleted entries have no body file in the legacy layout — we
          // must not GET them and we must not copy them.
          'id': 'n-3',
          'updated_at': '2026-05-03T00:00:00.000Z',
          'deleted': true,
        },
      ],
      'attachments': [],
    };

    adapter
      ..onGet(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(404, null),
      )
      ..onGet(
        '/me/drive/special/approot:/manifest.json:/content',
        (server) => server.reply(200, legacyManifestBody),
      )
      ..onGet(
        '/me/drive/special/approot:/notes/n-1.json:/content',
        (server) => server.reply(200, {'body': 'note-1'}),
      )
      ..onGet(
        '/me/drive/special/approot:/notes/n-2.json:/content',
        (server) => server.reply(200, {'body': 'note-2'}),
      )
      ..onPut(
        '/me/drive/special/approot:/users/USER-A/notes/n-1.json:/content',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      )
      ..onPut(
        '/me/drive/special/approot:/users/USER-A/notes/n-2.json:/content',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      )
      ..onGet(
        // Per-user manifest check before copying — returns 404, so we
        // copy the legacy manifest into the user subtree.
        '/me/drive/special/approot:/users/USER-A/manifest.json:/content',
        (server) => server.reply(404, null),
      )
      ..onPut(
        '/me/drive/special/approot:/users/USER-A/manifest.json:/content',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      )
      ..onPut(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      );

    final copied = await provider.migrateLegacyIfNeeded();
    expect(copied, equals(2),
        reason: 'n-3 is deleted, so only n-1 + n-2 should be copied');
  });

  test('preserves existing per-user manifest (does NOT clobber it)',
      () async {
    // Scenario: User-A has been syncing from another device already
    // (their per-user manifest exists at users/USER-A/manifest.json).
    // Now they install this device — the legacy migration runs on first
    // sync, but it must NOT overwrite the per-user manifest with the
    // legacy one (which would erase their cross-device sync state).
    final legacyManifestBody = {
      'version': 1,
      'generated_at': '2026-05-01T00:00:00.000Z',
      'device_id': 'legacy-device',
      'notes': [
        {
          'id': 'n-1',
          'updated_at': '2026-05-01T00:00:00.000Z',
          'deleted': false,
        },
      ],
      'attachments': [],
    };

    var perUserManifestPutHits = 0;

    adapter
      ..onGet(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(404, null),
      )
      ..onGet(
        '/me/drive/special/approot:/manifest.json:/content',
        (server) => server.reply(200, legacyManifestBody),
      )
      ..onGet(
        '/me/drive/special/approot:/notes/n-1.json:/content',
        (server) => server.reply(200, {'body': 'note-1'}),
      )
      ..onPut(
        '/me/drive/special/approot:/users/USER-A/notes/n-1.json:/content',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      )
      ..onGet(
        // Per-user manifest ALREADY exists — migration must skip the
        // manifest write.
        '/me/drive/special/approot:/users/USER-A/manifest.json:/content',
        (server) => server.reply(200, {
          'version': 1,
          'generated_at': '2026-05-10T00:00:00.000Z',
          'device_id': 'other-device',
          'notes': [],
          'attachments': [],
        }),
      )
      ..onPut(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      );

    // Tripwire: any PUT to users/USER-A/manifest.json fails the test.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'PUT' &&
          options.path.contains('users/USER-A/manifest.json')) {
        perUserManifestPutHits++;
      }
      handler.next(options);
    }));

    final copied = await provider.migrateLegacyIfNeeded();
    expect(copied, equals(1));
    expect(perUserManifestPutHits, equals(0),
        reason: 'must not overwrite the existing per-user manifest');
  });
}

/// FakeIdpTokenService that only implements what migration needs:
/// `getStoredClaims()` returning `{'sub': sub}` or null when `sub` is null.
class _FakeIdpTokenService implements IdpTokenService {
  _FakeIdpTokenService({this.sub});
  String? sub;

  String? subFromClaims() => sub;

  @override
  Future<Map<String, dynamic>?> getStoredClaims() async {
    if (sub == null) return null;
    return {'sub': sub!};
  }

  // Everything else is unused for the migration code path.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  TokenStorage get tokenStorage =>
      throw UnimplementedError('not used in migration tests');

  @override
  Future<void> clearTokens() async {}

  @override
  Future<String> getValidAccessToken() async => 'test-token';

  @override
  Future<void> refreshAccessToken() async {}
}

/// Same fake as the path test — graph client only needs SOME bearer token
/// to slip past its own auth interceptor.
class _FakeOneDriveAuth extends OneDriveAuth {
  _FakeOneDriveAuth() : super(storage: _NoopSecureStorage());

  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<bool> hasToken() async => true;
}

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
