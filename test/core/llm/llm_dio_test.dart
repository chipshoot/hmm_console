import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/llm_dio.dart';

class _Ok implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"secret":"BODYSECRET"}',
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('llm dio has no auth interceptor and logs no headers', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(llmDioProvider);
    expect(dio.interceptors.whereType<InterceptorsWrapper>(), isEmpty);
    expect(
      dio.interceptors.map((i) => i.runtimeType.toString()),
      everyElement(isNot(contains('Auth'))),
    );
    expect(dio.options.connectTimeout, const Duration(seconds: 15));
    expect(dio.options.receiveTimeout, const Duration(seconds: 120));

    dio.httpClientAdapter = _Ok();
    final lines = <String>[];
    final old = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => lines.add(m ?? '');
    addTearDown(() => debugPrint = old);

    await dio.post<Object?>(
      'https://api.example.com/v1/chat?q=URLSECRET',
      data: {'prompt': 'PROMPTSECRET'},
      options: Options(
        headers: {'x-api-key': 'SECRET', 'Authorization': 'Bearer SECRET'},
      ),
    );

    final out = lines.join('\n');
    expect(lines, isNotEmpty);
    expect(out, contains('POST'));
    expect(out, contains('api.example.com'));
    expect(out, contains('200'));
    for (final s in ['SECRET', 'PROMPTSECRET', 'BODYSECRET', 'URLSECRET']) {
      expect(out, isNot(contains(s)));
    }
  });
}
