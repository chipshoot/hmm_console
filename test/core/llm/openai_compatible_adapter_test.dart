import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/adapters/llm_adapter.dart';
import 'package:hmm_console/core/llm/adapters/openai_compatible_adapter.dart';
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
  LlmEngineKind kind = LlmEngineKind.openai,
  String baseUrl = 'https://h/v1',
  StructuredOutput so = StructuredOutput.native,
}) => LlmEngine(
  id: 'e',
  label: 'E',
  kind: kind,
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
  'model': 'gpt-x',
  'choices': [
    {
      'message': {'role': 'assistant', 'content': 'hello'},
      'finish_reason': 'stop',
    },
  ],
  'usage': {'prompt_tokens': 3, 'completion_tokens': 5},
};

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
  late OpenAiCompatibleAdapter adapter;

  OpenAiCompatibleAdapter make(_Handler h) {
    fake = _FakeAdapter(h);
    return adapter = OpenAiCompatibleAdapter(Dio()..httpClientAdapter = fake);
  }

  Future<LlmResponse> run(
    LlmRequest r, {
    LlmEngine? engine,
    String? key = 'k',
    CancelToken? cancel,
  }) =>
      adapter.complete(engine ?? _engine(), key, r, model: 'm', cancel: cancel);

  Map<String, Object?> sent() => fake.last!.data as Map<String, Object?>;

  test('text request body golden', () async {
    make((_) => _json(_ok));
    final res = await run(_req(system: 'sys', temperature: 0.2));
    expect(sent(), {
      'model': 'm',
      'messages': [
        {'role': 'system', 'content': 'sys'},
        {'role': 'user', 'content': 'hi'},
      ],
      'max_completion_tokens': 2048,
      'temperature': 0.2,
    });
    expect(res.text, 'hello');
    expect(res.stopReason, LlmStopReason.end);
    expect(res.usage, const LlmUsage(inputTokens: 3, outputTokens: 5));
    expect(res.model, 'gpt-x');
    expect(fake.last!.headers['Authorization'], 'Bearer k');
  });

  test('image part encodes data URL', () async {
    make((_) => _json(_ok));
    await run(
      _req(
        messages: [
          LlmMessage(
            role: LlmRole.user,
            parts: [
              const TextPart('see'),
              ImagePart(Uint8List.fromList([1, 2, 3]), 'image/png'),
            ],
          ),
        ],
      ),
    );
    final content = (sent()['messages'] as List).first['content'] as List;
    expect(content, [
      {'type': 'text', 'text': 'see'},
      {
        'type': 'image_url',
        'image_url': {'url': 'data:image/png;base64,AQID'},
      },
    ]);
  });

  test('pdf part uses file content', () async {
    make((_) => _json(_ok));
    await run(
      _req(
        messages: [
          LlmMessage(
            role: LlmRole.user,
            parts: [
              DocumentPart(Uint8List.fromList([1, 2, 3])),
            ],
          ),
        ],
      ),
    );
    final content = (sent()['messages'] as List).first['content'] as List;
    expect(content.single, {
      'type': 'file',
      'file': {
        'filename': 'document.pdf',
        'file_data': 'data:application/pdf;base64,AQID',
      },
    });
  });

  test('native schema sets response_format strict', () async {
    make((_) => _json(_ok));
    await run(
      _req(
        schema: const LlmJsonSchema(name: 's', schema: {'type': 'object'}),
      ),
    );
    expect(sent()['response_format'], {
      'type': 'json_schema',
      'json_schema': {
        'name': 's',
        'schema': {'type': 'object'},
        'strict': true,
      },
    });
  });

  test('jsonMode adds json_object and schema to system', () async {
    make((_) => _json(_ok));
    await run(
      _req(
        system: 'sys',
        schema: const LlmJsonSchema(name: 's', schema: {'type': 'object'}),
      ),
      engine: _engine(so: StructuredOutput.jsonMode),
    );
    expect(sent()['response_format'], {'type': 'json_object'});
    final sys = (sent()['messages'] as List).first['content'] as String;
    expect(sys, startsWith('sys'));
    expect(
      sys,
      contains('Respond with JSON matching this schema: {"type":"object"}'),
    );
  });

  test('no Authorization header when key null', () async {
    make((_) => _json(_ok));
    await run(_req(), key: null);
    expect(fake.last!.headers.containsKey('Authorization'), isFalse);
  });

  test('joins base URL without double slash', () async {
    make((_) => _json(_ok));
    await run(_req(), engine: _engine(baseUrl: 'https://h/v1/'));
    expect(fake.last!.uri.toString(), 'https://h/v1/chat/completions');
    expect(
      joinUrl('https://h/v1', '/chat/completions').toString(),
      'https://h/v1/chat/completions',
    );
  });

  test('maps finish reasons', () async {
    for (final (fr, want) in [
      ('length', LlmStopReason.maxTokens),
      ('content_filter', LlmStopReason.refused),
    ]) {
      make(
        (_) => _json({
          'choices': [
            {
              'message': {'content': 'x'},
              'finish_reason': fr,
            },
          ],
        }),
      );
      expect((await run(_req())).stopReason, want);
    }
  });

  test('openai engine sends max_completion_tokens, not max_tokens', () async {
    make((_) => _json(_ok));
    await run(_req());
    expect(sent()['max_completion_tokens'], 2048);
    expect(sent().containsKey('max_tokens'), isFalse);
  });

  test('deepseek and custom engines send max_tokens', () async {
    for (final k in [LlmEngineKind.deepseek, LlmEngineKind.custom]) {
      make((_) => _json(_ok));
      await run(_req(), engine: _engine(kind: k));
      expect(sent()['max_tokens'], 2048);
      expect(sent().containsKey('max_completion_tokens'), isFalse);
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
    test(
      '429 quota',
      () => expectErr<LlmQuotaExceeded>(
        (_) => _json({
          'error': {'code': 'insufficient_quota'},
        }, status: 429),
      ),
    );
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
    test('404', () => expectErr<LlmNotFound>((_) => _json({}, status: 404)));
    test('413', () => expectErr<LlmTooLarge>((_) => _json({}, status: 413)));
    test('refusal field is a refusal, not malformed', () async {
      make(
        (_) => _json({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': null,
                'refusal': 'no',
              },
              'finish_reason': 'stop',
            },
          ],
        }),
      );
      final r = await run(_req());
      expect(r.stopReason, LlmStopReason.refused);
      expect(r.text, '');
    });
    test('503', () => expectErr<LlmUnreachable>((_) => _json({}, status: 503)));
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
      await expectLater(
        run(_req()),
        throwsA(
          isA<LlmBadResponse>().having(
            (e) => e.detail,
            'detail',
            'openai: malformed',
          ),
        ),
      );
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

    String ev(Object o) => 'data: ${jsonEncode(o)}\n\n';

    test('yields deltas then Completed with usage', () async {
      make(
        (_) => sse(
          Stream.fromIterable([
            utf8.encode(
              ev({
                'model': 'gpt-x',
                'choices': [
                  {
                    'delta': {'content': 'Hel'},
                  },
                ],
              }),
            ),
            utf8.encode(
              ev({
                'choices': [
                  {
                    'delta': {'content': 'lo'},
                    'finish_reason': 'stop',
                  },
                ],
              }),
            ),
            utf8.encode(
              ev({
                'choices': [],
                'usage': {'prompt_tokens': 2, 'completion_tokens': 4},
              }),
            ),
            utf8.encode('data: [DONE]\n\n'),
          ]),
        ),
      );
      final events = await adapter
          .stream(_engine(), 'k', _req(), model: 'm')
          .toList();
      expect(sent()['stream'], true);
      expect(sent()['stream_options'], {'include_usage': true});
      expect(events, [
        const TextDelta('Hel'),
        const TextDelta('lo'),
        const Completed(
          LlmResponse(
            text: 'Hello',
            stopReason: LlmStopReason.end,
            usage: LlmUsage(inputTokens: 2, outputTokens: 4),
            model: 'gpt-x',
          ),
        ),
      ]);
    });

    test('dropped stream errors', () async {
      make((_) {
        Stream<List<int>> body() async* {
          yield utf8.encode(
            ev({
              'choices': [
                {
                  'delta': {'content': 'Hel'},
                },
              ],
            }),
          );
          throw const SocketException('reset');
        }

        return sse(body());
      });
      final seen = <LlmEvent>[];
      Object? error;
      try {
        await for (final e in adapter.stream(
          _engine(),
          'k',
          _req(),
          model: 'm',
        )) {
          seen.add(e);
        }
      } catch (e) {
        error = e;
      }
      expect(seen, [const TextDelta('Hel')]);
      expect(error, isA<LlmUnreachable>());
    });

    test('clean close without DONE or finish_reason is unreachable', () async {
      make(
        (_) => sse(
          Stream.fromIterable([
            utf8.encode(
              ev({
                'choices': [
                  {
                    'delta': {'content': 'Hel'},
                  },
                ],
              }),
            ),
          ]),
        ),
      );
      final seen = <LlmEvent>[];
      Object? error;
      try {
        await for (final e in adapter.stream(
          _engine(),
          'k',
          _req(),
          model: 'm',
        )) {
          seen.add(e);
        }
      } catch (e) {
        error = e;
      }
      expect(seen, [const TextDelta('Hel')]);
      expect(error, isA<LlmUnreachable>());
    });

    test('event with empty data is skipped', () async {
      make(
        (_) => sse(
          Stream.fromIterable([
            utf8.encode('event: ping\n\n'),
            utf8.encode(
              ev({
                'choices': [
                  {
                    'delta': {'content': 'A'},
                    'finish_reason': 'stop',
                  },
                ],
              }),
            ),
          ]),
        ),
      );
      final events = await adapter
          .stream(_engine(), 'k', _req(), model: 'm')
          .toList();
      expect(events.first, const TextDelta('A'));
      expect((events.last as Completed).response.text, 'A');
    });

    test('stream HTTP error maps status', () async {
      make(
        (_) => ResponseBody.fromString(
          jsonEncode({
            'error': {'code': 'insufficient_quota'},
          }),
          429,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await expectLater(
        adapter.stream(_engine(), 'k', _req(), model: 'm').toList(),
        throwsA(isA<LlmQuotaExceeded>()),
      );
    });
  });
}
