import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/idp_token_service.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:hmm_console/core/data/sync/onedrive_sync_provider.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'onedrive_test_fakes.dart';

class _FakeIdpTokenService implements IdpTokenService {
  @override
  Future<Map<String, dynamic>?> getStoredClaims() async => {'sub': 'SUB-1'};
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('supportsAttachments is true and pullAttachment delegates to Graph',
      () async {
    final dio = Dio(BaseOptions(validateStatus: (_) => true));
    DioAdapter(dio: dio).onGet(
      '/me/drive/special/approot:/users/SUB-1/vault/x.m4a:/content',
      (server) => server.reply(200, [7, 7]),
    );
    final graph =
        OneDriveGraphClient(FakeOneDriveAuth(), () async => 'SUB-1', dio: dio);
    final provider =
        OneDriveSyncProvider(FakeOneDriveAuth(), graph, _FakeIdpTokenService());

    expect(provider.supportsAttachments, isTrue);
    final bytes = await provider.pullAttachment('x.m4a');
    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);
  });
}
