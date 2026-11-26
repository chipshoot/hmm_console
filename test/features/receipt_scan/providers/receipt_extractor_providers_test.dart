import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';
import 'package:hmm_console/core/llm/engines/engine_presets.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/engines/llm_engine_registry.dart';
import 'package:hmm_console/features/receipt_scan/data/llm_receipt_extractor.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/receipt_scan/data/api_llm_extractor.dart';
import 'package:hmm_console/features/receipt_scan/data/on_device_ocr_extractor.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:hmm_console/features/receipt_scan/providers/receipt_extractor_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to onDevice and returns the on-device extractor', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(receiptExtractorModeProvider), ReceiptExtractorMode.onDevice);
    expect(c.read(receiptExtractorProvider), isA<OnDeviceOcrExtractor>());
  });

  test('setMode persists the choice', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    await c
        .read(receiptExtractorModeProvider.notifier)
        .setMode(ReceiptExtractorMode.cloudAi);
    expect(c.read(receiptExtractorModeProvider), ReceiptExtractorMode.cloudAi);

    // Persisted in the settings blob: a fresh container observes it.
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    await c2.read(settingsProvider.future);
    expect(c2.read(receiptExtractorModeProvider), ReceiptExtractorMode.cloudAi);
  });

  test('cloudAi mode returns the API extractor', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient(Dio())),
    ]);
    addTearDown(c.dispose);
    await c
        .read(receiptExtractorModeProvider.notifier)
        .setMode(ReceiptExtractorMode.cloudAi);
    expect(c.read(receiptExtractorProvider), isA<ApiLlmExtractor>());
  });

  test('loads a persisted mode on build', () async {
    SharedPreferences.setMockInitialValues(
        {'receipt_extractor_mode': 'cloudAi'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(receiptExtractorModeProvider); // trigger build + async load
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(receiptExtractorModeProvider), ReceiptExtractorMode.cloudAi);
  });

  test('provider mode returns the LLM extractor', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c
        .read(receiptExtractorModeProvider.notifier)
        .setMode(ReceiptExtractorMode.provider);
    expect(c.read(receiptExtractorProvider), isA<LlmReceiptExtractor>());
  });

  group('receiptPdfSupported', () {
    LlmEngine eng(bool pdf) =>
        presetEngine(LlmEngineKind.openai, id: 'a', label: 'A', model: 'm')
            .copyWith(
      capabilities: LlmCapabilities(
        vision: true,
        pdf: pdf,
        streaming: true,
        structuredOutput: StructuredOutput.native,
      ),
    );

    test('cloudAi always, onDevice never', () {
      const s = LlmEngineSettings(engines: [], defaultId: null, routes: {});
      expect(receiptPdfSupported(ReceiptExtractorMode.cloudAi, s), isTrue);
      expect(receiptPdfSupported(ReceiptExtractorMode.onDevice, s), isFalse);
    });

    test('provider only when the receipts engine has pdf', () {
      LlmEngineSettings with_(bool pdf) => LlmEngineSettings(
            engines: [eng(pdf)],
            defaultId: 'a',
            routes: const {},
          );
      expect(receiptPdfSupported(ReceiptExtractorMode.provider, with_(true)),
          isTrue);
      expect(receiptPdfSupported(ReceiptExtractorMode.provider, with_(false)),
          isFalse);
      expect(
          receiptPdfSupported(ReceiptExtractorMode.provider,
              LlmEngineSettings.empty),
          isFalse);
    });
  });
}
