import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/adapters/anthropic_adapter.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';

typedef _Handler = FutureOr<ResponseBody> Function(RequestOptions o);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final _Handler handler;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200, Map<String, String>? h}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        for (final e in (h ?? {}).entries) e.key: [e.value],
      },
    );

LlmEngine _engine({
  String baseUrl = 'https://a/',
  StructuredOutput so = StructuredOutput.native,
}) => LlmEngine(
  id: 'e',
  label: 'E',
  kind: LlmEngineKind.anthropic,
  baseUrl: baseUrl,
  defaultModel: 'm',
  requiresKey: true,
  capabilities: LlmCapabilities(
    vision: true,
    pdf: true,
    streaming: true,
    structuredOutput: so,
  ),
);

const _ok = {
  'model': 'claude-x',
  'content': [
    {'type': 'text', 'text': 'hel'},
    {'type': 'text', 'text': 'lo'},
  ],
  'stop_reason': 'end_turn',
  'usage': {'input_tokens': 3, 'output_tokens': 5},
};

const _schema = LlmJsonSchema(name: 'out', schema: {'type': 'object'});

LlmRequest _req({
  String? system,
  List<LlmMessage>? messages,
  LlmJsonSchema? schema,
  double? temperature,
}) => LlmRequest(
  system: system,
  messages: messages ?? [LlmMessage.user('hi')],
  responseSchema: schema,
  temperature: temperature,
  containsSensitive: false,
);

