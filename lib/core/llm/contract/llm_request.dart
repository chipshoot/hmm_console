import 'package:flutter/foundation.dart';

import 'llm_json_schema.dart';
import 'llm_message.dart';

@immutable
class LlmRequest {
  LlmRequest({
    this.system,
    required this.messages,
    this.model,
    this.maxTokens = 2048,
    this.temperature,
    this.responseSchema,
    required this.containsSensitive,
    this.tools = const [],
  }) : assert(tools.isEmpty, 'tools are not supported in v1');

  final String? system;
  final List<LlmMessage> messages;
  final String? model;
  final int maxTokens;
  final double? temperature;
  final LlmJsonSchema? responseSchema;

  /// When true the call is refused before any I/O (sensitive guard).
  final bool containsSensitive;
  final List<LlmToolSpec> tools;

  bool get hasImages => messages.any((m) => m.parts.any((p) => p is ImagePart));

  bool get hasDocuments =>
      messages.any((m) => m.parts.any((p) => p is DocumentPart));

  @override
  bool operator ==(Object other) =>
      other is LlmRequest &&
      other.system == system &&
      listEquals(other.messages, messages) &&
      other.model == model &&
      other.maxTokens == maxTokens &&
      other.temperature == temperature &&
      other.responseSchema == responseSchema &&
      other.containsSensitive == containsSensitive &&
      listEquals(other.tools, tools);

  @override
  int get hashCode => Object.hash(
    system,
    Object.hashAll(messages),
    model,
    maxTokens,
    temperature,
    responseSchema,
    containsSensitive,
    Object.hashAll(tools),
  );
}
