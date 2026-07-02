import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/network/api_client.dart';
import 'package:hmm_console/features/receipt_scan/data/api_llm_extractor.dart';
import 'package:hmm_console/features/receipt_scan/data/on_device_ocr_extractor.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
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
    await c
        .read(receiptExtractorModeProvider.notifier)
        .setMode(ReceiptExtractorMode.cloudAi);
    expect(c.read(receiptExtractorModeProvider), ReceiptExtractorMode.cloudAi);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('receipt_extractor_mode'), 'cloudAi');
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
}
