import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_auth.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
// ignore: depend_on_referenced_packages — flutter is transitively present.

/// Coverage for the per-user OneDrive path scoping introduced in
/// Phase A of the cloud-sync improvements. Every endpoint must include
/// `/users/{encoded-sub}/` between the approot selector and the
/// resource name; legacy access methods read the unscoped paths only.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late _FakeOneDriveAuth auth;

  setUp(() {
    // Mirror the production graph client's `validateStatus: (_) => true` so
    // 404s come through as Response objects (the production code branches
    // on status manually). Default Dio throws on 4xx, which would break
    // every "missing-file returns null" test in this file.
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
    auth = _FakeOneDriveAuth();
  });

  OneDriveGraphClient buildClient({String? sub = 'SUB-1'}) {
    return OneDriveGraphClient(
      auth,
      () async => sub,
      dio: dio,
    );
  }

  group('user-scoped paths', () {
    test('getManifest hits approot/users/{sub}/manifest.json', () async {
      adapter.onGet(
        '/me/drive/special/approot:/users/SUB-1/manifest.json:/content',
        (server) => server.reply(404, null),
      );
      final client = buildClient(sub: 'SUB-1');

      final manifest = await client.getManifest();
      expect(manifest, isNull); // 404 → null, as per the production contract.
    });

    test('putManifest, getNoteBlob, putNoteBlob, deleteNoteBlob all scope',
        () async {
      final manifest = SyncManifest(
        version: 1,
        generatedAt: DateTime.utc(2026, 5, 24),
        deviceId: 'test-dev',
        notes: const [],
        attachments: const [],
      );

      adapter
        ..onPut(
          '/me/drive/special/approot:/users/SUB-2/manifest.json:/content',
          (server) => server.reply(200, {'ok': true}),
          data: Matchers.any,
        )
        ..onGet(
          '/me/drive/special/approot:/users/SUB-2/notes/n-1.json:/content',
          (server) => server.reply(200, {'body': 'note-1'}),
        )
        ..onPut(
          '/me/drive/special/approot:/users/SUB-2/notes/n-1.json:/content',
          (server) => server.reply(200, {'ok': true}),
          data: Matchers.any,
        )
        ..onDelete(
          '/me/drive/special/approot:/users/SUB-2/notes/n-1.json',
          (server) => server.reply(204, null),
        );

      final client = buildClient(sub: 'SUB-2');
      await client.putManifest(manifest);
      final blob = await client.getNoteBlob('n-1');
      expect(blob, equals({'body': 'note-1'}));
      await client.putNoteBlob('n-1', {'body': 'note-1'});
      await client.deleteNoteBlob('n-1');
      // If any path were wrong, http_mock_adapter would have returned a
      // synthetic null and the assertions above would fail.
    });

    test('special characters in sub are URL-encoded into the path', () async {
      // Hypothetical future IDP sub with a slash would be catastrophic
      // (path traversal) if not encoded. Encode + match the encoded
      // form.
      adapter.onGet(
        '/me/drive/special/approot:/users/'
        'sub%2Fwith%2Fslash/manifest.json:/content',
        (server) => server.reply(404, null),
      );

      final client = buildClient(sub: 'sub/with/slash');
      final manifest = await client.getManifest();
      expect(manifest, isNull);
    });

    test('missing sub throws OneDriveGraphException(401) on every endpoint',
        () async {
      final client = buildClient(sub: null);

      await expectLater(
        client.getManifest(),
        throwsA(isA<OneDriveGraphException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );

      await expectLater(
        client.putNoteBlob('n-1', {'body': 'x'}),
        throwsA(isA<OneDriveGraphException>().having(
          (e) => e.message,
          'message',
          contains('no authenticated Hmm user'),
        )),
      );

      await expectLater(
        client.deleteNoteBlob('n-1'),
        throwsA(isA<OneDriveGraphException>()),
      );
    });

    test('empty-string sub is treated the same as null', () async {
      final client = buildClient(sub: '');
      await expectLater(
        client.getManifest(),
        throwsA(isA<OneDriveGraphException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );
    });
  });

  group('legacy access methods (used only by migration)', () {
    test('getLegacyManifest reads approot/manifest.json (unscoped)', () async {
      adapter.onGet(
        '/me/drive/special/approot:/manifest.json:/content',
        (server) => server.reply(200, {
          'version': 1,
          'generated_at': '2026-05-01T00:00:00.000Z',
          'device_id': 'legacy-device',
          'notes': [],
          'attachments': [],
        }),
      );

      final client = buildClient(sub: 'SUB-1');
      final m = await client.getLegacyManifest();
      expect(m, isNotNull);
      expect(m!.deviceId, equals('legacy-device'));
    });

    test('getLegacyNoteBlob reads approot/notes/{id}.json (unscoped)',
        () async {
      adapter.onGet(
        '/me/drive/special/approot:/notes/legacy-1.json:/content',
        (server) => server.reply(200, {'body': 'legacy'}),
      );

      final client = buildClient(sub: 'SUB-1');
      final blob = await client.getLegacyNoteBlob('legacy-1');
      expect(blob, equals({'body': 'legacy'}));
    });

    test('legacy methods work even when sub is missing (no user context yet)',
        () async {
      // We must be able to PROBE for legacy data before we know which
      // user gets to claim it. Migration logic in OneDriveSyncProvider
      // checks sub itself; the graph client's legacy methods don't.
      adapter.onGet(
        '/me/drive/special/approot:/manifest.json:/content',
        (server) => server.reply(404, null),
      );

      final client = buildClient(sub: null);
      final m = await client.getLegacyManifest();
      expect(m, isNull);
    });
  });

  group('legacy-migration marker', () {
    test('hasLegacyMigrationMarker returns false on 404', () async {
      adapter.onGet(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(404, null),
      );
      final client = buildClient();
      expect(await client.hasLegacyMigrationMarker(), isFalse);
    });

    test('hasLegacyMigrationMarker returns true on 200', () async {
      adapter.onGet(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(200, {
          'migrated_at': '2026-05-24T00:00:00.000Z',
          'for_sub': 'SUB-1',
          'copied_note_count': 7,
          '_v': 1,
        }),
      );
      final client = buildClient();
      expect(await client.hasLegacyMigrationMarker(), isTrue);
    });

    test('writeLegacyMigrationMarker PUTs the audit JSON', () async {
      Map<String, dynamic>? capturedBody;
      adapter.onPut(
        '/me/drive/special/approot:/users/.legacy_migrated.json:/content',
        (server) => server.reply(201, {'ok': true}),
        data: Matchers.any,
      );
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (options.method == 'PUT' &&
            options.path.endsWith('.legacy_migrated.json:/content') &&
            options.data is Map) {
          capturedBody = options.data as Map<String, dynamic>;
        }
        handler.next(options);
      }));

      final client = buildClient();
      await client.writeLegacyMigrationMarker(
        forSub: 'SUB-1',
        copiedNoteCount: 3,
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['for_sub'], equals('SUB-1'));
      expect(capturedBody!['copied_note_count'], equals(3));
      expect(capturedBody!['migrated_at'], isNotEmpty);
      expect(capturedBody!['_v'], equals(1));
    });
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
