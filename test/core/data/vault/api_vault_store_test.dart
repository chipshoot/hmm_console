import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/vault/api_vault_store.dart';
import 'package:hmm_console/core/data/vault/vault_store.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Coverage for the Phase 15 [ApiVaultStore]. Path translation is the
/// interesting bit — the rest of the IVaultStore contract is just
/// thin shims over Dio calls + status-code translation.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiVaultStore store;

  setUp(() {
    // Tests use a bare baseUrl (no "/v1" suffix) so http_mock_adapter's
    // path matcher lines up with the relative paths the store emits.
    // Production keeps the "/v1" prefix on baseUrl — the store is
    // unaware either way.
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    adapter = DioAdapter(dio: dio);
    store = ApiVaultStore(client: ApiClient(dio));
  });

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  group('path decomposition', () {
    test('valid attachments/note-N/file is routed to per-note endpoint',
        () async {
      adapter.onPost(
        '/notes/7/vault/main.jpg',
        (server) => server.reply(200, {
          'path': 'attachments/note-7/main.jpg',
          'contentType': 'image/jpeg',
          'byteSize': 4,
        }),
        data: Matchers.any,
      );

      await store.putBytes('attachments/note-7/main.jpg', bytes('JPEG'));
      // No throw == route hit. Implicit in DioAdapter — if no
      // matcher fires, the request errors.
    });

    test('non-vault path shape is rejected before any request', () async {
      // No DioAdapter match needed — the throw happens client-side.
      expect(
        () => store.putBytes('vault/note-7/a.jpg', bytes('x')),
        throwsArgumentError,
      );
      expect(
        () => store.getBytes('attachments/x/a.jpg'),
        throwsArgumentError,
      );
      expect(
        () => store.exists('attachments/note-/a.jpg'),
        throwsArgumentError,
      );
      // Two-segment shape (no filename) rejected too.
      expect(
        () => store.getBytes('attachments/note-1'),
        throwsArgumentError,
      );
    });
  });

  group('putBytes', () {
    test('infers content-type from the filename extension', () async {
      String? seenContentType;
      adapter.onPost(
        '/notes/3/vault/photo.png',
        (server) => server.reply(200, {
          'path': 'attachments/note-3/photo.png',
          'contentType': 'image/png',
          'byteSize': 1,
        }),
        data: Matchers.any,
      );
      // Wrap to capture the request via an interceptor.
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          seenContentType = options.contentType;
          handler.next(options);
        },
      ));

      await store.putBytes('attachments/note-3/photo.png', bytes('X'));

      expect(seenContentType, 'image/png');
    });

    test('uses caller-supplied content-type verbatim when given', () async {
      String? seenContentType;
      adapter.onPost(
        '/notes/9/vault/a.jpg',
        (server) => server.reply(200, {}),
        data: Matchers.any,
      );
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          seenContentType = options.contentType;
          handler.next(options);
        },
      ));

      await store.putBytes(
        'attachments/note-9/a.jpg',
        bytes('hi'),
        contentType: 'image/heic',
      );

      expect(seenContentType, 'image/heic');
    });

    test('413 surfaces as a VaultStoreException including the status',
        () async {
      adapter.onPost(
        '/notes/2/vault/huge.jpg',
        (server) => server.reply(413, {'detail': 'too big'}),
        data: Matchers.any,
      );

      await expectLater(
        store.putBytes('attachments/note-2/huge.jpg', bytes('X')),
        throwsA(isA<VaultStoreException>()
            .having((e) => e.message, 'message', contains('413'))
            .having((e) => e.relativePath, 'relativePath',
                'attachments/note-2/huge.jpg')),
      );
    });
  });

  group('getBytes', () {
    test('200 → non-empty bytes (path + status are the contract)',
        () async {
      // http_mock_adapter JSON-encodes any reply body, so the byte
      // stream that reaches Dio is the JSON serialisation of the
      // reply, not the original [0xDE, 0xAD, ...]. Test what the
      // store actually controls: the request hits the right path,
      // and bytes come back at all. Byte-for-byte preservation is
      // verified by the .NET-side FilesystemVaultBlobStore tests +
      // the real integration loop.
      adapter.onGet(
        '/notes/5/vault/a.jpg',
        (server) => server.reply(200, [0xDE, 0xAD, 0xBE, 0xEF]),
      );

      final out = await store.getBytes('attachments/note-5/a.jpg');

      expect(out, isNotEmpty);
    });

    test('404 throws VaultStoreException with "file not found"', () async {
      adapter.onGet(
        '/notes/9/vault/missing.jpg',
        (server) => server.reply(404, {'detail': 'gone'}),
      );

      await expectLater(
        store.getBytes('attachments/note-9/missing.jpg'),
        throwsA(isA<VaultStoreException>()
            .having((e) => e.message, 'message', contains('file not found'))),
      );
    });
  });

  group('exists', () {
    test('200 → true', () async {
      adapter.onHead(
        '/notes/4/vault/here.jpg',
        (server) => server.reply(200, null),
      );

      expect(await store.exists('attachments/note-4/here.jpg'), isTrue);
    });

    test('404 → false (no throw)', () async {
      adapter.onHead(
        '/notes/4/vault/gone.jpg',
        (server) => server.reply(404, null),
      );

      expect(await store.exists('attachments/note-4/gone.jpg'), isFalse);
    });
  });

  group('delete', () {
    test('204 → success', () async {
      adapter.onDelete(
        '/notes/1/vault/a.jpg',
        (server) => server.reply(204, null),
      );

      await store.delete('attachments/note-1/a.jpg');
    });

    test('404 → idempotent success (no throw)', () async {
      adapter.onDelete(
        '/notes/1/vault/gone.jpg',
        (server) => server.reply(404, null),
      );

      await store.delete('attachments/note-1/gone.jpg');
    });
  });

  group('list', () {
    test('empty prefix throws UnimplementedError — per-note API only',
        () async {
      expect(() => store.list(''), throwsUnimplementedError);
    });

    test('per-note prefix maps to GET /notes/{N}/vault and parses entries',
        () async {
      adapter.onGet(
        '/notes/7/vault',
        (server) => server.reply(200, [
          {
            'relativePath': 'attachments/note-7/b.jpg',
            'byteSize': 100,
          },
          {
            'relativePath': 'attachments/note-7/a.jpg',
            'byteSize': 50,
          },
        ]),
      );

      final entries = await store.list('attachments/note-7');

      // Stable sort — alphabetical by relativePath.
      expect(entries.map((e) => e.relativePath), [
        'attachments/note-7/a.jpg',
        'attachments/note-7/b.jpg',
      ]);
      expect(entries[0].byteSize, 50);
      expect(entries[1].byteSize, 100);
    });

    test('single-file prefix falls back to HEAD and yields one entry',
        () async {
      // http_mock_adapter doesn't support custom response headers
      // on reply(), so Content-Length flow-through can't be
      // asserted here — that's covered by the real loop. The
      // store defaults byteSize to 0 when the header is absent,
      // which is the realistic shape for HEAD over many real
      // servers anyway.
      adapter.onHead(
        '/notes/9/vault/only.jpg',
        (server) => server.reply(200, {}),
      );

      final entries = await store.list('attachments/note-9/only.jpg');

      expect(entries, hasLength(1));
      expect(entries[0].relativePath, 'attachments/note-9/only.jpg');
      // No Content-Length in the mock → store falls back to 0.
      expect(entries[0].byteSize, 0);
    });

    test('single-file prefix that 404s yields empty list', () async {
      adapter.onHead(
        '/notes/9/vault/missing.jpg',
        (server) => server.reply(404, null),
      );

      final entries = await store.list('attachments/note-9/missing.jpg');

      expect(entries, isEmpty);
    });

    test('per-note prefix that 404s yields empty list', () async {
      adapter.onGet(
        '/notes/77/vault',
        (server) => server.reply(404, null),
      );

      final entries = await store.list('attachments/note-77');

      expect(entries, isEmpty);
    });
  });
}
