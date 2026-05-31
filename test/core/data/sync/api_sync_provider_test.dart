import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/api_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_models.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Coverage for the real ApiSyncProvider — auth gating, paginated
/// manifest pull, by-uuid pull, the create / update / delete branch
/// in pushNoteBody, and the catalog-name → id translation.
///
/// The IdpTokenService dependency is swapped for a fake to keep the
/// tests free of real token storage / IdP round-trips.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late _FakeIdpTokenService tokenService;
  late ApiSyncProvider provider;

  setUp(() {
    // Bare baseUrl matches the ApiVaultStore test convention — keeps
    // http_mock_adapter's relative-path matching aligned with the
    // leading-slash routes the provider emits.
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    tokenService = _FakeIdpTokenService();
    provider = ApiSyncProvider(
      client: ApiClient(dio),
      tokenService: tokenService,
    );
  });

  // ============================================================
  // Auth
  // ============================================================

  group('auth', () {
    test('isAuthenticated true when token storage has claims', () async {
      tokenService.claims = {'sub': 'user-1'};

      expect(await provider.isAuthenticated(), isTrue);
    });

    test('isAuthenticated false when no claims', () async {
      tokenService.claims = null;

      expect(await provider.isAuthenticated(), isFalse);
    });

    test('signIn throws UnsupportedError pointing at the IdP login flow',
        () async {
      // ApiSyncProvider.signIn is a non-async function that throws
      // synchronously — wrap the call so the matcher catches the
      // throw before it becomes a Future.error.
      expect(() => provider.signIn(), throwsUnsupportedError);
    });

    test('signOut is a no-op (does not clear app-wide tokens)', () async {
      tokenService.claims = {'sub': 'user-1'};

      await provider.signOut();

      expect(tokenService.cleared, isFalse);
    });
  });

  // ============================================================
  // pullManifest
  // ============================================================

  group('pullManifest', () {
    Map<String, List<String>> paginationHeader({
      required int currentPage,
      required int totalPages,
      int totalCount = 1,
    }) {
      // http_mock_adapter v0.6.1 requires Content-Type alongside
      // any custom response header — it stumbles parsing the body
      // without it (and the gas_log tests do the same dance).
      return {
        Headers.contentTypeHeader: ['application/json'],
        'x-pagination': [
          jsonEncode({
            'totalCount': totalCount,
            'pageSize': 100,
            'currentPage': currentPage,
            'totalPages': totalPages,
            'maxPageSize': 100,
          }),
        ],
      };
    }

    test('returns null when server has no notes', () async {
      adapter.onGet(
        '/notes',
        (server) => server.reply(200, {'value': []},
            headers: paginationHeader(
                currentPage: 1, totalPages: 1, totalCount: 0)),
      );

      final manifest = await provider.pullManifest();

      // Empty cloud namespace — same shape OneDriveSyncProvider
      // returns on a fresh remote.
      expect(manifest, isNull);
    });

    test('builds entries from every page when paginated', () async {
      // http_mock_adapter doesn't sequence two same-path setups
      // FIFO — second call overwrites the first. Distinguish the
      // pages by the PageNumber query parameter Dio actually sends.
      adapter.onGet(
        '/notes',
        (server) => server.reply(200, {
          'value': [
            {
              'uuid': 'u-1',
              'isDeleted': false,
              'lastModifiedDate': '2026-05-18T10:00:00Z',
            },
            {
              'uuid': 'u-2',
              'isDeleted': true,
              'lastModifiedDate': '2026-05-18T11:00:00Z',
            },
          ],
        }, headers: paginationHeader(currentPage: 1, totalPages: 2)),
        queryParameters: <String, dynamic>{
          'includeDeleted': true,
          'PageNumber': 1,
          'PageSize': 100,
        },
      );
      adapter.onGet(
        '/notes',
        (server) => server.reply(200, {
          'value': [
            {
              'uuid': 'u-3',
              'isDeleted': false,
              'lastModifiedDate': '2026-05-18T12:00:00Z',
            },
          ],
        }, headers: paginationHeader(currentPage: 2, totalPages: 2)),
        queryParameters: <String, dynamic>{
          'includeDeleted': true,
          'PageNumber': 2,
          'PageSize': 100,
        },
      );

      final manifest = await provider.pullManifest();

      expect(manifest, isNotNull);
      expect(manifest!.notes.map((e) => e.id), ['u-1', 'u-2', 'u-3']);
      expect(manifest.notes[1].deleted, isTrue);
    });

    test('skips entries that lack a uuid (legacy server rows)', () async {
      adapter.onGet(
        '/notes',
        (server) => server.reply(200, {
          'value': [
            {
              // No uuid — pre-Phase-15b row not yet backfilled.
              'isDeleted': false,
              'lastModifiedDate': '2026-05-18T10:00:00Z',
            },
            {
              'uuid': 'has-uuid',
              'isDeleted': false,
              'lastModifiedDate': '2026-05-18T11:00:00Z',
            },
          ],
        }, headers: paginationHeader(currentPage: 1, totalPages: 1)),
      );

      final manifest = await provider.pullManifest();

      expect(manifest!.notes.map((e) => e.id), ['has-uuid']);
    });
  });

  // ============================================================
  // pullNoteBody
  // ============================================================

  group('pullNoteBody', () {
    test('translates ApiNote → orchestrator body shape', () async {
      adapter.onGet(
        '/notes/by-uuid/abc',
        (server) => server.reply(200, {
          'id': 7,
          'uuid': 'abc',
          'subject': 'hello',
          'content': 'world',
          'catalogName': 'GasLog',
          'description': 'd',
          'createDate': '2026-05-18T10:00:00Z',
          'lastModifiedDate': '2026-05-18T11:00:00Z',
          'isDeleted': false,
        }),
      );

      final body = await provider.pullNoteBody('abc');

      expect(body, isNotNull);
      expect(body!['uuid'], 'abc');
      expect(body['subject'], 'hello');
      expect(body['content'], 'world');
      expect(body['catalogName'], 'GasLog');
      expect(body['parentNoteUuid'], isNull); // server doesn't model it
      expect(body['deletedAt'], isNull);
    });

    test('IsDeleted=true on the server surfaces deletedAt on the body',
        () async {
      adapter.onGet(
        '/notes/by-uuid/abc',
        (server) => server.reply(200, {
          'uuid': 'abc',
          'subject': 's',
          'content': 'c',
          'catalogName': 'GasLog',
          'lastModifiedDate': '2026-05-18T11:00:00Z',
          'isDeleted': true,
        }),
      );

      final body = await provider.pullNoteBody('abc');

      expect(body!['deletedAt'], '2026-05-18T11:00:00Z');
    });

    test('404 returns null', () async {
      adapter.onGet(
        '/notes/by-uuid/missing',
        (server) => server.reply(404, {'detail': 'not found'}),
      );

      final body = await provider.pullNoteBody('missing');

      expect(body, isNull);
    });

    test('empty uuid returns null without hitting the wire', () async {
      // No matcher set up — if the provider made a request we'd
      // get a DioException; assertion is just that no call fires.
      final body = await provider.pullNoteBody('');

      expect(body, isNull);
    });
  });

  // ============================================================
  // pushNoteBody
  // ============================================================

  group('pushNoteBody', () {
    test('POSTs when the server has no matching uuid', () async {
      adapter.onGet(
        '/notes/by-uuid/new',
        (server) => server.reply(404, {'detail': 'not found'}),
      );
      adapter.onGet(
        '/authors',
        (server) => server.reply(200, {
          'value': [
            {'id': 3, 'accountName': 'me'},
          ],
        }),
      );
      adapter.onGet(
        '/notecatalogs',
        (server) => server.reply(200, {
          'value': [
            {'id': 7, 'name': 'GasLog'},
          ],
        }),
      );
      Map<String, dynamic>? capturedBody;
      adapter.onPost(
        '/notes',
        (server) => server.reply(201, {'id': 99, 'uuid': 'new'}),
        data: Matchers.any,
      );
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST') {
            capturedBody = options.data as Map<String, dynamic>?;
          }
          handler.next(options);
        },
      ));

      await provider.pushNoteBody('new', {
        'subject': 'fresh',
        'content': 'body',
        'catalogName': 'GasLog',
      });

      expect(capturedBody, isNotNull);
      expect(capturedBody!['uuid'], 'new');
      expect(capturedBody!['authorId'], 3);
      expect(capturedBody!['catalogId'], 7);
      expect(capturedBody!['subject'], 'fresh');
    });

    test('PUTs when the server already has the uuid', () async {
      adapter.onGet(
        '/notes/by-uuid/existing',
        (server) => server.reply(200, {
          'id': 42,
          'uuid': 'existing',
        }),
      );
      String? capturedMethod;
      String? capturedPath;
      adapter.onPut(
        '/notes/42',
        (server) => server.reply(204, null),
        data: Matchers.any,
      );
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'PUT') {
            capturedMethod = options.method;
            capturedPath = options.path;
          }
          handler.next(options);
        },
      ));

      await provider.pushNoteBody('existing', {
        'subject': 'updated',
        'content': 'new content',
      });

      expect(capturedMethod, 'PUT');
      expect(capturedPath, '/notes/42');
    });

    test('DELETEs when the body carries a deletedAt and the note exists',
        () async {
      adapter.onGet(
        '/notes/by-uuid/gone',
        (server) => server.reply(200, {
          'id': 99,
          'uuid': 'gone',
        }),
      );
      String? capturedMethod;
      adapter.onDelete(
        '/notes/99',
        (server) => server.reply(204, null),
      );
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'DELETE') capturedMethod = options.method;
          handler.next(options);
        },
      ));

      await provider.pushNoteBody('gone', {
        'subject': 's',
        'deletedAt': '2026-05-18T13:00:00Z',
      });

      expect(capturedMethod, 'DELETE');
    });

    test('tombstone for a server-side-missing note is a no-op', () async {
      adapter.onGet(
        '/notes/by-uuid/never-existed',
        (server) => server.reply(404, {'detail': 'gone'}),
      );
      // No POST/DELETE mock — if the provider tries either, the
      // adapter throws "no matcher" which fails the test.

      await provider.pushNoteBody('never-existed', {
        'subject': 's',
        'deletedAt': '2026-05-18T13:00:00Z',
      });
    });

    test('throws when the orchestrator passes an empty uuid', () async {
      await expectLater(
        provider.pushNoteBody('', {}),
        throwsA(isA<ApiSyncProviderException>()),
      );
    });

    test('throws when the requested catalogName is unknown', () async {
      adapter.onGet(
        '/notes/by-uuid/with-unknown-catalog',
        (server) => server.reply(404, {'detail': 'not found'}),
      );
      adapter.onGet(
        '/authors',
        (server) => server.reply(200, {
          'value': [
            {'id': 1, 'accountName': 'me'},
          ],
        }),
      );
      adapter.onGet(
        '/notecatalogs',
        (server) => server.reply(200, {
          'value': [
            {'id': 1, 'name': 'GasLog'},
            // No "Unknown" catalog here.
          ],
        }),
      );

      await expectLater(
        provider.pushNoteBody('with-unknown-catalog', {
          'subject': 's',
          'content': 'c',
          'catalogName': 'Unknown',
        }),
        throwsA(isA<ApiSyncProviderException>()
            .having((e) => e.message, 'message',
                contains('Unknown'))),
      );
    });
  });

  // ============================================================
  // pushManifest
  // ============================================================

  group('pushManifest', () {
    test('is a no-op (server holds the canonical manifest)', () async {
      // No mocks for any HTTP method — if pushManifest were to
      // make a request, http_mock_adapter would fail.
      await provider.pushManifest(SyncManifest(
        version: 1,
        generatedAt: DateTime.now().toUtc(),
        deviceId: 'd-1',
        notes: const [],
        attachments: const [],
      ));
    });
  });

  // ============================================================
  // settings (Phase P3 — /profile/settings)
  // ============================================================

  group('settings', () {
    test('pullSettings 200 returns the bundle map', () async {
      adapter.onGet(
        '/profile/settings',
        (server) => server.reply(200, {
          'gasLog': <String, dynamic>{},
          'lastModified': '2026-05-29T18:04:11.000Z',
          '_v': 1,
        }),
      );

      final body = await provider.pullSettings();

      expect(body, isNotNull);
      expect(body!['_v'], 1);
      expect(body['lastModified'], '2026-05-29T18:04:11.000Z');
    });

    test('pullSettings 204 returns null (cloud empty → seed local)',
        () async {
      adapter.onGet(
        '/profile/settings',
        (server) => server.reply(204, null),
      );

      expect(await provider.pullSettings(), isNull);
    });

    test('pullSettings 404 returns null defensively', () async {
      adapter.onGet(
        '/profile/settings',
        (server) => server.reply(404, {'detail': 'not found'}),
      );

      expect(await provider.pullSettings(), isNull);
    });

    test('pushSettings PUTs the bundle to /profile/settings', () async {
      adapter.onPut(
        '/profile/settings',
        (server) => server.reply(200, {'ok': true}),
        data: Matchers.any,
      );
      Map<String, dynamic>? captured;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'PUT') {
            captured = options.data as Map<String, dynamic>?;
          }
          handler.next(options);
        },
      ));

      await provider.pushSettings({
        'gasLog': <String, dynamic>{},
        'lastModified': '2026-05-29T18:04:11.000Z',
        '_v': 1,
      });

      expect(captured, isNotNull);
      expect(captured!['_v'], 1);
      expect(captured!['lastModified'], '2026-05-29T18:04:11.000Z');
    });
  });
}

/// Minimal IdpTokenService stand-in. The full service hits
/// SharedPreferences + the network; we just need to control
/// `getStoredClaims` for the auth-gating tests.
class _FakeIdpTokenService implements IdpTokenService {
  Map<String, dynamic>? claims;
  bool cleared = false;

  @override
  Future<Map<String, dynamic>?> getStoredClaims() async => claims;

  @override
  Future<void> clearTokens() async {
    cleared = true;
  }

  // Everything else on the interface is unused by ApiSyncProvider —
  // throw if anyone wires the fake up to something we didn't expect.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
        '_FakeIdpTokenService.${invocation.memberName} not stubbed.',
      );
}
