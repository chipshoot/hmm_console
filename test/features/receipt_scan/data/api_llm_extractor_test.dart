import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/automobile_records/domain/entities/line_item_type.dart';
import 'package:hmm_console/features/receipt_scan/data/api_llm_extractor.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiLlmExtractor _extractor(int status, String body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/v1'))
    ..httpClientAdapter = _FakeAdapter(status, body);
  return ApiLlmExtractor(ApiClient(dio));
}

ReceiptInput _input() =>
    ReceiptInput(bytes: Uint8List.fromList([1, 2, 3]), contentType: 'image/jpeg');

void main() {
  test('parses a structured draft from the API response', () async {
    const body = '''
    {
      "shopName": "Bob Auto",
      "date": "2026-03-02",
      "odometer": 45000,
      "tax": 3.5,
      "total": 53.5,
      "currency": "CAD",
      "lineItems": [
        {"type": "Labour", "name": "Oil change", "quantity": 1, "unitCost": 40},
        {"type": "Part", "name": "Filter", "quantity": 2, "unitCost": 10}
      ]
    }
    ''';
    final draft = await _extractor(200, body).extract(_input());

    expect(draft.source, ReceiptExtractorMode.cloudAi);
    expect(draft.shopName, 'Bob Auto');
    expect(draft.date, DateTime(2026, 3, 2));
    expect(draft.odometer, 45000);
    expect(draft.tax, 3.5);
    expect(draft.currency, 'CAD');
    expect(draft.lineItems, hasLength(2));
    expect(draft.lineItems[0].type, LineItemType.labour);
    expect(draft.lineItems[1].type, LineItemType.part);
    expect(draft.lineItems[1].quantity, 2);
  });

  test('maps an error response to ReceiptExtractionException', () async {
    final ex = _extractor(400, '{"errors":["Receipt exceeds the 8 MB limit."]}');
    expect(
      () => ex.extract(_input()),
      throwsA(isA<ReceiptExtractionException>()),
    );
  });

  test('maps a server error to ReceiptExtractionException', () async {
    final ex = _extractor(500, 'boom');
    expect(
      () => ex.extract(_input()),
      throwsA(isA<ReceiptExtractionException>()),
    );
  });
}
