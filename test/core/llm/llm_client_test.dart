import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/adapters/llm_adapter.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/engines/llm_engine_registry.dart';
import 'package:hmm_console/core/llm/llm_client.dart';
import 'package:hmm_console/core/llm/llm_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Keys extends LlmKeyStore {
  _Keys();
  String? key = 'sk';
  bool consent = true;
  String? hostSeen;
  int reads = 0;
  int consentChecks = 0;
  @override
  Future<String?> readKey(String id) async {
    reads++;
    return key;
  }

  @override
  Future<void> sweepOrphans(Set<String> liveIds) async {}

  @override
  Future<bool> hasConsent(String id, String host) async {
    hostSeen = host;
    consentChecks++;
    return consent;
  }
}

class _Adapter implements LlmAdapter {
  _Adapter(this.format);
  @override
  final WireFormat format;
  final replies = <Object>[]; // LlmResponse or LlmException
  final requests = <LlmRequest>[];
  final keysSeen = <String?>[];
  final modelsSeen = <String>[];

  @override
  Future<LlmResponse> complete(
    LlmEngine engine,
    String? key,
    LlmRequest request, {
    required String model,
    CancelToken? cancel,
  }) async {
    requests.add(request);
    keysSeen.add(key);
    modelsSeen.add(model);
    final r = replies.removeAt(0);
    if (r is LlmException) throw r;
    return r as LlmResponse;
  }

  @override
  Stream<LlmEvent> stream(
    LlmEngine engine,
    String? key,
    LlmRequest request, {
    required String model,
    CancelToken? cancel,
  }) async* {
    requests.add(request);
    keysSeen.add(key);
    for (final r in replies) {
      yield r as LlmEvent;
    }
  }
}

LlmResponse _ok(String text) =>
    LlmResponse(text: text, stopReason: LlmStopReason.end);

LlmEngine _engine(
  String id, {
  LlmEngineKind kind = LlmEngineKind.openai,
  bool vision = true,
  bool pdf = true,
  bool streaming = true,
  StructuredOutput so = StructuredOutput.native,
  bool requiresKey = true,
}) => LlmEngine(
  id: id,
  label: 'L-$id',
  kind: kind,
  baseUrl: 'https://x',
  defaultModel: 'm-$id',
  requiresKey: requiresKey,
  capabilities: LlmCapabilities(
    vision: vision,
    pdf: pdf,
    streaming: streaming,
    structuredOutput: so,
  ),
);

LlmRequest _req({
  bool sensitive = false,
  LlmJsonSchema? schema,
  List<LlmMessage>? messages,
}) => LlmRequest(
  messages: messages ?? [LlmMessage.user('hi')],
  containsSensitive: sensitive,
  responseSchema: schema,
);

const _schema = LlmJsonSchema(
  name: 's',
  schema: {
    'type': 'object',
    'required': ['a'],
    'properties': {
      'a': {'type': 'integer'},
    },
  },
);

