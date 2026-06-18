import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';

void main() {
  test('PickedImageBytes holds bytes + metadata', () {
    final pick = PickedImageBytes(
      bytes: Uint8List.fromList([1, 2, 3]),
      originalName: 'photo.jpg',
      contentType: 'image/jpeg',
    );
    expect(pick.bytes.length, 3);
    expect(pick.originalName, 'photo.jpg');
    expect(pick.contentType, 'image/jpeg');
  });
}
