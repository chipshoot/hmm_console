import '../../../core/data/attachments/picker/image_byte_source.dart';

/// Maps one scanning session onto a licence's two sides.
///
/// VisionKit returns however many pages the user shot. A licence has exactly
/// two sides, so the rules are fixed HERE, in Dart, where a test can reach
/// them — the Swift side deliberately knows nothing about licences, because it
/// cannot be unit-tested and does not run on the simulator.
class LicenceScanPages {
  const LicenceScanPages({this.front, this.back, this.ignoredPageCount = 0});

  final PickedImageBytes? front;
  final PickedImageBytes? back;

  /// Pages beyond the second. Surfaced so the screen can say they were
  /// ignored; dropping them silently would look like lost work.
  final int ignoredPageCount;

  factory LicenceScanPages.fromScan(List<PickedImageBytes> pages) =>
      LicenceScanPages(
        front: pages.isNotEmpty ? pages[0] : null,
        back: pages.length > 1 ? pages[1] : null,
        ignoredPageCount: pages.length > 2 ? pages.length - 2 : 0,
      );
}