void main() {
  late _FakeAdapter fake;
  late AnthropicAdapter adapter;

  void make(_Handler h) {
    fake = _FakeAdapter(h);
    adapter = AnthropicAdapter(Dio()..httpClientAdapter = fake);
  }

  Future<LlmResponse> run(
    LlmRequest r, {
    LlmEngine? engine,
    String? key = 'k',
    CancelToken? cancel,
  }) =>
      adapter.complete(engine ?? _engine(), key, r, model: 'm', cancel: cancel);

  Map<String, Object?> sent() => fake.last!.data as Map<String, Object?>;

  test('body golden with system top-level', () async {
    make((_) => _json(_ok));
    final res = await run(_req(system: 'sys', temperature: 0.2));
    expect(sent(), {
      'model': 'm',
      'max_tokens': 2048,
      'system': 'sys',
      'temperature': 0.2,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'hi'},
          ],
        },
      ],
    });
    expect(fake.last!.uri.toString(), 'https://a/v1/messages');
    expect(res.text, 'hello');
    expect(res.stopReason, LlmStopReason.end);
    expect(res.usage, const LlmUsage(inputTokens: 3, outputTokens: 5));
    expect(res.model, 'claude-x');
  });

  test('image and document blocks', () async {
    make((_) => _json(_ok));
    await run(
      _req(
        messages: [
          LlmMessage(
            role: LlmRole.user,
            parts: [
              ImagePart(Uint8List.fromList([1, 2, 3]), 'image/png'),
              DocumentPart(Uint8List.fromList([1, 2, 3])),
            ],
          ),
        ],
      ),
    );
    final content = (sent()['messages'] as List).first['content'] as List;
    expect(content, [
      {
        'type': 'image',
        'source': {'type': 'base64', 'media_type': 'image/png', 'data': 'AQID'},
      },
      {
        'type': 'document',
        'source': {
          'type': 'base64',
          'media_type': 'application/pdf',
          'data': 'AQID',
        },
      },
    ]);
  });

  test('schema becomes forced tool', () async {
    make((_) => _json(_ok));
    await run(_req(schema: _schema));
    expect(sent()['tools'], [
      {
        'name': 'out',
        'description': 'Return the result.',
        'input_schema': {'type': 'object'},
      },
    ]);
    expect(sent()['tool_choice'], {'type': 'tool', 'name': 'out'});
  });

  test('schema with structuredOutput none is unsupported', () async {
    make((_) => _json(_ok));
    await expectLater(
      run(
        _req(schema: _schema),
        engine: _engine(so: StructuredOutput.none),
      ),
      throwsA(
        isA<LlmUnsupported>().having(
          (e) => e.capability,
          'capability',
          LlmCapability.structuredOutput,
        ),
      ),
    );
  });

  test('tool_use input returned as JSON text', () async {
    make(
      (_) => _json({
        'content': [
          {
            'type': 'tool_use',
            'id': 't',
            'name': 'out',
            'input': {'a': 1},
          },
        ],
        'stop_reason': 'tool_use',
      }),
    );
    final res = await run(_req(schema: _schema));
    expect(jsonDecode(res.text), {'a': 1});
    expect(res.stopReason, LlmStopReason.end);
  });

  test('headers carry key and version, no Authorization', () async {
    make((_) => _json(_ok));
    await run(_req());
    final h = fake.last!.headers;
    expect(h['x-api-key'], 'k');
    expect(h['anthropic-version'], '2023-06-01');
    expect(h['content-type'], 'application/json');
    expect(
      h.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
  });

  test('stop reasons', () async {
    for (final (sr, want) in [
      ('stop_sequence', LlmStopReason.end),
      ('max_tokens', LlmStopReason.maxTokens),
      ('refusal', LlmStopReason.refused),
    ]) {
      make(
        (_) => _json({
          'content': [
            {'type': 'text', 'text': 'x'},
          ],
          'stop_reason': sr,
        }),
      );
      expect((await run(_req())).stopReason, want);
    }
  });

  test('tool part throws LlmUnsupported(tools)', () async {
    make((_) => _json(_ok));
    await expectLater(
      run(
        _req(
          messages: [
            const LlmMessage(
              role: LlmRole.assistant,
              parts: [ToolCallPart('1', 'f', '{}')],
            ),
          ],
        ),
      ),
      throwsA(
        isA<LlmUnsupported>().having(
          (e) => e.capability,
          'capability',
          LlmCapability.tools,
        ),
      ),
    );
  });

  group('errors', () {
    Future<void> expectErr<T extends LlmException>(_Handler h) async {
      make(h);
      await expectLater(run(_req()), throwsA(isA<T>()));
    }

    test('401', () => expectErr<LlmInvalidKey>((_) => _json({}, status: 401)));
    test('403', () => expectErr<LlmInvalidKey>((_) => _json({}, status: 403)));
    test('429 rate with Retry-After', () async {
      make((_) => _json({}, status: 429, h: {'retry-after': '7'}));
      await expectLater(
        run(_req()),
        throwsA(
          isA<LlmRateLimited>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 7),
          ),
        ),
      );
    });
    test('529', () => expectErr<LlmUnreachable>((_) => _json({}, status: 529)));
    test('500', () => expectErr<LlmUnreachable>((_) => _json({}, status: 500)));
    test(
      '400 credit balance',
      () => expectErr<LlmQuotaExceeded>(
        (_) => _json({
          'type': 'error',
          'error': {
            'type': 'invalid_request_error',
            'message': 'Your credit balance is too low',
          },
        }, status: 400),
      ),
    );
    test(
      '400 other is bad response',
      () => expectErr<LlmBadResponse>(
        (_) => _json({
          'error': {'message': 'nope'},
        }, status: 400),
      ),
    );
    test(
      'timeout',
      () => expectErr<LlmTimeout>(
        (o) => throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: o,
        ),
      ),
    );
    test(
      'connection error',
      () => expectErr<LlmUnreachable>(
        (o) =>
            throw DioException.connectionError(requestOptions: o, reason: 'x'),
      ),
    );
    test('malformed body', () async {
      make((_) => _json({'nope': 1}));
      await expectLater(run(_req()), throwsA(isA<LlmBadResponse>()));
    });
    test('cancel', () async {
      make((_) => _json(_ok));
      final token = CancelToken()..cancel();
      await expectLater(
        run(_req(), cancel: token),
        throwsA(isA<LlmCancelled>()),
      );
    });
  });

  group('stream', () {
    ResponseBody sse(Stream<List<int>> s) => ResponseBody(
      s.map((c) => Uint8List.fromList(c)),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );

    List<int> ev(String type, Object o) =>
        utf8.encode('event: $type\ndata: ${jsonEncode(o)}\n\n');

    Future<(List<LlmEvent>, Object?)> collect(LlmRequest r) async {
      final seen = <LlmEvent>[];
      Object? error;
      try {
        await for (final e in adapter.stream(_engine(), 'k', r, model: 'm')) {
          seen.add(e);
        }
      } catch (e) {
        error = e;
      }
      return (seen, error);
    }

    final start = ev('message_start', {
      'type': 'message_start',
      'message': {
        'model': 'claude-x',
        'usage': {'input_tokens': 2, 'output_tokens': 1},
      },
    });
    List<int> delta(String t) => ev('content_block_delta', {
      'type': 'content_block_delta',
      'index': 0,
      'delta': {'type': 'text_delta', 'text': t},
    });
    List<int> mdelta(String sr) => ev('message_delta', {
      'type': 'message_delta',
      'delta': {'stop_reason': sr},
      'usage': {'output_tokens': 4},
    });
    final stop = ev('message_stop', {'type': 'message_stop'});

    test('text deltas then Completed', () async {
      make(
        (_) => sse(
          Stream.fromIterable([
            start,
            utf8.encode('event: ping\n\n'),
            delta('Hel'),
            delta('lo'),
            mdelta('end_turn'),
            stop,
          ]),
        ),
      );
      final (events, error) = await collect(_req());
      expect(error, isNull);
      expect(sent()['stream'], true);
      expect(events, [
        const TextDelta('Hel'),
        const TextDelta('lo'),
        const Completed(
          LlmResponse(
            text: 'Hello',
            stopReason: LlmStopReason.end,
            usage: LlmUsage(inputTokens: 2, outputTokens: 4),
            model: 'claude-x',
          ),
        ),
      ]);
    });

    test('accumulates input_json_delta into Completed text', () async {
      List<int> j(String p) => ev('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'input_json_delta', 'partial_json': p},
      });
      make(
        (_) => sse(
          Stream.fromIterable([
            start,
            j('{"a":'),
            j('1}'),
            mdelta('tool_use'),
            stop,
          ]),
        ),
      );
      final (events, error) = await collect(_req(schema: _schema));
      expect(error, isNull);
      expect(events, hasLength(1));
      final done = (events.single as Completed).response;
      expect(done.text, '{"a":1}');
      expect(done.stopReason, LlmStopReason.end);
    });

    test('error event maps exception', () async {
      make(
        (_) => sse(
          Stream.fromIterable([
            start,
            ev('error', {
              'type': 'error',
              'error': {'type': 'overloaded_error', 'message': 'busy'},
            }),
          ]),
        ),
      );
      final (_, error) = await collect(_req());
      expect(error, isA<LlmUnreachable>());
    });

    test('dropped stream errors', () async {
      make((_) {
        Stream<List<int>> body() async* {
          yield start;
          yield delta('Hel');
          throw const SocketException('reset');
        }

        return sse(body());
      });
      final (seen, error) = await collect(_req());
      expect(seen, [const TextDelta('Hel')]);
      expect(error, isA<LlmUnreachable>());
    });

    test('clean close without message_stop is unreachable', () async {
      make(
        (_) =>
            sse(Stream.fromIterable([start, delta('Hel'), mdelta('end_turn')])),
      );
      final (seen, error) = await collect(_req());
      expect(seen, [const TextDelta('Hel')]);
      expect(error, isA<LlmUnreachable>());
    });

    test('stream HTTP error maps status', () async {
      make((_) => _json({}, status: 401));
      final (_, error) = await collect(_req());
      expect(error, isA<LlmInvalidKey>());
    });
  });
}
