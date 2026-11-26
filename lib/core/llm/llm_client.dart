import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapters/anthropic_adapter.dart';
import 'adapters/llm_adapter.dart';
import 'adapters/openai_compatible_adapter.dart';
import 'contract/contract.dart';
import 'engines/engine_selector.dart';
import 'engines/llm_engine.dart';
import 'engines/llm_engine_registry.dart';
import 'json_schema_validator.dart';
import 'llm_dio.dart';
import 'llm_key_store.dart';

/// Host a consent is tied to: content goes to this host and no other.
String engineHost(LlmEngine e) => Uri.tryParse(e.baseUrl)?.host ?? e.baseUrl;

/// The one entry point features use to call an AI provider. Runs the guards
/// in a fixed order, picks the engine, reads its key, calls the adapter,
/// retries, and validates structured output.
class LlmClient {
  LlmClient({
    required Future<LlmEngineSettings> Function() settings,
    required LlmKeyStore keys,
    required Map<WireFormat, LlmAdapter> adapters,
    Future<void> Function(Duration) delay = Future.delayed,
  }) : _settings = settings,
       _keys = keys,
       _adapters = adapters,
       _delay = delay;

  final Future<LlmEngineSettings> Function() _settings;
  final LlmKeyStore _keys;
  final Map<WireFormat, LlmAdapter> _adapters;
  final Future<void> Function(Duration) _delay;

  static const _maxRetryAfter = Duration(seconds: 10);

  Future<LlmResponse> complete(
    LlmRequest r, {
    String? engineId,
    String? purpose,
    CancelToken? cancel,
  }) async {
    final (engine, key) = await _prepare(r, engineId, purpose, stream: false);
    return _guarded(engine, () => _completeValidated(engine, key, r, cancel));
  }

  Stream<LlmEvent> stream(
    LlmRequest r, {
    String? engineId,
    String? purpose,
    CancelToken? cancel,
  }) async* {
    final (engine, key) = await _prepare(r, engineId, purpose, stream: true);
    try {
      await for (final e in _adapterFor(engine).stream(
        engine,
        key,
        r,
        model: r.model ?? engine.defaultModel,
        cancel: cancel,
      )) {
        if (e is Completed && r.responseSchema != null) {
          final (json, _) = _parse(e.response.text, r.responseSchema!);
          if (json == null) throw const LlmBadResponse('schema');
          yield Completed(
            LlmResponse(
              text: e.response.text,
              json: json,
              stopReason: e.response.stopReason,
              usage: e.response.usage,
              model: e.response.model,
            ),
          );
        } else {
          yield e;
        }
      }
    } on LlmException catch (e) {
      throw e.withEngine(engine.label);
    }
  }

  /// Sends a tiny request with [key] (typed in Settings, not yet saved).
  /// Skips the consent guard: testing is the user's own action.
  Future<void> testConnection(LlmEngine engine, String? key) => _guarded(
    engine,
    () => _call(
      engine,
      key,
      LlmRequest(
        messages: [LlmMessage.user('Reply with OK.')],
        maxTokens: 16,
        containsSensitive: false,
      ),
      null,
    ),
  );

  Future<(LlmEngine, String?)> _prepare(
    LlmRequest r,
    String? engineId,
    String? purpose, {
    required bool stream,
  }) async {
    // Absolute guard: nothing below (settings, keys) is touched first.
    if (r.containsSensitive) throw const LlmSensitiveRefused();

    final engine = selectEngine(
      await _settings(),
      engineId: engineId,
      purpose: purpose,
    );
    if (engine == null) throw const LlmKeyMissing();

    LlmException unsupported(LlmCapability c) =>
        LlmUnsupported(c, engineLabel: engine.label);

    if (!await _keys.hasConsent(engine.id, engineHost(engine))) {
      throw LlmConsentRequired(engineLabel: engine.label);
    }
    final caps = engine.capabilities;
    if (r.hasImages && !caps.vision) throw unsupported(LlmCapability.vision);
    if (r.hasDocuments && !caps.pdf) throw unsupported(LlmCapability.pdf);
    if (r.responseSchema != null &&
        caps.structuredOutput == StructuredOutput.none) {
      throw unsupported(LlmCapability.structuredOutput);
    }
    if (stream && !caps.streaming) throw unsupported(LlmCapability.streaming);

    final key = await _keys.readKey(engine.id);
    if (engine.requiresKey && key == null) {
      throw LlmKeyMissing(engineLabel: engine.label);
    }
    return (engine, key);
  }

