// Wire-level coverage for putAttachment: http_mock_adapter can't route a
// streamed request body, so this drives a REAL Dio against a local HttpServer
// and asserts the raw bytes (and content length) arrive intact — closing the
// gap that the streamed octet-stream upload would otherwise have no coverage.

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';

import 'onedrive_test_fakes.dart';

void main() {
  test('putAttachment uploads the raw bytes verbatim (real Dio over HTTP)',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));

    Uint8List? receivedBody;
    String? receivedPath;
    String? receivedContentType;
    server.listen((req) async {
      receivedPath = req.uri.path;
      receivedContentType = req.headers.contentType?.value;
      final chunks = <int>[];
      await for (final c in req) {
        chunks.addAll(c);
      }
      receivedBody = Uint8List.fromList(chunks);
      req.response.statusCode = 201;
      await req.response.close();
    });

    final dio = Dio(BaseOptions(
      baseUrl: 'http://${server.address.host}:${server.port}',
      validateStatus: (_) => true,
    ));
    final client =
        OneDriveGraphClient(FakeOneDriveAuth(), () async => 'SUB-1', dio: dio);

    final payload = Uint8List.fromList([0, 1, 2, 250, 255, 7, 42]);
    await client.putAttachment('attachments/note-1/a.m4a', payload);

    expect(receivedBody, isNotNull);
    expect(receivedBody!.toList(), payload.toList(),
        reason: 'bytes must arrive verbatim (no JSON-encoding / truncation)');
    expect(receivedContentType, 'application/octet-stream');
    expect(
        receivedPath,
        '/me/drive/special/approot:/users/SUB-1/vault/attachments/note-1/a.m4a:/content');
  });
}
