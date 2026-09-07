import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../picker/image_byte_source.dart';

/// The OS document scanner: edge detection, perspective correction and shadow
/// removal, done by the platform rather than by us.
///
/// Returns [PickedImageBytes] — the same type the camera picker returns — so
/// everything downstream (pending picks, `persistToVault(sensitive: true)`,
/// downsizing) works unchanged.
abstract interface class DocumentScanner {
  /// False on the simulator, on Android until its half lands, and on iOS
  /// versions without VisionKit. Callers must check this and hide the scan
  /// affordance rather than offering something that cannot work.
  Future<bool> isAvailable();

  /// One entry per page, in capture order. Empty when the user cancels.
  Future<List<PickedImageBytes>> scan();
}

/// The default everywhere the platform cannot scan. Deliberately silent: an
/// unavailable scanner is not an error, it is a reason to show the plain
/// camera instead.
class UnavailableDocumentScanner implements DocumentScanner {
  const UnavailableDocumentScanner();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<PickedImageBytes>> scan() async => const [];
}

final documentScannerProvider = Provider<DocumentScanner>(
  // Task 3 makes this platform-aware; until the MethodChannel client exists,
  // every caller correctly sees "cannot scan here".
  (ref) => const UnavailableDocumentScanner(),
);
