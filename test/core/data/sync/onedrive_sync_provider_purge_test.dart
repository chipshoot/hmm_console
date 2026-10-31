import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:hmm_console/core/data/sync/onedrive_sync_provider.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'onedrive_test_fakes.dart';

class _FakeIdpTokenService implements IdpTokenService {
  @override
  Future<Map<String, dynamic>?> getStoredClaims() async => {'sub': 'SUB-1'};
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'purgeNote deletes the note blob and each released vault file',
    () async {
      final dio = Dio(BaseOptions(validateStatus: (_) => true));
      final adapter = DioAdapter(dio: dio);
      const root = '/me/drive/special/approot:/users/SUB-1';
      adapter.onDelete('$root/notes/n1.json', (s) => s.reply(204, null));
      adapter.onDelete('$root/vault/note-1/a.jpg', (s) => s.reply(204, null));
      final deletes = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.method == 'DELETE') deletes.add(o.path);
            h.next(o);
          },
        ),
      );
      final graph = OneDriveGraphClient(
        FakeOneDriveAuth(),
        () async => 'SUB-1',
        dio: dio,
      );
      final provider = OneDriveSyncProvider(
        FakeOneDriveAuth(),
        graph,
        _FakeIdpTokenService(),
      );

      await provider.purgeNote('n1', releasedVaultPaths: {'note-1/a.jpg'});

      expect(deletes, ['$root/notes/n1.json', '$root/vault/note-1/a.jpg']);
    },
  );
}
