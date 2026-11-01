import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/local/database.dart';
import 'package:hmm_console/core/data/local/local_tag_repository.dart';
import 'package:hmm_console/core/data/sync/api_sync_provider.dart';
import 'package:hmm_console/core/data/sync/sync_meta_repository.dart';
import 'package:hmm_console/core/data/sync/sync_orchestrator.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onedrive_test_fakes.dart';

/// cloudApi tag definitions are global on the server, so a cloudApi sync must
/// neither import other accounts' tags nor touch the server's /tags at all —
/// and must leave this device's own definitions alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a cloudApi sync keeps local tag definitions and never calls /tags',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = HmmDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final tags = LocalTagRepository(db);
      await tags.createTag(TagsCompanion.insert(name: 'mine'));

      final dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
      final adapter = DioAdapter(dio: dio);
      final tagRequests = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.path.startsWith('/tags')) {
              tagRequests.add('${o.method} ${o.path}');
            }
            h.next(o);
          },
        ),
      );
      adapter
        ..onGet('/profile/settings', (s) => s.reply(204, null))
        ..onGet(
          '/notes',
          (s) => s.reply(
            200,
            {'value': []},
            headers: {
              Headers.contentTypeHeader: ['application/json'],
              'x-pagination': [
                jsonEncode({
                  'totalCount': 0,
                  'pageSize': 100,
                  'currentPage': 1,
                  'totalPages': 1,
                  'maxPageSize': 100,
                }),
              ],
            },
          ),
        )
        ..onGet('/notes/states', (s) => s.reply(404, null))
        // Another account's tag: must never reach this device.
        ..onGet(
          '/tags',
          (s) => s.reply(200, {
            'value': [
              {'id': 9, 'name': 'theirs'},
            ],
          }),
          queryParameters: {'PageNumber': 1, 'PageSize': 100},
        )
        ..onPost('/tags', (s) => s.reply(201, {'id': 10}), data: Matchers.any);

      final orchestrator = SyncOrchestrator(
        provider: ApiSyncProvider(
          client: ApiClient(dio),
          tokenService: _FakeIdpTokenService(),
        ),
        db: db,
        meta: SyncMetaRepository(),
        vaultStore: noopVaultStore,
      );

      final result = await orchestrator.syncNow();

      expect(result.errors, isEmpty, reason: result.errors.join('\n'));
      final names = (await tags.getTagsWithMeta()).map((t) => t.name).toList();
      expect(names, ['mine']);
      expect(tagRequests, isEmpty);
    },
  );
}

class _FakeIdpTokenService implements IdpTokenService {
  @override
  Future<Map<String, dynamic>?> getStoredClaims() async => {'sub': 'user-1'};

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '_FakeIdpTokenService.${invocation.memberName} not stubbed.',
  );
}
