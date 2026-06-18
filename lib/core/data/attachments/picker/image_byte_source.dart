import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'image_attachment_picker.dart';

/// Raw picked image, held in editor state until the note is saved (then
/// persisted to the vault). Carries bytes so a thumbnail renders immediately.
class PickedImageBytes {
  PickedImageBytes({
    required this.bytes,
    required this.originalName,
    this.contentType,
  });
  final Uint8List bytes;
  final String originalName;
  final String? contentType;
}

/// Picks image bytes WITHOUT writing to the vault (no note id needed). The
/// editor uses this so a photo can be added before the note exists.
abstract interface class ImageByteSource {
  Future<PickedImageBytes?> pick(AttachmentPickSource source);
}

class ImagePickerByteSource implements ImageByteSource {
  ImagePickerByteSource({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source == AttachmentPickSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (picked == null) return null;
    return PickedImageBytes(
      bytes: await picked.readAsBytes(),
      originalName: p.basename(picked.path),
      contentType: picked.mimeType,
    );
  }
}

/// Overridable in tests to return canned bytes without the platform picker.
final imageByteSourceProvider =
    Provider<ImageByteSource>((ref) => ImagePickerByteSource());
