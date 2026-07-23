import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/receipt_scan/data/api_llm_extractor.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

class _TrackingAdapter implements HttpClientAdapter {
  _TrackingAdapter();
  bool posted = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    posted = true;
    return ResponseBody.fromString('{}', 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('sensitive input is rejected before any upload', () async {
    final adapter = _TrackingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/v1'))
      ..httpClientAdapter = adapter;
    final extractor = ApiLlmExtractor(ApiClient(dio));

    await expectLater(
      extractor.extract(ReceiptInput(
        bytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
        sensitive: true,
      )),
      throwsA(isA<ReceiptExtractionException>()),
    );
    expect(adapter.posted, isFalse, reason: 'must not reach the network');
  });
}
