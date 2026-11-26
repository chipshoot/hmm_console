import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../contract/contract.dart';
import '../engines/llm_engine.dart';
import 'llm_adapter.dart';
import 'sse.dart';

/// OpenAI chat-completions wire format: OpenAI, DeepSeek, Gemini's
/// OpenAI-compatible endpoint and self-hosted servers.
class OpenAiCompatibleAdapter implements LlmAdapter {
  OpenAiCompatibleAdapter(this._dio);

  final Dio _dio;

  static const _streamIdle = Duration(seconds: 60);

  @override
  WireFormat get format => WireFormat.openAiCompatible;

  @override
  Future<LlmResponse> complete(
    LlmEngine engine,
    String? key,
    LlmRequest request, {
    required String model,
    CancelToken? cancel,
  }) async {
    final body = _buildBody(engine, request, model, stream: false);
    try {
      final res = await _dio.postUri<Object?>(
        joinUrl(engine.baseUrl, 'chat/completions'),
        data: body,
        cancelToken: cancel,
        options: Options(headers: _headers(key), validateStatus: (_) => true),
      );
      final status = res.statusCode ?? 0;
      if (status >= 400) {
        throw _statusError(status, res.data, res.headers);
      }
      return _parseResponse(res.data);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Stream<LlmEvent> stream(
    LlmEngine engine,
    String? key,
    LlmRequest request, {
    required String model,
    CancelToken? cancel,
  }) async* {
    final body = _buildBody(engine, request, model, stream: true);
    try {
      final res = await _dio.postUri<ResponseBody>(
        joinUrl(engine.baseUrl, 'chat/completions'),
        data: body,
        cancelToken: cancel,
        options: Options(
          headers: _headers(key),
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
        ),
      );
      final status = res.statusCode ?? 0;
      final rb = res.data!;
      if (status >= 400) {
        Object? parsed;
        try {
          final bytes = await rb.stream.expand((c) => c).toList();
          parsed = jsonDecode(utf8.decode(bytes));
        } catch (_) {}
        throw _statusError(status, parsed, res.headers);
      }

      final text = StringBuffer();
      var stop = LlmStopReason.end;
      var finished = false;
      LlmUsage? usage;
      String? usedModel;
      final events = parseSse(rb.stream).timeout(
        _streamIdle,
        onTimeout: (sink) => sink.addError(const LlmTimeout()),
      );
      await for (final e in events) {
        if (e.data.isEmpty) continue;
        if (e.data.trim() == '[DONE]') {
          finished = true;
          break;
        }
        final Object? decoded;
        try {
          decoded = jsonDecode(e.data);
        } on FormatException {
          throw const LlmBadResponse('openai: malformed');
        }
        if (decoded is! Map) throw const LlmBadResponse('openai: malformed');
        usedModel = decoded['model'] as String? ?? usedModel;
        final u = _usage(decoded['usage']);
        if (u != null) usage = u;
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final choice = choices.first as Map;
          final delta = choice['delta'];
          final content = delta is Map ? delta['content'] : null;
          if (content is String && content.isNotEmpty) {
            text.write(content);
            yield TextDelta(content);
          }
          final fr = choice['finish_reason'];
          if (fr is String) {
            stop = _stop(fr);
            finished = true;
          }
        }
      }
      // A connection that closed without [DONE] or a finish_reason was cut.
      if (!finished) throw const LlmUnreachable();
      yield Completed(
        LlmResponse(
          text: text.toString(),
          stopReason: stop,
          usage: usage,
          model: usedModel,
        ),
      );
    } catch (e) {
      throw _map(e);
    }
  }

  Map<String, String> _headers(String? key) => {
    'Content-Type': 'application/json',
    if (key != null) 'Authorization': 'Bearer $key',
  };

  Map<String, Object?> _buildBody(
    LlmEngine engine,
    LlmRequest request,
    String model, {
    required bool stream,
  }) {
    var system = request.system;
    final schema = request.responseSchema;
    Map<String, Object?>? responseFormat;
    if (schema != null) {
      switch (engine.capabilities.structuredOutput) {
        case StructuredOutput.native:
          responseFormat = {
            'type': 'json_schema',
            'json_schema': {
              'name': schema.name,
              'schema': schema.schema,
              'strict': true,
            },
          };
        case StructuredOutput.jsonMode:
          responseFormat = {'type': 'json_object'};
          final hint =
              'Respond with JSON matching this schema: '
              '${jsonEncode(schema.schema)}';
          system = system == null ? hint : '$system\n\n$hint';
        case StructuredOutput.none:
          throw const LlmUnsupported(LlmCapability.structuredOutput);
      }
    }
    return {
      'model': model,
      'messages': [
        if (system != null) {'role': 'system', 'content': system},
        for (final m in request.messages) _message(m),
      ],
      // Current OpenAI models reject max_tokens; other providers want it.
      if (engine.kind == LlmEngineKind.openai)
        'max_completion_tokens': request.maxTokens
      else
        'max_tokens': request.maxTokens,
      'temperature': ?request.temperature,
      'response_format': ?responseFormat,
      if (stream) ...{
        'stream': true,
        'stream_options': {'include_usage': true},
      },
    };
  }

  Map<String, Object?> _message(LlmMessage m) {
    final role = switch (m.role) {
      LlmRole.user => 'user',
      LlmRole.assistant => 'assistant',
      LlmRole.tool => throw const LlmUnsupported(LlmCapability.tools),
    };
    for (final p in m.parts) {
      if (p is ToolCallPart || p is ToolResultPart) {
        throw const LlmUnsupported(LlmCapability.tools);
      }
    }
    if (m.parts.every((p) => p is TextPart)) {
      return {
        'role': role,
        'content': m.parts.map((p) => (p as TextPart).text).join('\n'),
      };
    }
    return {
      'role': role,
      'content': [
        for (final p in m.parts)
          switch (p) {
            TextPart() => {'type': 'text', 'text': p.text},
            ImagePart() => {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${p.mimeType};base64,${base64Encode(p.bytes)}',
              },
            },
            DocumentPart() => {
              'type': 'file',
              'file': {
                'filename': 'document.pdf',
                'file_data':
                    'data:${p.mimeType};base64,${base64Encode(p.bytes)}',
              },
            },
            _ => throw const LlmUnsupported(LlmCapability.tools),
          },
      ],
    };
  }

