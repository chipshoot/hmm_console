import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../util/uuid.dart';

/// Raw picked file (PDF), held in editor state until the note is saved (then
/// persisted to the vault). Mirrors PickedImageBytes.
class PickedFileBytes {
  PickedFileBytes({
    required this.bytes,
    required this.originalName,
    this.contentType,
    String? id,
  }) : id = id ?? generateUuid();

  /// Process-unique id, used to key per-pick temp files so two picks that
  /// share a display name don't collide.
  final String id;
  final Uint8List bytes;
  final String originalName;
  final String? contentType;
}

/// Picks a PDF's bytes WITHOUT writing to the vault (no note id needed).
abstract interface class FileByteSource {
  Future<PickedFileBytes?> pickPdf();
}

class FilePickerByteSource implements FileByteSource {
  @override
  Future<PickedFileBytes?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return null;
    return PickedFileBytes(
      bytes: file.bytes!,
      originalName: file.name,
      contentType: 'application/pdf',
    );
  }
}

/// Overridable in tests to return canned bytes without the platform picker.
final fileByteSourceProvider =
    Provider<FileByteSource>((ref) => FilePickerByteSource());
