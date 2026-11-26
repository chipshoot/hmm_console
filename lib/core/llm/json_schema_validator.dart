/// Validates [value] against a JSON Schema subset: `type` (string or list,
/// including `"null"`), `properties`, `required`, `items`, `enum` and
/// `additionalProperties: false`. Returns error paths; empty means valid.
/// Path format: dotted keys, `[i]` for indexes, suffixed `: required`,
/// `: type`, `: enum` or `: not allowed`.
List<String> validateJsonSchema(Object? value, Map<String, Object?> schema) {
  final errors = <String>[];
  _validate(value, schema, '', errors);
  return errors;
}

void _validate(
  Object? value,
  Map<String, Object?> schema,
  String path,
  List<String> errors,
) {
  final type = schema['type'];
  if (type != null) {
    final types = type is List ? type.cast<String>() : [type as String];
    if (!types.any((t) => _matchesType(value, t))) {
      errors.add('$path: type');
      return;
    }
  }

  final allowed = schema['enum'];
  if (allowed is List && !allowed.contains(value)) {
    errors.add('$path: enum');
  }

  if (value is Map) {
    final props = (schema['properties'] as Map?)?.cast<String, Object?>();
    final required = schema['required'];
    if (required is List) {
      for (final key in required) {
        if (!value.containsKey(key)) {
          errors.add('${_join(path, '$key')}: required');
        }
      }
    }
    if (props != null) {
      for (final entry in props.entries) {
        if (value.containsKey(entry.key)) {
          _validate(
            value[entry.key],
            (entry.value as Map).cast<String, Object?>(),
            _join(path, entry.key),
            errors,
          );
        }
      }
    }
    if (schema['additionalProperties'] == false) {
      for (final key in value.keys) {
        if (props == null || !props.containsKey(key)) {
          errors.add('${_join(path, '$key')}: not allowed');
        }
      }
    }
  }

  if (value is List) {
    final items = schema['items'];
    if (items is Map) {
      for (var i = 0; i < value.length; i++) {
        _validate(value[i], items.cast<String, Object?>(), '$path[$i]', errors);
      }
    }
  }
}

String _join(String path, String key) => path.isEmpty ? key : '$path.$key';

bool _matchesType(Object? v, String t) => switch (t) {
  'string' => v is String,
  'number' => v is num,
  'integer' => v is int || (v is double && v == v.truncateToDouble()),
  'boolean' => v is bool,
  'object' => v is Map,
  'array' => v is List,
  'null' => v == null,
  _ => true,
};
