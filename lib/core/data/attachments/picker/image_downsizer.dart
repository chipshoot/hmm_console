// Downsize-on-copy: shrink a picked image before it lands in the vault.
//
// Why: the vault always stores a COPY of the bytes (never a link to the
// user's Photos library — see docs/attachments-design.md "Reference
// kinds"). A full-resolution phone photo is 2-5 MB; for a
// vehicle-records app a 2048px-long-edge JPEG is plenty and cuts that
// to a few hundred KB. Copy keeps the "your photo is safe no matter
// what you do in Photos" guarantee; downsize keeps it cheap.
//
// Abstracted so the picker stays unit-testable: tests inject a fake (or
// the no-op) downsizer and never touch a platform channel; production
// injects [NativeImageDownsizer], which uses native codecs (and so can
// decode HEIC on iOS and re-encode to JPEG).

import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Result of a downsize pass. [contentType] may differ from the input
/// when the image was transcoded (HEIC/PNG/WebP → JPEG).
class DownsizeResult {
  const DownsizeResult({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Shrinks image bytes before they're written to the vault.
abstract interface class ImageDownsizer {
  /// Return a (usually smaller) version of [bytes]. Implementations must
  /// be lossless-of-meaning: on any failure they return the input
  /// unchanged rather than throwing, so a pick never fails just because
  /// it couldn't be compressed.
  Future<DownsizeResult> downsize(
    Uint8List bytes, {
    required String contentType,
  });
}

/// Identity downsizer — returns bytes untouched. Default for direct
/// construction (and tests); production wires [NativeImageDownsizer].
class NoopImageDownsizer implements ImageDownsizer {
  const NoopImageDownsizer();

  @override
  Future<DownsizeResult> downsize(
    Uint8List bytes, {
    required String contentType,
  }) async =>
      DownsizeResult(bytes: bytes, contentType: contentType);
}

/// Default long-edge cap (px) for vault-stored images.
const int kVaultImageMaxLongEdge = 2048;

/// Default JPEG quality (0-100) for vault-stored images.
const int kVaultImageQuality = 85;

/// Native, platform-codec downsizer backed by `flutter_image_compress`.
/// Resizes to fit within [maxLongEdge] (keeping aspect ratio, never
/// upscaling) and re-encodes as JPEG at [quality]. Decodes HEIC on iOS.
class NativeImageDownsizer implements ImageDownsizer {
  const NativeImageDownsizer({
    this.maxLongEdge = kVaultImageMaxLongEdge,
    this.quality = kVaultImageQuality,
  });

  final int maxLongEdge;
  final int quality;

  @override
  Future<DownsizeResult> downsize(
    Uint8List bytes, {
    required String contentType,
  }) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxLongEdge,
        minHeight: maxLongEdge,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      // Guard: if compression didn't actually save space (already-small
      // image, or a format that re-encoded larger), keep the original
      // so we never bloat the vault.
      if (out.isEmpty || out.lengthInBytes >= bytes.lengthInBytes) {
        return DownsizeResult(bytes: bytes, contentType: contentType);
      }
      return DownsizeResult(
        bytes: Uint8List.fromList(out),
        contentType: 'image/jpeg',
      );
    } catch (_) {
      // Unsupported/corrupt input, or no native codec — store the
      // original untouched rather than failing the pick.
      return DownsizeResult(bytes: bytes, contentType: contentType);
    }
  }
}
