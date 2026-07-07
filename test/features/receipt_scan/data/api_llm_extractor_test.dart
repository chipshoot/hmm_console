import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/receipt_scan/data/api_llm_extractor.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.statusCode, this.body,
      {this.contentType = Headers.jsonContentType});
  final int statusCode;
  final String body;
  final String contentType;
  RequestOptions? captured;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiLlmExtractor, _CapturingAdapter) _make(int status, String body,
    {String contentType = Headers.jsonContentType}) {
  final adapter = _CapturingAdapter(status, body, contentType: contentType);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/v1'))
    ..httpClientAdapter = adapter;
  return (ApiLlmExtractor(ApiClient(dio)), adapter);
}

ReceiptInput _image() =>
    ReceiptInput(bytes: Uint8List.fromList([1, 2, 3]), contentType: 'image/jpeg');
ReceiptInput _pdf() =>
    ReceiptInput(bytes: Uint8List.fromList([4, 5]), contentType: 'application/pdf');

void main() {
  const okBody = '''
  {
    "shopName": "Bob Auto", "date": "2026-03-02", "odometer": 45000,
    "tax": 3.5, "total": 53.5, "currency": "CAD",
    "lineItems": [
      {"type": "Labour", "name": "Oil change", "quantity": 1, "unitCost": 40},
      {"type": "Part", "name": "Filter", "quantity": 2, "unitCost": 10},
      {"type": "Fee", "name": "Shop supplies", "quantity": 1, "unitCost": 2}
    ]
  }
  ''';

  test('parses a structured draft and sends the correct multipart request',
      () async {
    final (ex, adapter) = _make(200, okBody);
    final draft = await ex.extract(_image());

    // Draft parsing.
    expect(draft.source, ReceiptExtractorMode.cloudAi);
    expect(draft.shopName, 'Bob Auto');
    expect(draft.date, DateTime(2026, 3, 2));
    expect(draft.odometer, 45000);
    expect(draft.tax, 3.5);
    expect(draft.currency, 'CAD');
    expect(draft.lineItems.map((e) => e.type),
        [LineItemType.labour, LineItemType.part, LineItemType.fee]);
    expect(draft.lineItems[1].quantity, 2);

    // Request contract.
    final opts = adapter.captured!;
    expect(opts.path, '/receipts/extract');
    expect(opts.receiveTimeout, const Duration(seconds: 60));
    final form = opts.data as FormData;
    expect(form.files, hasLength(1));
    expect(form.files.first.key, 'file');
    expect(form.files.first.value.contentType?.mimeType, 'image/jpeg');
    expect(form.files.first.value.filename, 'receipt.jpg');
  });

  test('uploads a PDF with the pdf content type + filename', () async {
    final (ex, adapter) = _make(200, okBody);
    await ex.extract(_pdf());
    final form = adapter.captured!.data as FormData;
    expect(form.files.first.value.contentType?.mimeType, 'application/pdf');
    expect(form.files.first.value.filename, 'receipt.pdf');
  });

  test('decodes a JSON body served without an application/json content type',
      () async {
    final (ex, _) = _make(200, okBody, contentType: 'text/plain');
    final draft = await ex.extract(_image());
    expect(draft.shopName, 'Bob Auto');
  });

  test('empty object yields an all-null draft with no items', () async {
    final (ex, _) = _make(200, '{}');
    final draft = await ex.extract(_image());
    expect(draft.shopName, isNull);
    expect(draft.lineItems, isEmpty);
  });

  test('parses a PascalCase response body (serializer-casing tolerance)',
      () async {
    // Defense-in-depth: the backend should emit camelCase, but a PascalCase
    // regression (the bug that once shipped) must not silently blank the
    // extracted fields. Read either casing.
    const pascalBody = '''
    {
      "ShopName": "Bob Auto", "Date": "2026-03-02", "Odometer": 45000,
      "Tax": 3.5, "Total": 53.5, "Currency": "CAD",
      "LineItems": [
        {"Type": "Labour", "Name": "Oil change", "Quantity": 1, "UnitCost": 40},
        {"Type": "Part", "Name": "Filter", "Quantity": 2, "UnitCost": 10}
      ]
    }
    ''';
    final (ex, _) = _make(200, pascalBody);
    final draft = await ex.extract(_image());
    expect(draft.shopName, 'Bob Auto');
    expect(draft.date, DateTime(2026, 3, 2));
    expect(draft.odometer, 45000);
    expect(draft.tax, 3.5);
    expect(draft.lineItems, hasLength(2));
    expect(draft.lineItems.first.name, 'Oil change');
    expect(draft.lineItems.first.type, LineItemType.labour);
    expect(draft.lineItems[1].unitCost, 10);
  });

  test('tolerates mistyped fields and unknown line-item types', () async {
    // odometer as a string, lineItems present, an unknown type falls back.
    const body = '''
    {"odometer":"nope","lineItems":[{"type":"Bogus","name":"X","quantity":1}]}
    ''';
    final (ex, _) = _make(200, body);
    final draft = await ex.extract(_image());
    expect(draft.odometer, isNull);
    expect(draft.lineItems.single.type, LineItemType.part);
  });

  test('maps a 4xx error body to ReceiptExtractionException', () async {
    final (ex, _) = _make(400, '{"errors":["Receipt exceeds the 8 MB limit."]}');
    await expectLater(
      ex.extract(_image()),
      throwsA(isA<ReceiptExtractionException>()),
    );
  });

  test('maps a server error to ReceiptExtractionException', () async {
    final (ex, _) = _make(500, 'boom');
    await expectLater(
      ex.extract(_image()),
      throwsA(isA<ReceiptExtractionException>()),
    );
  });
}
