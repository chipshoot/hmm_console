import 'package:flutter/foundation.dart';

/// A structured-output schema (JSON Schema subset) the response must satisfy.
@immutable
class LlmJsonSchema {
  const LlmJsonSchema({required this.name, required this.schema});
  final String name;
  final Map<String, Object?> schema;

  @override
  bool operator ==(Object other) =>
      other is LlmJsonSchema &&
      other.name == name &&
      _deepEquals(other.schema, schema);

  @override
  int get hashCode => Object.hash(name, schema.length);
}

/// Reserved for a later tool-calling version; requests refuse tools in v1.
@immutable
class LlmToolSpec {
  const LlmToolSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
  });
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  @override
  bool operator ==(Object other) =>
      other is LlmToolSpec &&
      other.name == name &&
      other.description == description &&
      _deepEquals(other.inputSchema, inputSchema);

  @override
  int get hashCode => Object.hash(name, description, inputSchema.length);
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