  LlmResponse _parseResponse(Object? data) {
    try {
      final map = data is String ? jsonDecode(data) : data;
      if (map is! Map) throw const FormatException();
      final choice = (map['choices'] as List).first as Map;
      final content = (choice['message'] as Map)['content'];
      if (content is! String) throw const FormatException();
      return LlmResponse(
        text: content,
        stopReason: _stop(choice['finish_reason'] as String?),
        usage: _usage(map['usage']),
        model: map['model'] as String?,
      );
    } on LlmException {
      rethrow;
    } catch (_) {
      throw const LlmBadResponse('openai: malformed');
    }
  }

  LlmStopReason _stop(String? reason) => switch (reason) {
    'length' => LlmStopReason.maxTokens,
    'content_filter' => LlmStopReason.refused,
    'tool_calls' => LlmStopReason.toolCall,
    _ => LlmStopReason.end,
  };

  LlmUsage? _usage(Object? u) {
    if (u is! Map) return null;
    return LlmUsage(
      inputTokens: u['prompt_tokens'] as int?,
      outputTokens: u['completion_tokens'] as int?,
    );
  }

  LlmException _statusError(int status, Object? body, Headers headers) {
    if (status == 401 || status == 403) return const LlmInvalidKey();
    if (status == 429) {
      Object? parsed = body;
      if (parsed is String) {
        try {
          parsed = jsonDecode(parsed);
        } catch (_) {}
      }
      final error = parsed is Map ? parsed['error'] : null;
      if (error is Map && error['code'] == 'insufficient_quota') {
        return const LlmQuotaExceeded();
      }
      final secs = int.tryParse(headers.value('retry-after') ?? '');
      return LlmRateLimited(
        retryAfter: secs == null ? null : Duration(seconds: secs),
      );
    }
    if (status >= 500) return const LlmUnreachable();
    return const LlmBadResponse('openai: malformed');
  }

  LlmException _map(Object e) {
    if (e is LlmException) return e;
    if (e is DioException) {
      return switch (e.type) {
        DioExceptionType.cancel => const LlmCancelled(),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => const LlmTimeout(),
        _ => const LlmUnreachable(),
      };
    }
    if (e is TimeoutException) return const LlmTimeout();
    return const LlmUnreachable();
  }
}