  LlmAdapter _adapterFor(LlmEngine engine) {
    final a = _adapters[engine.wireFormat];
    if (a == null) throw LlmBadResponse('adapter', engineLabel: engine.label);
    return a;
  }

  Future<T> _guarded<T>(LlmEngine engine, Future<T> Function() body) async {
    try {
      return await body();
    } on LlmException catch (e) {
      throw e.withEngine(engine.label);
    }
  }

  /// One adapter call; a short `Retry-After` rate limit is retried once.
  Future<LlmResponse> _call(
    LlmEngine engine,
    String? key,
    LlmRequest r,
    CancelToken? cancel,
  ) async {
    final adapter = _adapterFor(engine);
    final model = r.model ?? engine.defaultModel;
    try {
      return await adapter.complete(
        engine,
        key,
        r,
        model: model,
        cancel: cancel,
      );
    } on LlmRateLimited catch (e) {
      final wait = e.retryAfter;
      if (wait == null || wait > _maxRetryAfter) rethrow;
      await _delay(wait);
      return adapter.complete(engine, key, r, model: model, cancel: cancel);
    }
  }

  Future<LlmResponse> _completeValidated(
    LlmEngine engine,
    String? key,
    LlmRequest r,
    CancelToken? cancel,
  ) async {
    final schema = r.responseSchema;
    final first = await _call(engine, key, r, cancel);
    if (schema == null) return first;
    _rejectUnusable(first);

    final (json, errors) = _parse(first.text, schema);
    if (json != null) return _withJson(first, json);

    final retry = LlmRequest(
      system: r.system,
      messages: [
        ...r.messages,
        LlmMessage.user(
          'Your previous reply was invalid: ${errors.join('; ')}. '
          'Reply again with only valid JSON.',
        ),
      ],
      model: r.model,
      maxTokens: r.maxTokens,
      temperature: r.temperature,
      responseSchema: schema,
      containsSensitive: r.containsSensitive,
    );
    final second = await _call(engine, key, retry, cancel);
    _rejectUnusable(second);
    final (json2, _) = _parse(second.text, schema);
    if (json2 == null) throw const LlmBadResponse('schema');
    return _withJson(second, json2);
  }

  /// A refusal or a cut-off reply can never validate; retrying would only
  /// pay for a second upload.
  void _rejectUnusable(LlmResponse r) {
    if (r.stopReason == LlmStopReason.refused) throw const LlmRefused();
    if (r.stopReason == LlmStopReason.maxTokens) {
      throw const LlmBadResponse('truncated');
    }
  }

  LlmResponse _withJson(LlmResponse r, Map<String, Object?> json) =>
      LlmResponse(
        text: r.text,
        json: json,
        stopReason: r.stopReason,
        usage: r.usage,
        model: r.model,
      );

  /// Decoded object and no errors, or null and the error paths. Errors name
  /// paths only, never content, so they are safe to send back to the model.
  (Map<String, Object?>?, List<String>) _parse(String text, LlmJsonSchema s) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_stripFence(text));
    } on FormatException {
      return (null, ['reply is not valid JSON']);
    }
    final errors = validateJsonSchema(decoded, s.schema);
    if (errors.isNotEmpty) return (null, errors);
    if (decoded is! Map) return (null, ['reply is not a JSON object']);
    return (Map<String, Object?>.from(decoded), const []);
  }

  static String _stripFence(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```(?:json)?[ \t]*\r?\n?'), '');
      t = t.replaceFirst(RegExp(r'\r?\n?[ \t]*```$'), '');
    }
    return t.trim();
  }
}

final llmClientProvider = Provider<LlmClient>((ref) {
  final dio = ref.watch(llmDioProvider);
  final notifier = ref.read(llmEngineSettingsProvider.notifier);
  return LlmClient(
    settings: () async {
      await notifier.ready;
      return ref.read(llmEngineSettingsProvider);
    },
    keys: ref.watch(llmKeyStoreProvider),
    adapters: {
      WireFormat.openAiCompatible: OpenAiCompatibleAdapter(dio),
      WireFormat.anthropic: AnthropicAdapter(dio),
    },
  );
});
