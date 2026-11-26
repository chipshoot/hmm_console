import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/llm/engines/engine_selector.dart';
import '../../../core/llm/engines/llm_engine_registry.dart';
import '../../../core/llm/llm_client.dart';
import '../../../core/network/api_client.dart';
import '../../../core/settings/settings_controller.dart';
import '../data/api_llm_extractor.dart';
import '../data/llm_receipt_extractor.dart';
import '../data/on_device_ocr_extractor.dart';
import '../domain/receipt_draft.dart';
import '../domain/receipt_extractor.dart';

/// User preference: which extractor to use. Value + persistence live in the
/// unified SettingsController.
class ReceiptExtractorModeNotifier extends Notifier<ReceiptExtractorMode> {
  @override
  ReceiptExtractorMode build() =>
      ref.watch(settingsProvider).value?.receiptExtractorMode ??
      ReceiptExtractorMode.onDevice;

  Future<void> setMode(ReceiptExtractorMode mode) =>
      ref.read(settingsProvider.notifier).setReceiptExtractorMode(mode);
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
    ReceiptExtractorMode.cloudAi => ApiLlmExtractor(
      ref.watch(apiClientProvider),
    ),
    ReceiptExtractorMode.provider => LlmReceiptExtractor(
      ref.watch(llmClientProvider),
    ),
  };
});

/// Whether the PDF scan option is available: Hmm cloud AI reads PDFs; the
/// user's own provider only when the engine chosen for `receipts` does.
bool receiptPdfSupported(ReceiptExtractorMode mode, LlmEngineSettings s) =>
    switch (mode) {
      ReceiptExtractorMode.onDevice => false,
      ReceiptExtractorMode.cloudAi => true,
      ReceiptExtractorMode.provider =>
        selectEngine(s, purpose: 'receipts')?.capabilities.pdf ?? false,
    };
