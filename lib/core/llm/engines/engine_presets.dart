import '../contract/contract.dart';
import 'llm_engine.dart';

/// Builds an engine with the preset base URL and capabilities for [kind].
LlmEngine presetEngine(
  LlmEngineKind kind, {
  required String id,
  required String label,
  required String model,
}) {
  final (baseUrl, vision, pdf, structured, requiresKey) = switch (kind) {
    LlmEngineKind.openai => (
      'https://api.openai.com/v1',
      true,
      true,
      StructuredOutput.native,
      true,
    ),
    LlmEngineKind.anthropic => (
      'https://api.anthropic.com',
      true,
      true,
      StructuredOutput.native,
      true,
    ),
    LlmEngineKind.deepseek => (
      'https://api.deepseek.com/v1',
      false,
      false,
      StructuredOutput.jsonMode,
      true,
    ),
    LlmEngineKind.gemini => (
      'https://generativelanguage.googleapis.com/v1beta/openai',
      true,
      false,
      StructuredOutput.native,
      true,
    ),
    LlmEngineKind.custom => (
      '',
      false,
      false,
      StructuredOutput.jsonMode,
      false,
    ),
  };
  return LlmEngine(
    id: id,
    label: label,
    kind: kind,
    baseUrl: baseUrl,
    defaultModel: model,
    requiresKey: requiresKey,
    capabilities: LlmCapabilities(
      vision: vision,
      pdf: pdf,
      streaming: true,
      structuredOutput: structured,
    ),
  );
}
