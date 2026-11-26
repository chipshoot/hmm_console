import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/llm/engines/engine_presets.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/engines/llm_engine_registry.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:hmm_console/features/receipt_scan/presentation/receipt_extraction_settings_section.dart';
import 'package:hmm_console/features/receipt_scan/providers/receipt_extractor_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host() => const ProviderScope(
      child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      
        home: Scaffold(body: ReceiptExtractionSettingsSection()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first Cloud AI selection prompts consent and persists on confirm',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_host());
    await t.pump();

    await t.tap(find.text('Hmm cloud AI'));
    await t.pumpAndSettle();
    expect(find.text('Enable Cloud AI'), findsOneWidget);

    await t.tap(find.text('Enable Cloud AI'));
    await t.pumpAndSettle();

    final blob = (await SharedPreferences.getInstance()).getString('app_settings')!;
    expect(blob, contains('"receiptExtractorMode":"cloudAi"'));
    expect(blob, contains('"receiptCloudConsent":true'));
  });

  testWidgets('cancelling consent leaves the mode unset (stays on-device)',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_host());
    await t.pump();

    await t.tap(find.text('Hmm cloud AI'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();

    // Cancelled: the mode stays on-device in the settings blob.
    final blob = (await SharedPreferences.getInstance()).getString('app_settings')!;
    expect(blob, contains('"receiptExtractorMode":"onDevice"'));
  });

  testWidgets('after consent given, switching does not re-prompt', (t) async {
    SharedPreferences.setMockInitialValues({'receipt_cloud_consent': true});
    await t.pumpWidget(_host());
    await t.pump();

    await t.tap(find.text('Hmm cloud AI'));
    await t.pumpAndSettle();

    expect(find.text('Enable Cloud AI'), findsNothing);
    final blob = (await SharedPreferences.getInstance()).getString('app_settings')!;
    expect(blob, contains('"receiptExtractorMode":"cloudAi"'));
  });

  Future<ProviderContainer> pumpWithRouter(
    WidgetTester t, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: ReceiptExtractionSettingsSection()),
      ),
      GoRoute(
        path: '/settings/ai',
        name: RouterNames.aiProviders.name,
        builder: (_, _) => const Scaffold(body: Text('AI SCREEN')),
      ),
    ]);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await t.pumpAndSettle();
    return c;
  }

  testWidgets('third option is hidden off iOS/Android', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await pumpWithRouter(t);
      expect(find.text('My AI provider'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('choosing My AI provider with no engine opens /settings/ai',
      (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final c = await pumpWithRouter(t);
      await t.tap(find.text('My AI provider'));
      await t.pumpAndSettle();
      expect(find.text('AI SCREEN'), findsOneWidget);
      expect(c.read(receiptExtractorModeProvider), ReceiptExtractorMode.onDevice);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('cold start: the first tap sees the stored default engine',
      (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final e = presetEngine(
        LlmEngineKind.openai,
        id: 'a',
        label: 'A',
        model: 'm',
      );
      // No notifier has been built before the tap.
      final c = await pumpWithRouter(t, prefs: {
        'ai.engines': jsonEncode([e.toJson()]),
        'ai.default': 'a',
      });
      await t.tap(find.text('My AI provider'));
      await t.pumpAndSettle();
      expect(find.text('AI SCREEN'), findsNothing);
      expect(c.read(receiptExtractorModeProvider), ReceiptExtractorMode.provider);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('choosing My AI provider with a default engine selects it',
      (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final c = await pumpWithRouter(t);
      final n = c.read(llmEngineSettingsProvider.notifier);
      await n.add(presetEngine(LlmEngineKind.openai, id: 'a', label: 'A', model: 'm'));
      await n.setDefault('a');
      await t.tap(find.text('My AI provider'));
      await t.pumpAndSettle();
      expect(find.text('AI SCREEN'), findsNothing);
      expect(c.read(receiptExtractorModeProvider), ReceiptExtractorMode.provider);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
