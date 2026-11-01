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
  late List<String> deletes;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    provider = ApiSyncProvider(
      client: ApiClient(dio),
      tokenService: _FakeIdpTokenService(),
    );
    deletes = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (o.method == 'DELETE') deletes.add(o.path);
          h.next(o);
        },
      ),
    );
  });

  test('a deleted server note is purged through /purge', () async {
    adapter.onGet(
      '/notes/by-uuid/p1',
      (s) => s.reply(200, {'id': 5, 'uuid': 'p1', 'isDeleted': true}),
    );
    adapter.onDelete('/notes/5/purge', (s) => s.reply(204, null));

    await provider.purgeNote('p1');

    expect(deletes, ['/notes/5/purge']);
  });

  test('a live server note is never purged', () async {
    adapter.onGet(
      '/notes/by-uuid/p1',
      (s) => s.reply(200, {'id': 5, 'uuid': 'p1', 'isDeleted': false}),
    );

    await expectLater(
      provider.purgeNote('p1'),
      throwsA(isA<NoteLiveOnServerException>()),
    );
    expect(deletes, isEmpty);
  });

  test('a 409 from /purge (restored meanwhile) surfaces as live', () async {
    adapter.onGet(
      '/notes/by-uuid/p1',
      (s) => s.reply(200, {'id': 5, 'uuid': 'p1', 'isDeleted': true}),
    );
    adapter.onDelete(
      '/notes/5/purge',
      (s) => s.reply(409, {'detail': 'not deleted'}),
    );

    await expectLater(
      provider.purgeNote('p1'),
      throwsA(isA<NoteLiveOnServerException>()),
    );
  });

  test('a note the server never had (or already purged) is done', () async {
    adapter.onGet('/notes/by-uuid/p1', (s) => s.reply(404, {'detail': 'nf'}));

    await provider.purgeNote('p1');

    expect(deletes, isEmpty);
  });

  test('a 404 from /purge after a deleted probe means a missing route: '
      'it throws so the caller keeps its row', () async {
    adapter.onGet(
      '/notes/by-uuid/p1',
      (s) => s.reply(200, {'id': 5, 'uuid': 'p1', 'isDeleted': true}),
    );
    adapter.onDelete('/notes/5/purge', (s) => s.reply(404, {'detail': 'nf'}));

    await expectLater(provider.purgeNote('p1'), throwsA(isA<DioException>()));
    expect(deletes, ['/notes/5/purge']);
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
