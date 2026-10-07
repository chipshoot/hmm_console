import 'package:flutter/foundation.dart';

/// Computes a field from the stored entity map instead of reading it.
typedef DerivedFieldResolver = String? Function(Map<String, dynamic> entity);

/// Read-time values for `field` rows, keyed by entity root (`Contact`) and
/// dotted path (`displayName`). The resolver consults this before reading
/// the stored JSON; null (unregistered, empty, or failed) falls back to the
/// stored value. The field picker's offered paths are unaffected.
class DerivedFieldRegistry {
  const DerivedFieldRegistry([this._resolvers = const {}]);

  final Map<String, Map<String, DerivedFieldResolver>> _resolvers;

  String? resolve(String rootKey, String path, Map<String, dynamic> entityMap) {
    final f = _resolvers[rootKey]?[path];
    if (f == null) return null;
    try {
      return f(entityMap);
    } catch (e) {
      // Type only: the message can quote stored data.
      debugPrint(
        'DerivedFieldRegistry: $rootKey.$path failed '
        '(${e.runtimeType}); using the stored value.',
      );
      return null;
    }
  }
}