void main() {
  late _Keys keys;
  late _Adapter openai;
  late _Adapter anthropic;
  late LlmEngineSettings settings;
  late int settingsCalls;
  late List<Duration> delays;

  LlmClient client() => LlmClient(
    settings: () async {
      settingsCalls++;
      return settings;
    },
    keys: keys,
    adapters: {
      WireFormat.openAiCompatible: openai,
      WireFormat.anthropic: anthropic,
    },
    delay: (d) async => delays.add(d),
  );

  setUp(() {
    keys = _Keys();
    openai = _Adapter(WireFormat.openAiCompatible);
    anthropic = _Adapter(WireFormat.anthropic);
    settingsCalls = 0;
    delays = [];
    settings = LlmEngineSettings(
      engines: [_engine('a')],
      defaultId: 'a',
      routes: const {},
    );
  });

  test('sensitive refused before settings or key read', () async {
    await expectLater(
      client().complete(_req(sensitive: true)),
      throwsA(isA<LlmSensitiveRefused>()),
    );
    expect(settingsCalls, 0);
    expect(keys.reads, 0);
    expect(keys.consentChecks, 0);
    expect(openai.requests, isEmpty);
  });

  test('no engine -> key missing without label', () async {
    settings = LlmEngineSettings.empty;
    await expectLater(
      client().complete(_req()),
      throwsA(
        isA<LlmKeyMissing>().having((e) => e.engineLabel, 'label', isNull),
      ),
    );
  });

  test('consent required', () async {
    keys.consent = false;
    await expectLater(
      client().complete(_req()),
      throwsA(isA<LlmConsentRequired>()),
    );
    expect(openai.requests, isEmpty);
  });

  test('image to non-vision engine unsupported', () async {
    settings = LlmEngineSettings(
      engines: [_engine('a', vision: false)],
      defaultId: 'a',
      routes: const {},
    );
    final r = _req(
      messages: [
        LlmMessage(
          role: LlmRole.user,
          parts: [
            ImagePart(Uint8List.fromList([1]), 'image/png'),
          ],
        ),
      ],
    );
    await expectLater(
      client().complete(r),
      throwsA(
        isA<LlmUnsupported>().having(
          (e) => e.capability,
          'cap',
          LlmCapability.vision,
        ),
      ),
    );
  });

  test('pdf to non-pdf engine unsupported', () async {
    settings = LlmEngineSettings(
      engines: [_engine('a', pdf: false)],
      defaultId: 'a',
      routes: const {},
    );
    final r = _req(
      messages: [
        LlmMessage(
          role: LlmRole.user,
          parts: [
            DocumentPart(Uint8List.fromList([1])),
          ],
        ),
      ],
    );
    await expectLater(
      client().complete(r),
      throwsA(
        isA<LlmUnsupported>().having(
          (e) => e.capability,
          'cap',
          LlmCapability.pdf,
        ),
      ),
    );
  });

  test(
    'schema with structuredOutput none unsupported; stream needs streaming',
    () async {
      settings = LlmEngineSettings(
        engines: [_engine('a', so: StructuredOutput.none, streaming: false)],
        defaultId: 'a',
        routes: const {},
      );
      await expectLater(
        client().complete(_req(schema: _schema)),
        throwsA(
          isA<LlmUnsupported>().having(
            (e) => e.capability,
            'cap',
            LlmCapability.structuredOutput,
          ),
        ),
      );
      await expectLater(
        client().stream(_req()).toList(),
        throwsA(
          isA<LlmUnsupported>().having(
            (e) => e.capability,
            'cap',
            LlmCapability.streaming,
          ),
        ),
      );
    },
  );

  test('missing key when requiresKey', () async {
    keys.key = null;
    await expectLater(
      client().complete(_req()),
      throwsA(
        isA<LlmKeyMissing>().having((e) => e.engineLabel, 'label', 'L-a'),
      ),
    );
    expect(openai.requests, isEmpty);
  });

  test('keyless engine sends null key', () async {
    settings = LlmEngineSettings(
      engines: [_engine('a', requiresKey: false)],
      defaultId: 'a',
      routes: const {},
    );
    keys.key = null;
    openai.replies.add(_ok('hello'));
    final r = await client().complete(_req());
    expect(r.text, 'hello');
    expect(openai.keysSeen, [null]);
    expect(openai.modelsSeen, ['m-a']);
  });

  test(
    'anthropic engine uses the anthropic adapter and request model',
    () async {
      settings = LlmEngineSettings(
        engines: [_engine('a', kind: LlmEngineKind.anthropic)],
        defaultId: 'a',
        routes: const {},
      );
      anthropic.replies.add(_ok('x'));
      await client().complete(
        LlmRequest(
          messages: [LlmMessage.user('hi')],
          containsSensitive: false,
          model: 'custom',
        ),
      );
      expect(anthropic.modelsSeen, ['custom']);
      expect(openai.requests, isEmpty);
    },
  );

  test('engine label attached to adapter errors', () async {
    openai.replies.add(const LlmInvalidKey());
    await expectLater(
      client().complete(_req()),
      throwsA(
        isA<LlmInvalidKey>().having((e) => e.engineLabel, 'label', 'L-a'),
      ),
    );
  });

  test('retries once on short rate limit, not on long', () async {
    openai.replies
      ..add(const LlmRateLimited(retryAfter: Duration(seconds: 3)))
      ..add(_ok('fine'));
    final r = await client().complete(_req());
    expect(r.text, 'fine');
    expect(delays, [const Duration(seconds: 3)]);
    expect(openai.requests, hasLength(2));

    openai.requests.clear();
    delays.clear();
    openai.replies.add(const LlmRateLimited(retryAfter: Duration(seconds: 30)));
    await expectLater(
      client().complete(_req()),
      throwsA(isA<LlmRateLimited>()),
    );
    expect(delays, isEmpty);
    expect(openai.requests, hasLength(1));

    // A second rate limit after the single retry propagates.
    openai.requests.clear();
    openai.replies
      ..add(const LlmRateLimited(retryAfter: Duration(seconds: 1)))
      ..add(const LlmRateLimited(retryAfter: Duration(seconds: 1)));
    await expectLater(
      client().complete(_req()),
      throwsA(
        isA<LlmRateLimited>().having((e) => e.engineLabel, 'label', 'L-a'),
      ),
    );
    expect(openai.requests, hasLength(2));
  });

  test('validates schema and sets json', () async {
    openai.replies.add(_ok('{"a": 1}'));
    final r = await client().complete(_req(schema: _schema));
    expect(r.json, {'a': 1});
    expect(r.text, '{"a": 1}');
  });

  test('strips code fences in jsonMode', () async {
    openai.replies.add(_ok('```json\n{"a": 2}\n```'));
    final r = await client().complete(_req(schema: _schema));
    expect(r.json, {'a': 2});
    openai.replies.add(_ok('```\n{"a": 3}\n```'));
    final r2 = await client().complete(_req(schema: _schema));
    expect(r2.json, {'a': 3});
  });

  test('retries once on invalid JSON with a corrective message', () async {
    openai.replies
      ..add(_ok('not json'))
      ..add(_ok('{"a": 4}'));
    final r = await client().complete(_req(schema: _schema));
    expect(r.json, {'a': 4});
    expect(openai.requests, hasLength(2));
    final extra = openai.requests[1].messages.last;
    expect(extra.role, LlmRole.user);
    expect(
      (extra.parts.single as TextPart).text,
      startsWith('Your previous reply was invalid: '),
    );
    expect(
      (extra.parts.single as TextPart).text,
      endsWith('Reply again with only valid JSON.'),
    );
  });

  test('invalid twice -> badResponse schema', () async {
    openai.replies
      ..add(_ok('{"a": "x"}'))
      ..add(_ok('{}'));
    await expectLater(
      client().complete(_req(schema: _schema)),
      throwsA(
        isA<LlmBadResponse>()
            .having((e) => e.detail, 'detail', 'schema')
            .having((e) => e.engineLabel, 'label', 'L-a'),
      ),
    );
    expect(openai.requests, hasLength(2));
  });

  test('purpose route used', () async {
    settings = LlmEngineSettings(
      engines: [
        _engine('a'),
        _engine('b', kind: LlmEngineKind.anthropic),
      ],
      defaultId: 'a',
      routes: const {'receipts': 'b'},
    );
    anthropic.replies.add(_ok('x'));
    await client().complete(_req(), purpose: 'receipts');
    expect(anthropic.requests, hasLength(1));
    expect(openai.requests, isEmpty);
  });

  test('stream validates schema on Completed', () async {
    openai.replies
      ..add(const TextDelta('{"a":1}'))
      ..add(Completed(_ok('{"a":1}')));
    final events = await client().stream(_req(schema: _schema)).toList();
    expect(events.last, isA<Completed>());
    expect((events.last as Completed).response.json, {'a': 1});

    openai.replies
      ..clear()
      ..add(Completed(_ok('{"a":"bad"}')));
    await expectLater(
      client().stream(_req(schema: _schema)).toList(),
      throwsA(isA<LlmBadResponse>()),
    );
  });

  test('stream sensitive refused before settings', () async {
    await expectLater(
      client().stream(_req(sensitive: true)).toList(),
      throwsA(isA<LlmSensitiveRefused>()),
    );
    expect(settingsCalls, 0);
  });

  test(
    'refused stop reason throws LlmRefused without a schema retry',
    () async {
      openai.replies.add(
        const LlmResponse(text: '', stopReason: LlmStopReason.refused),
      );
      await expectLater(
        client().complete(_req(schema: _schema)),
        throwsA(isA<LlmRefused>().having((e) => e.engineLabel, 'label', 'L-a')),
      );
      expect(openai.requests, hasLength(1));
    },
  );

  test('maxTokens with a schema is truncated, no retry', () async {
    openai.replies.add(
      const LlmResponse(text: '{"a":', stopReason: LlmStopReason.maxTokens),
    );
    await expectLater(
      client().complete(_req(schema: _schema)),
      throwsA(
        isA<LlmBadResponse>().having((e) => e.detail, 'detail', 'truncated'),
      ),
    );
    expect(openai.requests, hasLength(1));
  });

  test('consent is checked against the engine host', () async {
    openai.replies.add(_ok('x'));
    await client().complete(_req());
    expect(keys.hostSeen, 'x');
  });

  test('testConnection skips consent', () async {
    keys.consent = false;
    openai.replies.add(_ok('OK'));
    await client().testConnection(_engine('a'), 'typed-key');
    expect(keys.consentChecks, 0);
    expect(keys.reads, 0);
    expect(openai.keysSeen, ['typed-key']);
    final r = openai.requests.single;
    expect(r.maxTokens, 16);
    expect(r.containsSensitive, isFalse);
    expect((r.messages.single.parts.single as TextPart).text, 'Reply with OK.');
  });

  test('testConnection labels errors', () async {
    openai.replies.add(const LlmInvalidKey());
    await expectLater(
      client().testConnection(_engine('a'), 'k'),
      throwsA(
        isA<LlmInvalidKey>().having((e) => e.engineLabel, 'label', 'L-a'),
      ),
    );
  });

  group('provider wiring', () {
    test('call before settings load still finds the engine', () async {
      SharedPreferences.setMockInitialValues({
        'ai.engines': jsonEncode([_engine('a').toJson()]),
        'ai.default': 'a',
      });
      final c = ProviderContainer(
        overrides: [llmKeyStoreProvider.overrideWithValue(_Keys())],
      );
      addTearDown(c.dispose);
      // Nothing has loaded yet: the state is still the empty default.
      final notifier = c.read(llmEngineSettingsProvider.notifier);
      expect(c.read(llmEngineSettingsProvider).engines, isEmpty);
      final fresh = LlmClient(
        settings: () async {
          await notifier.ready;
          return c.read(llmEngineSettingsProvider);
        },
        keys: _Keys(),
        adapters: {WireFormat.openAiCompatible: openai},
      );
      openai.replies.add(_ok('hi'));
      final r = await fresh.complete(_req());
      expect(r.text, 'hi');
    });

    test('ready completes even when settings are unreadable', () async {
      SharedPreferences.setMockInitialValues({'ai.engines': 5});
      final c = ProviderContainer(
        overrides: [llmKeyStoreProvider.overrideWithValue(_Keys())],
      );
      addTearDown(c.dispose);
      await c.read(llmEngineSettingsProvider.notifier).ready;
    });

    test('llmClientProvider builds on the LLM dio', () {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [llmKeyStoreProvider.overrideWithValue(_Keys())],
      );
      addTearDown(c.dispose);
      expect(c.read(llmClientProvider), isA<LlmClient>());
    });
  });
}
