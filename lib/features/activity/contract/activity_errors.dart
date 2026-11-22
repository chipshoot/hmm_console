import 'package:flutter_riverpod/misc.dart' show ProviderException;

export '../data/activity_codec.dart' show ActivityUnreadable;

/// A save under [id] found a note of another catalog with that uuid (live
/// or deleted). Nothing is written.
class ActivityIdCollision implements Exception {
  const ActivityIdCollision(this.id);

  final String id;

  @override
  String toString() => 'ActivityIdCollision($id)';
}

/// Thrown in `cloudApi` mode, where no activity repository exists yet.
class ActivityCloudApiUnavailable extends UnimplementedError {
  ActivityCloudApiUnavailable()
    : super('activity cloudApi repo ships in the backend plan');
}

/// True when [error] is, or is Riverpod's wrapper around, an
/// [ActivityCloudApiUnavailable].
bool isActivityCloudApiUnavailable(Object error) {
  var e = error;
  while (e is ProviderException) {
    e = e.exception;
  }
  return e is ActivityCloudApiUnavailable;
}
