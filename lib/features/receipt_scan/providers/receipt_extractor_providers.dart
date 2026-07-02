import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../data/api_llm_extractor.dart';
import '../data/on_device_ocr_extractor.dart';
import '../domain/receipt_draft.dart';
import '../domain/receipt_extractor.dart';

/// User preference: which extractor to use. Mirrors [DataModeNotifier] —
/// `build()` returns the default synchronously and kicks off a prefs load that
/// updates state when it resolves.
class ReceiptExtractorModeNotifier extends Notifier<ReceiptExtractorMode> {
  static const _key = 'receipt_extractor_mode';

  @override
  ReceiptExtractorMode build() {
    _loadFromPrefs();
    return ReceiptExtractorMode.onDevice;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = ReceiptExtractorMode.fromWire(prefs.getString(_key));
  }

  Future<void> setMode(ReceiptExtractorMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.wire);
  }
}

final receiptExtractorModeProvider =
    NotifierProvider<ReceiptExtractorModeNotifier, ReceiptExtractorMode>(
  ReceiptExtractorModeNotifier.new,
);

/// The extractor for the active mode: on-device OCR, or the backend Claude
/// vision endpoint for Cloud AI.
final receiptExtractorProvider = Provider<ReceiptExtractor>((ref) {
  final mode = ref.watch(receiptExtractorModeProvider);
  return switch (mode) {
    ReceiptExtractorMode.onDevice => OnDeviceOcrExtractor(),
    ReceiptExtractorMode.cloudAi =>
      ApiLlmExtractor(ref.watch(apiClientProvider)),
  };
});
