import 'package:flutter/foundation.dart';

enum StructuredOutput { native, jsonMode, none }

enum LlmCapability { vision, pdf, streaming, structuredOutput, tools }

@immutable
class LlmCapabilities {
  const LlmCapabilities({
    required this.vision,
    required this.pdf,
    required this.streaming,
    required this.structuredOutput,
    this.tools = false,
  });

  factory LlmCapabilities.fromJson(Map<String, Object?> json) =>
      LlmCapabilities(
        vision: json['vision'] as bool? ?? false,
        pdf: json['pdf'] as bool? ?? false,
        streaming: json['streaming'] as bool? ?? false,
        structuredOutput: StructuredOutput.values.firstWhere(
          (e) => e.name == json['structuredOutput'],
          orElse: () => StructuredOutput.none,
        ),
        tools: json['tools'] as bool? ?? false,
      );

  final bool vision;
  final bool pdf;
  final bool streaming;
  final StructuredOutput structuredOutput;
  final bool tools;

  Map<String, Object?> toJson() => {
    'vision': vision,
    'pdf': pdf,
    'streaming': streaming,
    'structuredOutput': structuredOutput.name,
    'tools': tools,
  };

  @override
  bool operator ==(Object other) =>
      other is LlmCapabilities &&
      other.vision == vision &&
      other.pdf == pdf &&
      other.streaming == streaming &&
      other.structuredOutput == structuredOutput &&
      other.tools == tools;

  @override
  int get hashCode =>
      Object.hash(vision, pdf, streaming, structuredOutput, tools);
}
