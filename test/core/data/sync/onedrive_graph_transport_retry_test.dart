// A dropped connection (no HTTP response at all) is retried once on the
// Graph client's main Dio; HTTP status responses and cancellations are not.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/sync/onedrive_graph_client.dart';

import 'onedrive_test_fakes.dart';

/// Plays back one scripted outcome per request: an [Object] to throw, or a
/// `(status, body)` record to answer with.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);
  final List<Object> script;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final step = script[requests.length - 1];
    if (step is (int, Object?)) {
      return ResponseBody.fromString(
        jsonEncode(step.$2),
        step.$1,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    throw step;
  }

  @override
  void close({bool force = false}) {}
}

DioException _connectionError(RequestOptions o) => DioException(
  requestOptions: o,
  type: DioExceptionType.connectionError,
  error: const SocketException('Connection reset by peer'),
);

void main() {
  late _ScriptedAdapter adapter;
  late OneDriveGraphClient client;

  OneDriveGraphClient build(List<Object> script) {
    adapter = _ScriptedAdapter(script);
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://graph.example',
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = adapter;
    return OneDriveGraphClient(
      FakeOneDriveAuth(),
      () async => 'SUB-1',
      dio: dio,
      transportRetryDelay: Duration.zero,
    );
  }

  // The adapter throws a raw error; Dio wraps it as DioExceptionType.unknown
  // (as it does for an HttpException "read failed" / "Connection closed").
  const readFailed = HttpException('read failed');

  test(
    'GET: a connection error then success → succeeds on the retry',
    () async {
      client = build([
        readFailed,
        (200, {'id': 'n1'}),
      ]);

      final blob = await client.getNoteBlob('n1');

      expect(blob, {'id': 'n1'});
      expect(adapter.requests, hasLength(2));
    },
  );

  test('PUT note blob: a connection error then success → succeeds', () async {
    client = build([
      const SocketException(
        'Connection closed before full header was '
        'received',
      ),
      (201, {'id': 'n1'}),
    ]);

    await client.putNoteBlob('n1', {'id': 'n1'});

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.map((r) => r.method), ['PUT', 'PUT']);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer test-token');
  });

  test('connectionError type is retried too', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://graph.example',
        validateStatus: (_) => true,
      ),
    );
    var calls = 0;
    // A typed connectionError from the adapter on the first call.
    dio.httpClientAdapter = _CallbackAdapter((o) {
      calls++;
      if (calls == 1) throw _connectionError(o);
      return ResponseBody.fromString(
        '{"id":"n1"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    client = OneDriveGraphClient(
      FakeOneDriveAuth(),
      () async => 'SUB-1',
      dio: dio,
      transportRetryDelay: Duration.zero,
    );

    expect(await client.getNoteBlob('n1'), {'id': 'n1'});
    expect(calls, 2);
  });

  test(
    'two connection errors in a row → fails after exactly 2 attempts',
    () async {
      client = build([
        readFailed,
        readFailed,
        (200, {'id': 'never'}),
      ]);

      await expectLater(client.getNoteBlob('n1'), throwsA(isA<DioException>()));
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'PUT: two connection errors in a row → fails after 2 attempts',
    () async {
      client = build([readFailed, readFailed, (201, {})]);

      await expectLater(
        client.putNoteBlob('n1', {'id': 'n1'}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, hasLength(2));
    },
  );

  test('a TLS handshake drop then success → succeeds on the retry', () async {
    client = build([
      const HandshakeException('Connection terminated during handshake'),
      (200, {'id': 'n1'}),
    ]);

    expect(await client.getNoteBlob('n1'), {'id': 'n1'});
    expect(adapter.requests, hasLength(2));
  });

  test('a 500 response is not retried', () async {
    client = build([
      (500, {'error': 'boom'}),
      (200, {'id': 'n1'}),
    ]);

    await expectLater(
      client.getNoteBlob('n1'),
      throwsA(isA<OneDriveGraphException>()),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('a cancelled request is not retried', () async {
    var calls = 0;
    final dio =
        Dio(
            BaseOptions(
              baseUrl: 'https://graph.example',
              validateStatus: (_) => true,
            ),
          )
          ..httpClientAdapter = _CallbackAdapter((o) {
            calls++;
            throw DioException.requestCancelled(
              requestOptions: o,
              reason: 'user',
            );
          });
    client = OneDriveGraphClient(
      FakeOneDriveAuth(),
      () async => 'SUB-1',
      dio: dio,
      transportRetryDelay: Duration.zero,
    );

    await expectLater(client.getNoteBlob('n1'), throwsA(isA<DioException>()));
    expect(calls, 1);
  });
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.onFetch);
  final ResponseBody Function(RequestOptions) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => onFetch(options);

  @override
  void close({bool force = false}) {}
}
