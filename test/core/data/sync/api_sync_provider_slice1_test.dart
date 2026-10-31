import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/api_sync_provider.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiSyncProvider provider;
  late List<String> writes;
  late Map<String, Object?> sent;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    provider = ApiSyncProvider(
      client: ApiClient(dio),
      tokenService: _FakeIdpTokenService(),
    );
    writes = [];
    sent = {};
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (o.method != 'GET') {
            writes.add('${o.method} ${o.path}');
            sent['${o.method} ${o.path}'] = o.data;
          }
          h.next(o);
        },
      ),
    );
  });

  void existing(String uuid, Map<String, dynamic> note) => adapter.onGet(
    '/notes/by-uuid/$uuid',
    (s) => s.reply(200, {'uuid': uuid, ...note}),
  );

  group('pull', () {
    test('tag names come through when the server sends them', () async {
      existing('abc', {
        'id': 7,
        'subject': 's',
        'content': 'c',
        'catalogName': 'General',
        'lastModifiedDate': '2026-10-18T10:00:00Z',
        'isDeleted': false,
        'tagNames': ['work'],
      });

      final body = (await provider.pullNoteBody('abc'))!;

      expect(body['tags'], ['work']);
      expect(
        body.containsKey('isPinned'),
        isFalse,
        reason: 'pin/flag are note state, never note body',
      );
      expect(body.containsKey('flagColor'), isFalse);
    });

    test(
      'an empty tagNames list stays a present key (clears on apply)',
      () async {
        existing('abc', {'id': 7, 'subject': 's', 'tagNames': []});

        final body = (await provider.pullNoteBody('abc'))!;

        expect(body.containsKey('tags'), isTrue);
        expect(body['tags'], isEmpty);
      },
    );

    test(
      'an old server (no tagNames) yields a body without a tags key',
      () async {
        existing('abc', {
          'id': 7,
          'subject': 's',
          'content': 'c',
          'isDeleted': false,
        });

        final body = (await provider.pullNoteBody('abc'))!;

        expect(body.containsKey('tags'), isFalse);
      },
    );
  });

  group('push', () {
    test('create sends no pin/flag and pushes tags to the new id', () async {
      adapter.onGet(
        '/notes/by-uuid/new',
        (s) => s.reply(404, {'detail': 'nf'}),
      );
      adapter.onGet(
        '/authors',
        (s) => s.reply(200, {
          'value': [
            {'id': 3},
          ],
        }),
      );
      adapter.onGet(
        '/notecatalogs',
        (s) => s.reply(200, {
          'value': [
            {'id': 1, 'name': 'General'},
          ],
        }),
      );
      adapter.onPost(
        '/notes',
        (s) => s.reply(201, {'id': 99, 'uuid': 'new'}),
        data: Matchers.any,
      );
      adapter.onPut(
        '/notes/99/tags',
        (s) => s.reply(200, ['work']),
        data: Matchers.any,
      );

      await provider.pushNoteBody('new', {
        'subject': 's',
        'content': 'c',
        'catalogName': 'General',
        'tags': ['work'],
      });

      final create = sent['POST /notes'] as Map<String, dynamic>;
      expect(create.containsKey('isPinned'), isFalse);
      expect(create.containsKey('flagColor'), isFalse);
      expect(writes, ['POST /notes', 'PUT /notes/99/tags']);
      expect(sent['PUT /notes/99/tags'], {
        'names': ['work'],
      });
    });

    test(
      'a restored note is undeleted on the server before it is updated',
      () async {
        existing('r', {'id': 8, 'isDeleted': true});
        adapter.onPost(
          '/notes/8/restore',
          (s) => s.reply(200, {'id': 8, 'uuid': 'r', 'isDeleted': false}),
          data: Matchers.any,
        );
        adapter.onPut(
          '/notes/8',
          (s) => s.reply(204, null),
          data: Matchers.any,
        );

        await provider.pushNoteBody('r', {
          'subject': 'back',
          'content': 'c',
          'deletedAt': null,
        });

        expect(writes, ['POST /notes/8/restore', 'PUT /notes/8']);
      },
    );

    test(
      'restoring against a server without the restore endpoint fails clearly',
      () async {
        existing('r', {'id': 8, 'isDeleted': true});
        adapter.onPost(
          '/notes/8/restore',
          (s) => s.reply(404, {'detail': 'nf'}),
          data: Matchers.any,
        );

        await expectLater(
          provider.pushNoteBody('r', {'subject': 'back', 'content': 'c'}),
          throwsA(
            isA<ApiSyncProviderException>().having(
              (e) => e.message,
              'message',
              contains('restore'),
            ),
          ),
        );
        expect(writes, [
          'POST /notes/8/restore',
        ], reason: 'never PUT a deleted note');
      },
    );

    test(
      'a tombstone for a note already deleted on the server is a no-op',
      () async {
        existing('gone', {'id': 9, 'isDeleted': true});
        // No DELETE mock: a DELETE would fail the test.

        await provider.pushNoteBody('gone', {
          'subject': 's',
          'deletedAt': '2026-10-18T10:00:00Z',
        });

        expect(writes, isEmpty);
      },
    );

    test('tags are set-replaced on the server after an update', () async {
      existing('u', {'id': 42});
      adapter.onPut('/notes/42', (s) => s.reply(204, null), data: Matchers.any);
      adapter.onPut(
        '/notes/42/tags',
        (s) => s.reply(200, ['a', 'b']),
        data: Matchers.any,
      );

      await provider.pushNoteBody('u', {
        'subject': 's',
        'content': 'c',
        'tags': ['a', 'b'],
      });

      expect(writes, ['PUT /notes/42', 'PUT /notes/42/tags']);
      expect(sent['PUT /notes/42/tags'], {
        'names': ['a', 'b'],
      });
    });

    test('an update without a tags key makes no tags call', () async {
      existing('u', {'id': 42});
      adapter.onPut('/notes/42', (s) => s.reply(204, null), data: Matchers.any);

      await provider.pushNoteBody('u', {'subject': 's', 'content': 'c'});

      expect(writes, ['PUT /notes/42']);
      final payload = sent['PUT /notes/42'] as Map<String, dynamic>;
      expect(payload.containsKey('isPinned'), isFalse);
    });

    test(
      'an old server without the tags endpoint does not fail the push',
      () async {
        existing('u', {'id': 42});
        adapter.onPut(
          '/notes/42',
          (s) => s.reply(204, null),
          data: Matchers.any,
        );
        adapter.onPut(
          '/notes/42/tags',
          (s) => s.reply(404, {'detail': 'nf'}),
          data: Matchers.any,
        );

        await provider.pushNoteBody('u', {
          'subject': 's',
          'content': 'c',
          'tags': ['a'],
        });

        expect(writes, ['PUT /notes/42', 'PUT /notes/42/tags']);
      },
    );
  });

  group('note states', () {
    test(
      'pullNoteStates maps the caller\'s rows to the state document',
      () async {
        adapter.onGet(
          '/notes/states',
          (s) => s.reply(200, [
            {
              'noteId': 7,
              'noteUuid': 'abc',
              'isPinned': true,
              'flagColor': 42,
              'lastModifiedDate': '2026-10-18T10:00:00Z',
            },
            {
              'noteId': 8,
              'noteUuid': null,
              'isPinned': true,
              'flagColor': null,
              'lastModifiedDate': '2026-10-18T10:00:00Z',
            },
          ]),
        );

        final doc = (await provider.pullNoteStates())!;

        final state = (doc['states'] as List).single as Map<String, dynamic>;
        expect(state['noteUuid'], 'abc');
        expect(state['isPinned'], isTrue);
        expect(state['flagColor'], 42, reason: 'unknown colours are kept');
        expect(
          DateTime.parse(state['lastModified'] as String),
          DateTime.utc(2026, 10, 18, 10),
        );
      },
    );

    test(
      'a server without the states endpoint is reported as unsupported',
      () async {
        adapter.onGet('/notes/states', (s) => s.reply(404, {'detail': 'nf'}));

        await expectLater(
          provider.pullNoteStates(),
          throwsA(isA<NoteStatesUnsupportedException>()),
        );
      },
    );

    test('pushNoteStates PUTs only the changed states, by server id', () async {
      adapter.onGet(
        '/notes/states',
        (s) => s.reply(200, [
          {
            'noteId': 7,
            'noteUuid': 'abc',
            'isPinned': false,
            'flagColor': null,
            'lastModifiedDate': '2026-10-18T09:00:00Z',
          },
        ]),
      );
      adapter.onPut(
        '/notes/7/state',
        (s) => s.reply(200, {}),
        data: Matchers.any,
      );
      await provider.pullNoteStates();

      await provider.pushNoteStates(
        {
          'states': [
            {
              'noteUuid': 'abc',
              'isPinned': false,
              'flagColor': null,
              'lastModified': '2026-10-18T10:00:00.000Z',
            },
            {
              'noteUuid': 'same',
              'isPinned': true,
              'flagColor': 1,
              'lastModified': '2026-10-18T08:00:00.000Z',
            },
          ],
        },
        changed: {'abc'},
      );

      expect(writes, ['PUT /notes/7/state']);
      expect(
        sent['PUT /notes/7/state'],
        {
          'isPinned': false,
          'flagColor': null,
          'lastModifiedDate': '2026-10-18T10:00:00.000Z',
        },
        reason: 'unpin is sent as false, never as a delete',
      );
    });

    test(
      'a note unknown to the GET is resolved by uuid; one the server lacks is skipped',
      () async {
        adapter.onGet('/notes/states', (s) => s.reply(200, []));
        adapter.onGet(
          '/notes/by-uuid/new',
          (s) => s.reply(200, {'id': 9, 'uuid': 'new'}),
        );
        adapter.onGet(
          '/notes/by-uuid/unsynced',
          (s) => s.reply(404, {'detail': 'nf'}),
        );
        adapter.onPut(
          '/notes/9/state',
          (s) => s.reply(200, {}),
          data: Matchers.any,
        );
        await provider.pullNoteStates();

        await provider.pushNoteStates(
          {
            'states': [
              {
                'noteUuid': 'new',
                'isPinned': true,
                'flagColor': 0,
                'lastModified': '2026-10-18T10:00:00.000Z',
              },
              {
                'noteUuid': 'unsynced',
                'isPinned': true,
                'flagColor': null,
                'lastModified': '2026-10-18T10:00:00.000Z',
              },
            ],
          },
          changed: {'new', 'unsynced'},
        );

        expect(writes, ['PUT /notes/9/state']);
      },
    );

    test(
      'a failed PUT is reported once, after the others were tried',
      () async {
        adapter.onGet(
          '/notes/states',
          (s) => s.reply(200, [
            {
              'noteId': 7,
              'noteUuid': 'a',
              'isPinned': false,
              'lastModifiedDate': '2026-10-18T09:00:00Z',
            },
            {
              'noteId': 8,
              'noteUuid': 'b',
              'isPinned': false,
              'lastModifiedDate': '2026-10-18T09:00:00Z',
            },
          ]),
        );
        adapter.onPut(
          '/notes/7/state',
          (s) => s.reply(500, {'detail': 'boom'}),
          data: Matchers.any,
        );
        adapter.onPut(
          '/notes/8/state',
          (s) => s.reply(200, {}),
          data: Matchers.any,
        );
        await provider.pullNoteStates();

        await expectLater(
          provider.pushNoteStates(
            {
              'states': [
                {
                  'noteUuid': 'a',
                  'isPinned': true,
                  'lastModified': '2026-10-18T10:00:00.000Z',
                },
                {
                  'noteUuid': 'b',
                  'isPinned': true,
                  'lastModified': '2026-10-18T10:00:00.000Z',
                },
              ],
            },
            changed: {'a', 'b'},
          ),
          throwsA(isA<ApiSyncProviderException>()),
        );
        expect(writes, ['PUT /notes/7/state', 'PUT /notes/8/state']);
      },
    );
  });

  group('tag definitions', () {
    // Server tags are global (no author column): definition sync would copy
    // every account's tags and deactivate tags for all accounts (slice 6).
    test('pullTags and pushTags make no HTTP calls', () async {
      final requests = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requests.add('${o.method} ${o.path}');
            h.next(o);
          },
        ),
      );

      final doc = await provider.pullTags();
      await provider.pushTags({
        'tags': [
          {'name': 'home', 'deleted': false},
          {'name': 'work', 'deleted': true},
        ],
      });

      expect(doc, isNull);
      expect(requests, isEmpty);
    });
  });
}

class _FakeIdpTokenService implements IdpTokenService {
  @override
  Future<Map<String, dynamic>?> getStoredClaims() async => {'sub': 'user-1'};

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '_FakeIdpTokenService.${invocation.memberName} not stubbed.',
  );
}
