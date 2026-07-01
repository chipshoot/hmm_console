import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/util/uuid.dart';
import '../domain/receipt_draft.dart';
import '../domain/receipt_extractor.dart';
import 'receipt_text_parser.dart';

/// Recognizes text from image bytes. Injectable so tests bypass ML Kit (which
/// needs a device/plugin). Production writes the bytes to a temp file and runs
/// the on-device recognizer.
typedef RecognizeText = Future<String> Function(Uint8List imageBytes);

/// Offline, on-device extractor. Runs ML Kit text recognition on the image,
/// then heuristics via [ReceiptTextParser]. Fills scalar fields only; does not
/// itemize. Images only — PDFs need the Cloud AI extractor.
class OnDeviceOcrExtractor implements ReceiptExtractor {
  OnDeviceOcrExtractor({RecognizeText? recognize, ReceiptTextParser? parser})
      : _recognize = recognize ?? _mlkitRecognize,
        _parser = parser ?? const ReceiptTextParser();

  final RecognizeText _recognize;
  final ReceiptTextParser _parser;

  @override
  Future<ReceiptDraft> extract(ReceiptInput input) async {
    if (input.isPdf) {
      throw const ReceiptExtractionException(
        'PDF receipts need Cloud AI extraction. Use a photo, or switch to '
        'Cloud AI in Settings.',
      );
    }
    try {
      final text = await _recognize(input.bytes);
      if (text.trim().isEmpty) {
        throw const ReceiptExtractionException('No text found in the image.');
      }
      return _parser.parse(text);
    } on ReceiptExtractionException {
      rethrow;
    } catch (e) {
      throw ReceiptExtractionException('Could not read the receipt: $e');
    }
  }

  static Future<String> _mlkitRecognize(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    // Unique name so equal-size receipts don't collide; deleted after OCR so
    // receipt images don't linger on disk in the "private" on-device mode.
    final file = File(p.join(dir.path, 'receipt-ocr-${generateUuid()}.jpg'));
    await file.writeAsBytes(bytes);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(file.path));
      return result.text;
    } finally {
      await recognizer.close();
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
