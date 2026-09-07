import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/features/driver_licence/domain/licence_scan_mapping.dart';

PickedImageBytes page(int n) => PickedImageBytes(
      bytes: Uint8List.fromList([n]),
      originalName: 'page$n.jpg',
      contentType: 'image/jpeg',
    );

void main() {
  // `same()`, not equality: PickedImageBytes has no `==`, and the mapping
  // should hand back the very instances it was given rather than copies —
  // a stronger claim than matching a filename, and it needs no change to a
  // shared type just to satisfy a test.

  test('no pages means the user cancelled and nothing changes', () {
    final r = LicenceScanPages.fromScan(const []);

    expect(r.front, isNull);
    expect(r.back, isNull);
    expect(r.ignoredPageCount, 0);
  });

  test('one page is the front', () {
    final p1 = page(1);
    final r = LicenceScanPages.fromScan([p1]);

    expect(r.front, same(p1));
    expect(r.back, isNull);
    expect(r.ignoredPageCount, 0);
  });

  test('two pages are front then back, in capture order', () {
    final p1 = page(1);
    final p2 = page(2);
    final r = LicenceScanPages.fromScan([p1, p2]);

    expect(r.front, same(p1));
    expect(r.back, same(p2));
    expect(r.ignoredPageCount, 0);
  });

  test('extra pages are counted, not silently dropped', () {
    // The user shot four pages; they must be told two were ignored rather
    // than left wondering where they went.
    final p1 = page(1);
    final p2 = page(2);
    final r = LicenceScanPages.fromScan([p1, p2, page(3), page(4)]);

    expect(r.front, same(p1));
    expect(r.back, same(p2));
    expect(r.ignoredPageCount, 2);
  });
}
