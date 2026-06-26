import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'onedrive_test_fakes.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(validateStatus: (_) => true));
    adapter = DioAdapter(dio: dio);
  });

  OneDriveGraphClient client({String? sub = 'SUB-1'}) =>
      OneDriveGraphClient(FakeOneDriveAuth(), () async => sub, dio: dio);

  // NOTE: putAttachment streams a raw octet-stream body (the correct way to
  // upload binary via Dio). http_mock_adapter cannot route a streamed request
  // body, so putAttachment has no Dio-level unit test here; its behavior
  // (right vault path, byte fidelity) is covered by the two-device round-trip
  // test (in-memory provider, no Dio). getAttachment is GET-based and routes
  // fine, so it is unit-tested below.

  test('getAttachment returns non-null bytes on 200', () async {
    // http_mock_adapter JSON-encodes the reply body, so ResponseType.bytes
    // reads the JSON text bytes rather than a raw binary payload — we can't
    // assert exact bytes here (real Graph returns raw bytes; byte fidelity is
    // covered by the in-memory two-device round-trip test). Assert the bytes
    // path is wired (right URL + ResponseType.bytes) and returns non-null.
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/vault/attachments/note-1/a.jpg:/content',
      (server) => server.reply(200, [9, 9, 9]),
    );
    final bytes = await client().getAttachment('attachments/note-1/a.jpg');
    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);
  });

  test('getAttachment returns null on 404', () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/vault/missing.jpg:/content',
      (server) => server.reply(404, null),
    );
    expect(await client().getAttachment('missing.jpg'), isNull);
  });

  test('listAttachments returns vault-relative file paths recursively',
      () async {
    void folder(String atPath, List<Map<String, dynamic>> children) {
      adapter.onGet(
        '/me/drive/special/approot:/users/SUB-1/$atPath:/children',
        (server) => server.reply(200, {'value': children}),
      );
    }

    folder('vault', [
      {'name': 'attachments', 'folder': {'childCount': 1}},
    ]);
    folder('vault/attachments', [
      {'name': 'note-1', 'folder': {'childCount': 1}},
    ]);
    folder('vault/attachments/note-1', [
      {'name': 'a.jpg', 'file': {'mimeType': 'image/jpeg'}},
    ]);

    final paths = await client().listAttachments();
    expect(paths, {'attachments/note-1/a.jpg'});
  });

  test('listAttachments returns empty set when the vault folder is absent',
      () async {
    adapter.onGet(
      '/me/drive/special/approot:/users/SUB-1/vault:/children',
      (server) => server.reply(404, null),
    );
    expect(await client().listAttachments(), isEmpty);
  });
}
