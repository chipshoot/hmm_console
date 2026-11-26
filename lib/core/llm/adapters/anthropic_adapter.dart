import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../contract/contract.dart';
import '../engines/llm_engine.dart';
import 'llm_adapter.dart';
import 'sse.dart';

/// Anthropic Messages API wire format.
class AnthropicAdapter implements LlmAdapter {
  AnthropicAdapter(this._dio);

  final Dio _dio;

  static const _streamIdle = Duration(seconds: 60);
  static const _version = '2023-06-01';

  @override
  WireFormat get format => WireFormat.anthropic;

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
        joinUrl(engine.baseUrl, 'v1/messages'),
        data: body,
        cancelToken: cancel,
        options: Options(headers: _headers(key), validateStatus: (_) => true),
      );
      final status = res.statusCode ?? 0;
      if (status >= 400) {
        throw _statusError(status, res.data, res.headers);
      }
      return _parseResponse(res.data, request.responseSchema != null);
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
    final forced = request.responseSchema != null;
    try {
      final res = await _dio.postUri<ResponseBody>(
        joinUrl(engine.baseUrl, 'v1/messages'),
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
      final toolJson = StringBuffer();
      var stop = LlmStopReason.end;
      var finished = false;
      int? inTokens;
      int? outTokens;
      String? usedModel;
      final events = parseSse(rb.stream).timeout(
        _streamIdle,
        onTimeout: (sink) => sink.addError(const LlmTimeout()),
      );
      await for (final e in events) {
        if (e.data.isEmpty) continue;
        final Object? decoded;
        try {
          decoded = jsonDecode(e.data);
        } on FormatException {
          throw const LlmBadResponse('anthropic: malformed');
        }
        if (decoded is! Map) throw const LlmBadResponse('anthropic: malformed');
        switch (decoded['type']) {
          case 'message_start':
            final m = decoded['message'];
            if (m is Map) {
              usedModel = m['model'] as String? ?? usedModel;
              final u = m['usage'];
              if (u is Map) {
                inTokens = u['input_tokens'] as int? ?? inTokens;
                outTokens = u['output_tokens'] as int? ?? outTokens;
              }
            }
          case 'content_block_delta':
            final d = decoded['delta'];
            if (d is Map) {
              if (d['type'] == 'text_delta') {
                final t = d['text'];
                if (t is String && t.isNotEmpty) {
                  text.write(t);
                  yield TextDelta(t);
                }
              } else if (d['type'] == 'input_json_delta') {
                final p = d['partial_json'];
                if (p is String) toolJson.write(p);
              }
            }
          case 'message_delta':
            final d = decoded['delta'];
            if (d is Map && d['stop_reason'] is String) {
              stop = _stop(d['stop_reason'] as String, forced);
            }
            final u = decoded['usage'];
            if (u is Map) {
              inTokens = u['input_tokens'] as int? ?? inTokens;
              outTokens = u['output_tokens'] as int? ?? outTokens;
            }
          case 'message_stop':
            finished = true;
          case 'error':
            throw _errorEvent(decoded['error']);
        }
        if (finished) break;
      }
      // A connection that closed without message_stop was cut.
      if (!finished) throw const LlmUnreachable();
      yield Completed(
        LlmResponse(
          text: toolJson.isNotEmpty ? toolJson.toString() : text.toString(),
          stopReason: stop,
          usage: inTokens == null && outTokens == null
              ? null
              : LlmUsage(inputTokens: inTokens, outputTokens: outTokens),
          model: usedModel,
        ),
      );
    } catch (e) {
      throw _map(e);
    }
  }

  Map<String, String> _headers(String? key) => {
    'content-type': 'application/json',
    'anthropic-version': _version,
    'x-api-key': ?key,
  };

  Map<String, Object?> _buildBody(
    LlmEngine engine,
    LlmRequest request,
    String model, {
    required bool stream,
  }) {
    final schema = request.responseSchema;
    if (schema != null &&
        engine.capabilities.structuredOutput == StructuredOutput.none) {
      throw const LlmUnsupported(LlmCapability.structuredOutput);
    }
    return {
      'model': model,
      'max_tokens': request.maxTokens,
      'system': ?request.system,
      'temperature': ?request.temperature,
      'messages': [for (final m in request.messages) _message(m)],
      if (schema != null) ...{
        'tools': [
          {
            'name': schema.name,
            'description': 'Return the result.',
            'input_schema': schema.schema,
          },
        ],
        'tool_choice': {'type': 'tool', 'name': schema.name},
      },
      if (stream) 'stream': true,
    };
  }

  Map<String, Object?> _message(LlmMessage m) {
    final role = switch (m.role) {
      LlmRole.user => 'user',
      LlmRole.assistant => 'assistant',
      LlmRole.tool => throw const LlmUnsupported(LlmCapability.tools),
    };
    return {
      'role': role,
      'content': [
        for (final p in m.parts)
          switch (p) {
            TextPart() => {'type': 'text', 'text': p.text},
            ImagePart() => {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': p.mimeType,
                'data': base64Encode(p.bytes),
              },
            },
            DocumentPart() => {
              'type': 'document',
              'source': {
                'type': 'base64',
                'media_type': p.mimeType,
                'data': base64Encode(p.bytes),
              },
            },
            ToolCallPart() ||
            ToolResultPart() => throw const LlmUnsupported(LlmCapability.tools),
          },
      ],
    };
  }

  LlmResponse _parseResponse(Object? data, bool forced) {
    try {
      final map = data is String ? jsonDecode(data) : data;
      if (map is! Map) throw const FormatException();
      final blocks = map['content'] as List;
      final text = StringBuffer();
      String? toolInput;
      for (final b in blocks) {
        if (b is! Map) continue;
        if (b['type'] == 'text') {
          text.write(b['text'] as String);
        } else if (b['type'] == 'tool_use') {
          toolInput = jsonEncode(b['input']);
        }
      }
      final u = map['usage'];
      return LlmResponse(
        text: toolInput ?? text.toString(),
        stopReason: _stop(map['stop_reason'] as String?, forced),
        usage: u is Map
            ? LlmUsage(
                inputTokens: u['input_tokens'] as int?,
                outputTokens: u['output_tokens'] as int?,
              )
            : null,
        model: map['model'] as String?,
      );
    } on LlmException {
      rethrow;
    } catch (_) {
      throw const LlmBadResponse('anthropic: malformed');
    }
  }

  LlmStopReason _stop(String? reason, bool forced) => switch (reason) {
    'max_tokens' => LlmStopReason.maxTokens,
    'refusal' => LlmStopReason.refused,
    'tool_use' => forced ? LlmStopReason.end : LlmStopReason.toolCall,
    _ => LlmStopReason.end,
  };

  LlmException _statusError(int status, Object? body, Headers headers) {
    if (status == 401 || status == 403) return const LlmInvalidKey();
    if (status == 429) {
      final secs = int.tryParse(headers.value('retry-after') ?? '');
      return LlmRateLimited(
        retryAfter: secs == null ? null : Duration(seconds: secs),
      );
    }
    if (status == 404) return const LlmNotFound();
    if (status == 413) return const LlmTooLarge();
    if (status >= 500) return const LlmUnreachable();
    if (status == 400) {
      Object? parsed = body;
      if (parsed is String) {
        try {
          parsed = jsonDecode(parsed);
        } catch (_) {}
      }
      final error = parsed is Map ? parsed['error'] : null;
      final message = error is Map ? error['message'] : null;
      if (message is String && message.contains('credit balance')) {
        return const LlmQuotaExceeded();
      }
    }
    return const LlmBadResponse('anthropic: malformed');
  }

  LlmException _errorEvent(Object? error) {
    final type = error is Map ? error['type'] : null;
    return switch (type) {
      'authentication_error' || 'permission_error' => const LlmInvalidKey(),
      'rate_limit_error' => const LlmRateLimited(),
      'overloaded_error' || 'api_error' => const LlmUnreachable(),
      _ => const LlmBadResponse('anthropic: malformed'),
    };
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
