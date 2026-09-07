import 'package:flutter/services.dart';

import '../picker/image_byte_source.dart';
import 'document_scanner.dart';

/// Talks to `ios/Runner/DocumentScannerPlugin.swift`.
///
/// Bytes cross the channel, never a file path: a path would mean a plaintext
/// JPEG of an identity document sitting in the app's tmp directory, outside
/// the vault, until the OS reclaimed it.
class NativeDocumentScanner implements DocumentScanner {
  const NativeDocumentScanner();

  static const _channel = MethodChannel('hmm/document_scanner');

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      // Cannot scan is not a failure to report — it is a reason to offer the
      // plain camera instead.
      return false;
    } on MissingPluginException {
      // No plugin registered on this host: Android today, and any platform
      // where the channel was never wired up.
      return false;
    }
  }

  @override
  Future<List<PickedImageBytes>> scan() async {
    try {
      final pages = await _channel.invokeListMethod<Uint8List>('scan') ?? [];
      var i = 0;
      return [
        for (final bytes in pages)
          PickedImageBytes(
            bytes: bytes,
            originalName: 'scan-${++i}.jpg',
            contentType: 'image/jpeg',
          ),
      ];
    } on PlatformException catch (e) {
      // Two non-failures: the platform cannot scan, and a scan is already on
      // screen. Both mean "no new pages", which an empty list says exactly.
      if (e.code == 'unavailable' || e.code == 'already_presenting') {
        return const [];
      }
      rethrow;
    } on MissingPluginException {
      return const [];
    }
  }
}
