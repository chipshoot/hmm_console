import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/cloud_sync_provider.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';

import 'onedrive_test_fakes.dart';

class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final Map<String, dynamic> headers;
  final List<int> body;
}

class Reply {
  const Reply(this.status, [this.json, this.bytes]);
  final int status;
  final Object? json;
  final List<int>? bytes;
}

/// Wire-level adapter: consumes streamed bodies (http_mock_adapter can't) and
/// answers from a queue.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.replies);
  final List<Reply> replies;
  final requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = <int>[];
    if (requestStream != null) {
      await for (final c in requestStream) {
        body.addAll(c);
      }
    }
    requests.add(
      RecordedRequest(
        options.method,
        options.uri,
        Map.of(options.headers),
        body,
      ),
    );
    final r = replies.removeAt(0);
    final payload =
        r.bytes ?? (r.json == null ? <int>[] : utf8.encode(jsonEncode(r.json)));
    return ResponseBody.fromBytes(
      payload,
      r.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        Headers.contentLengthHeader: ['${payload.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

OneDriveGraphClient makeClient(RecordingAdapter a) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://graph.microsoft.com/v1.0',
      validateStatus: (_) => true,
    ),
  )..httpClientAdapter = a;
  final up = Dio(BaseOptions(validateStatus: (_) => true))
    ..httpClientAdapter = a;
  return OneDriveGraphClient(
    FakeOneDriveAuth(),
    () async => 'SUB-1',
    dio: dio,
    uploadDio: up,
  );
}

String? header(RecordedRequest r, String name) {
  for (final e in r.headers.entries) {
    if (e.key.toLowerCase() == name.toLowerCase()) return '${e.value}';
  }
  return null;
}

void main() {
  const url = 'https://upload.example/session/abc?tempauth=x';

  test('createUploadSession posts the replace conflict behaviour', () async {
    final a = RecordingAdapter([
      Reply(200, {'uploadUrl': url}),
    ]);
    final got = await makeClient(
      a,
    ).createUploadSession('attachments/note-1/u.mov');
    expect(got, url);
    final r = a.requests.single;
    expect(r.method, 'POST');
    expect(
      r.uri.path,
      endsWith('/vault/attachments/note-1/u.mov:/createUploadSession'),
    );
    expect(jsonDecode(utf8.decode(r.body)), {
      'item': {'@microsoft.graph.conflictBehavior': 'replace'},
    });
  });

  test('fragment PUT goes to uploadUrl without Authorization', () async {
    final a = RecordingAdapter([Reply(202), Reply(201)]);
    final c = makeClient(a);
    final chunk = Uint8List.fromList(List.filled(10, 7));
    expect(await c.putUploadFragment(url, chunk, 0, 20), isFalse);
    expect(await c.putUploadFragment(url, chunk, 10, 20), isTrue);
    final r = a.requests.first;
    expect(r.method, 'PUT');
    expect(r.uri.toString(), url);
    expect(header(r, 'Content-Range'), 'bytes 0-9/20');
    expect(header(r, 'Content-Length'), '10');
    expect(header(r, 'authorization'), isNull);
    expect(r.body.length, 10);
    expect(header(a.requests[1], 'Content-Range'), 'bytes 10-19/20');
  });

  test('next offset parses nextExpectedRanges', () async {
    final a = RecordingAdapter([
      Reply(200, {
        'nextExpectedRanges': ['10485760-'],
      }),
      Reply(404),
    ]);
    final c = makeClient(a);
    expect(await c.uploadSessionNextOffset(url), 10485760);
    expect(await c.uploadSessionNextOffset(url), isNull);
    expect(header(a.requests.first, 'authorization'), isNull);
  });

  test('fragment 404 throws LargeUploadSessionGone', () async {
    final a = RecordingAdapter([Reply(404)]);
    expect(
      () => makeClient(a).putUploadFragment(url, Uint8List.fromList([1]), 0, 1),
      throwsA(isA<LargeUploadSessionGone>()),
    );
  });

  test(
    'deleteUploadSession tolerates 404 and sends no Authorization',
    () async {
      final a = RecordingAdapter([Reply(204), Reply(404)]);
      final c = makeClient(a);
      await c.deleteUploadSession(url);
      await c.deleteUploadSession(url);
      expect(a.requests.first.method, 'DELETE');
      expect(header(a.requests.first, 'authorization'), isNull);
    },
  );

  test('attachmentExists maps 200/404', () async {
    final a = RecordingAdapter([
      Reply(200, {'id': 'x'}),
      Reply(404),
    ]);
    final c = makeClient(a);
    expect(await c.attachmentExists('v/a.mov'), isTrue);
    expect(await c.attachmentExists('v/a.mov'), isFalse);
    expect(a.requests.first.uri.path, endsWith('/vault/v/a.mov'));
  });
}
