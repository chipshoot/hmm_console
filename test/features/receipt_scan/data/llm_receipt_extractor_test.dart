import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';
import 'package:hmm_console/core/llm/llm_client.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/receipt_scan/data/api_llm_extractor.dart';
import 'package:hmm_console/features/receipt_scan/data/llm_receipt_extractor.dart';
import 'package:hmm_console/features/receipt_scan/data/receipt_llm_schema.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:hmm_console/core/network/api_client.dart';

class _FakeClient implements LlmClient {
  _FakeClient(this.json);
  final Map<String, Object?> json;
  final requests = <LlmRequest>[];
  String? purpose;

  @override
  Future<LlmResponse> complete(
    LlmRequest r, {
    String? engineId,
    String? purpose,
    CancelToken? cancel,
  }) async {
    requests.add(r);
    this.purpose = purpose;
    return LlmResponse(text: '{}', json: json, stopReason: LlmStopReason.end);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _sample = <String, Object?>{
  'shopName': 'Joe Auto',
  'date': '2026-03-04',
  'odometer': 45000,
  'tax': 1.5,
  'total': 31.5,
  'currency': 'CAD',
  'lineItems': [
    {
      'type': 'Part',
      'name': 'Filter',
      'quantity': 2,
      'unitCost': 10.0,
      'amount': 20.0,
    },
  ],
};

void main() {
  late _FakeClient client;
  setUp(() => client = _FakeClient(_sample));

  ReceiptInput img({bool sensitive = false}) => ReceiptInput(
    bytes: Uint8List.fromList([1, 2, 3]),
    contentType: 'image/png',
    sensitive: sensitive,
  );

  test('sensitive input refused before any call', () async {
    final x = LlmReceiptExtractor(client, compress: (b) async => b);
    await expectLater(
      x.extract(img(sensitive: true)),
      throwsA(isA<LlmSensitiveRefused>()),
    );
    expect(client.requests, isEmpty);
  });

  test('image request uses receipts purpose, schema and prompt', () async {
    final out = Uint8List.fromList([9, 9]);
    final x = LlmReceiptExtractor(client, compress: (b) async => out);
    await x.extract(img());
    final r = client.requests.single;
    expect(client.purpose, 'receipts');
    expect(r.system, receiptLlmPrompt);
    expect(r.responseSchema, receiptLlmSchema);
    expect(r.containsSensitive, false);
    final part = r.messages.single.parts.single as ImagePart;
    expect(part.bytes, out);
    expect(part.mimeType, 'image/jpeg');
  });

  test('pdf input becomes DocumentPart, uncompressed', () async {
    var compressed = false;
    final x = LlmReceiptExtractor(
      client,
      compress: (b) async {
        compressed = true;
        return b;
      },
    );
    await x.extract(
      ReceiptInput(
        bytes: Uint8List.fromList([7]),
        contentType: 'application/pdf',
      ),
    );
    final part = client.requests.single.messages.single.parts.single;
    expect(part, isA<DocumentPart>());
    expect((part as DocumentPart).bytes, [7]);
    expect(compressed, false);
  });

  test('large image is downscaled under 4 MB', () async {
    final big = Uint8List(5 * 1024 * 1024);
    final x = LlmReceiptExtractor(
      client,
      compress: (b) async => b.length > 4 * 1024 * 1024 ? Uint8List(1000) : b,
    );
    await x.extract(ReceiptInput(bytes: big, contentType: 'image/jpeg'));
    final part =
        client.requests.single.messages.single.parts.single as ImagePart;
    expect(part.bytes.length, lessThan(4 * 1024 * 1024));
  });

  test('json maps to draft with provider source', () async {
    final x = LlmReceiptExtractor(client, compress: (b) async => b);
    final d = await x.extract(img());
    expect(d.source, ReceiptExtractorMode.provider);
    expect(d.shopName, 'Joe Auto');
    expect(d.date, DateTime(2026, 3, 4));
    expect(d.odometer, 45000);
    expect(d.lineItems.single.type, LineItemType.part);
    expect(d.lineItems.single.quantity, 2);
  });

  group('receiptTargetSize', () {
    test('portrait: long side capped at 2000', () {
      expect(receiptTargetSize(3000, 4000), (1500, 2000));
    });
    test('landscape: long side capped at 2000', () {
      expect(receiptTargetSize(4000, 3000), (2000, 1500));
    });
    test('already small: never upscaled', () {
      expect(receiptTargetSize(800, 1200), (800, 1200));
      expect(receiptTargetSize(2000, 2000), (2000, 2000));
    });
    test('extreme aspect keeps at least 1 px', () {
      expect(receiptTargetSize(100, 20000), (10, 2000));
      expect(receiptTargetSize(1, 40000), (1, 2000));
    });
  });

  group('ApiLlmExtractor shares the mapper', () {
    Future<ReceiptDraft> run(String body) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://x/v1'))
        ..httpClientAdapter = _Body(body);
      return ApiLlmExtractor(ApiClient(dio)).extract(
        ReceiptInput(bytes: Uint8List.fromList([1]), contentType: 'image/jpeg'),
      );
    }

    test('camelCase keys', () async {
      final d = await run(
        '{"shopName":"Joe","odometer":10,"lineItems":'
        '[{"type":"Fee","name":"Env","quantity":3,"amount":3.0}]}',
      );
      expect(d.source, ReceiptExtractorMode.cloudAi);
      expect(d.shopName, 'Joe');
      expect(d.lineItems.single.quantity, 3);
    });

    test('PascalCase keys', () async {
      final d = await run(
        '{"ShopName":"Joe","Odometer":10,"LineItems":'
        '[{"Type":"Fee","Name":"Env","Quantity":3,"Amount":3.0}]}',
      );
      expect(d.shopName, 'Joe');
      expect(d.odometer, 10);
      expect(d.lineItems.single.name, 'Env');
      expect(d.lineItems.single.quantity, 3);
    });
  });
}

class _Body implements HttpClientAdapter {
  _Body(this.body);
  final String body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}
