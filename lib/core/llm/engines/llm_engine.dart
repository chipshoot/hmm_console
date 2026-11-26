import 'package:flutter/foundation.dart';

import '../contract/contract.dart';

enum LlmEngineKind { openai, anthropic, deepseek, gemini, custom }

enum WireFormat { openAiCompatible, anthropic }

/// One configured AI provider. Never holds the API key (that lives in
/// `LlmKeyStore`, per device).
@immutable
class LlmEngine {
  const LlmEngine({
    required this.id,
    required this.label,
    required this.kind,
    required this.baseUrl,
    required this.defaultModel,
    required this.requiresKey,
    required this.capabilities,
  });

  factory LlmEngine.fromJson(Map<String, Object?> json) => LlmEngine(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    kind: LlmEngineKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => LlmEngineKind.custom,
    ),
    baseUrl: json['baseUrl'] as String? ?? '',
    defaultModel: json['defaultModel'] as String? ?? '',
    requiresKey: json['requiresKey'] as bool? ?? true,
    capabilities: LlmCapabilities.fromJson(
      Map<String, Object?>.from(
        (json['capabilities'] as Map?) ?? const <String, Object?>{},
      ),
    ),
  );

  final String id;
  final String label;
  final LlmEngineKind kind;
  final String baseUrl;
  final String defaultModel;
  final bool requiresKey;
  final LlmCapabilities capabilities;

  WireFormat get wireFormat => kind == LlmEngineKind.anthropic
      ? WireFormat.anthropic
      : WireFormat.openAiCompatible;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.name,
    'baseUrl': baseUrl,
    'defaultModel': defaultModel,
    'requiresKey': requiresKey,
    'capabilities': capabilities.toJson(),
  };

  LlmEngine copyWith({
    String? label,
    LlmEngineKind? kind,
    String? baseUrl,
    String? defaultModel,
    bool? requiresKey,
    LlmCapabilities? capabilities,
  }) => LlmEngine(
    id: id,
    label: label ?? this.label,
    kind: kind ?? this.kind,
    baseUrl: baseUrl ?? this.baseUrl,
    defaultModel: defaultModel ?? this.defaultModel,
    requiresKey: requiresKey ?? this.requiresKey,
    capabilities: capabilities ?? this.capabilities,
  );

  // No key material here, but keep output minimal anyway.
  @override
  String toString() => 'LlmEngine($id, ${kind.name})';
}
