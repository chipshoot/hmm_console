import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/picker/image_attachment_picker.dart';
import 'package:hmm_console/core/data/attachments/picker/image_byte_source.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';
import 'package:hmm_console/core/llm/engines/engine_presets.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/engines/llm_engine_registry.dart';
import 'package:hmm_console/core/llm/llm_key_store.dart';
import 'package:hmm_console/features/automobile_records/data/repositories/service_record_repository.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/service_record_form_screen.dart';
import 'package:hmm_console/features/automobile_records/states/mutate_service_record_state.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_extractor.dart';
import 'package:hmm_console/features/receipt_scan/providers/receipt_extractor_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _Repo implements IServiceRecordRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubMode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.cloudApi;
}

class _ModeStub extends ReceiptExtractorModeNotifier {
  _ModeStub(this.m);
  final ReceiptExtractorMode m;
  @override
  ReceiptExtractorMode build() => m;
}

class _EngineStub extends LlmEngineSettingsNotifier {
  _EngineStub(this.s);
  final LlmEngineSettings s;
  @override
  Future<void> get ready => Future.value();
  @override
  LlmEngineSettings build() => s;
}

class _Keys extends LlmKeyStore {
  final consent = <String, String>{};
  @override
  Future<void> setConsent(String id, String host) async => consent[id] = host;
  @override
  Future<bool> hasConsent(String id, String host) async => consent[id] == host;
}

class _ImageSource implements ImageByteSource {
  @override
  Future<PickedImageBytes?> pick(AttachmentPickSource source) async =>
      PickedImageBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        originalName: 'r.png',
        contentType: 'image/png',
      );
}

class _Extractor implements ReceiptExtractor {
  _Extractor({this.consentFirst = false});
  final bool consentFirst;
  int calls = 0;
  @override
  Future<ReceiptDraft> extract(ReceiptInput input) async {
    calls++;
    if (consentFirst && calls == 1) throw const LlmConsentRequired();
    return const ReceiptDraft(
      source: ReceiptExtractorMode.provider,
      shopName: 'Joe Auto',
    );
  }
}

LlmEngineSettings _settings({required bool pdf}) => LlmEngineSettings(
  engines: [
    presetEngine(
      LlmEngineKind.openai,
      id: 'a',
      label: 'MyAI',
      model: 'm',
    ).copyWith(
      capabilities: LlmCapabilities(
        vision: true,
        pdf: pdf,
        streaming: true,
        structuredOutput: StructuredOutput.native,
      ),
    ),
  ],
  defaultId: 'a',
  routes: const {},
);

Future<ProviderContainer> _pump(
  WidgetTester t, {
  required ReceiptExtractorMode mode,
  LlmEngineSettings? engines,
  ReceiptExtractor? extractor,
  _Keys? keys,
  bool coldEngines = false,
}) async {
  final c = ProviderContainer(
    overrides: [
      serviceRecordRepositoryModeProvider.overrideWithValue(_Repo()),
      dataModeProvider.overrideWith(_StubMode.new),
      receiptExtractorModeProvider.overrideWith(() => _ModeStub(mode)),
      if (!coldEngines)
        llmEngineSettingsProvider.overrideWith(
          () => _EngineStub(engines ?? LlmEngineSettings.empty),
        ),
      llmKeyStoreProvider.overrideWithValue(keys ?? _Keys()),
      imageByteSourceProvider.overrideWithValue(_ImageSource()),
      if (extractor != null)
        receiptExtractorProvider.overrideWithValue(extractor),
    ],
  );
  addTearDown(c.dispose);
  await c.read(mutateServiceRecordStateProvider.future);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ServiceRecordFormScreen(automobileId: 7),
      ),
    ],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

Future<void> _openSheet(WidgetTester t) async {
  await t.tap(find.text('Scan a receipt'));
  await t.pumpAndSettle();
}

bool _pdfEnabled(WidgetTester t) =>
    t.widget<ListTile>(find.widgetWithText(ListTile, 'Choose a PDF')).enabled;

void main() {
  group('PDF option', () {
    testWidgets('enabled for Hmm cloud AI', (t) async {
      await _pump(t, mode: ReceiptExtractorMode.cloudAi);
      await _openSheet(t);
      expect(_pdfEnabled(t), isTrue);
    });

    testWidgets('provider: enabled only when the engine reads PDFs', (t) async {
      await _pump(
        t,
        mode: ReceiptExtractorMode.provider,
        engines: _settings(pdf: true),
      );
      await _openSheet(t);
      expect(_pdfEnabled(t), isTrue);
    });

    testWidgets('provider without pdf capability: disabled', (t) async {
      await _pump(
        t,
        mode: ReceiptExtractorMode.provider,
        engines: _settings(pdf: false),
      );
      await _openSheet(t);
      expect(_pdfEnabled(t), isFalse);
    });

    testWidgets('cold start: engines still loading, PDF is enabled', (t) async {
      final s = _settings(pdf: true);
      SharedPreferences.setMockInitialValues({
        'ai.engines': jsonEncode([for (final e in s.engines) e.toJson()]),
        'ai.default': 'a',
      });
      await _pump(t, mode: ReceiptExtractorMode.provider, coldEngines: true);
      await _openSheet(t);
      expect(_pdfEnabled(t), isTrue);
    });

    testWidgets('on-device: disabled', (t) async {
      await _pump(t, mode: ReceiptExtractorMode.onDevice);
      await _openSheet(t);
      expect(_pdfEnabled(t), isFalse);
    });
  });

  testWidgets('scan card names the provider mode from the ARB', (t) async {
    await _pump(t, mode: ReceiptExtractorMode.provider);
    expect(find.textContaining('My AI provider'), findsOneWidget);
    await _pump(t, mode: ReceiptExtractorMode.cloudAi);
    expect(find.textContaining('Hmm cloud AI'), findsOneWidget);
  });

  group('consent', () {
    testWidgets('accepting retries exactly once and applies the draft', (
      t,
    ) async {
      final ex = _Extractor(consentFirst: true);
      final keys = _Keys();
      await _pump(
        t,
        mode: ReceiptExtractorMode.provider,
        engines: _settings(pdf: true),
        extractor: ex,
        keys: keys,
      );
      await _openSheet(t);
      await t.tap(find.text('Choose a photo'));
      // The scan spinner animates while the consent sheet is up.
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Continue'), findsOneWidget);
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(ex.calls, 2);
      expect(keys.consent, {'a': 'api.openai.com'});
      expect(find.textContaining('Filled'), findsOneWidget);
      expect(find.text('Joe Auto'), findsWidgets);
    });

    testWidgets('declining does nothing: no retry, no snackbar', (t) async {
      final ex = _Extractor(consentFirst: true);
      await _pump(
        t,
        mode: ReceiptExtractorMode.provider,
        engines: _settings(pdf: true),
        extractor: ex,
      );
      await _openSheet(t);
      await t.tap(find.text('Choose a photo'));
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(ex.calls, 1);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
