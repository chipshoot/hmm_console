import 'package:flutter/foundation.dart';

enum LlmStopReason { end, maxTokens, toolCall, refused }

@immutable
class LlmUsage {
  const LlmUsage({this.inputTokens, this.outputTokens});
  final int? inputTokens;
  final int? outputTokens;

  @override
  bool operator ==(Object other) =>
      other is LlmUsage &&
      other.inputTokens == inputTokens &&
      other.outputTokens == outputTokens;

  @override
  int get hashCode => Object.hash(inputTokens, outputTokens);
}

@immutable
class LlmResponse {
  const LlmResponse({
    required this.text,
    this.json,
    required this.stopReason,
    this.usage,
    this.model,
  });

  final String text;

  /// Parsed structured output, when a response schema was requested.
  final Map<String, Object?>? json;
  final LlmStopReason stopReason;
  final LlmUsage? usage;
  final String? model;

  @override
  bool operator ==(Object other) =>
      other is LlmResponse &&
      other.text == text &&
      mapEquals(other.json, json) &&
      other.stopReason == stopReason &&
      other.usage == usage &&
      other.model == model;

  @override
  int get hashCode => Object.hash(text, json?.length, stopReason, usage, model);
}
