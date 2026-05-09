/// Unwraps the ASP.NET Core result-filter envelope used by single-item
/// endpoints in the Hmm.ServiceApi (`{ "value": { ... }, "links": [...] }`)
/// and lower-cases the first letter of each PascalCase key produced by the
/// underlying ExpandoObject. List endpoints return a plain array and don't
/// need this helper.
Map<String, dynamic> unwrapApiEnvelope(dynamic data) {
  if (data is! Map<String, dynamic>) {
    throw FormatException('Expected JSON object, got ${data.runtimeType}');
  }
  final value = data['value'] is Map<String, dynamic>
      ? data['value'] as Map<String, dynamic>
      : data;
  return value.map((key, v) {
    final camelKey = key.isNotEmpty
        ? key[0].toLowerCase() + key.substring(1)
        : key;
    return MapEntry(camelKey, v);
  });
}
