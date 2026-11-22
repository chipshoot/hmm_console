import 'package:flutter_riverpod/misc.dart' show ProviderException;

export '../data/glucose_codec.dart' show GlucoseUnreadable;

/// A save under [id] found a note of another catalog with that uuid (live
/// or deleted). Nothing is written.
class GlucoseIdCollision implements Exception {
  const GlucoseIdCollision(this.id);

  final String id;

  @override
  String toString() => 'GlucoseIdCollision($id)';
}

/// Thrown in `cloudApi` mode, where no glucose repository exists yet.
class GlucoseCloudApiUnavailable extends UnimplementedError {
  GlucoseCloudApiUnavailable()
    : super('glucose cloudApi repo ships in the backend plan');
}

/// True when [error] is, or is Riverpod's wrapper around, a
/// [GlucoseCloudApiUnavailable].
bool isGlucoseCloudApiUnavailable(Object error) {
  var e = error;
  while (e is ProviderException) {
    e = e.exception;
  }
  return e is GlucoseCloudApiUnavailable;
}
