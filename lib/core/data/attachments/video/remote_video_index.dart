import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which video vault paths the cloud holds, as of the last sync that listed it.
/// Unknown (null) until the first such sync, so the UI can tell "not uploaded"
/// from "not checked yet".
class RemoteVideoIndex extends ChangeNotifier {
  Set<String>? _cloudHas;

  Set<String>? get cloudHas => _cloudHas;

  void update(Set<String> remoteVideoPaths) {
    final next = Set<String>.unmodifiable(remoteVideoPaths);
    if (_cloudHas != null && setEquals(_cloudHas, next)) return;
    _cloudHas = next;
    notifyListeners();
  }

  /// null when the cloud has not been listed yet.
  bool? has(String path) => _cloudHas?.contains(path);
}

final remoteVideoIndexProvider = Provider<RemoteVideoIndex>((ref) {
  final index = RemoteVideoIndex();
  ref.onDispose(index.dispose);
  return index;
});
