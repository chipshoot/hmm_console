import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/llm/engines/engine_presets.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/engines/llm_engine_registry.dart';
import 'package:hmm_console/features/settings/presentation/screens/ai_providers_screen.dart';

import 'ai_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LlmEngine eng(
    String id,
    String label,
    LlmEngineKind k, {
    bool requiresKey = true,
  }) => presetEngine(
    k,
    id: id,
    label: label,
    model: 'm',
  ).copyWith(requiresKey: requiresKey);

  Future<AiHarness> pump(WidgetTester t) async {
    final h = await pumpAi(t, const AiProvidersScreen());
    final n = h.container.read(llmEngineSettingsProvider.notifier);
    h.keys.keys['a'] = 'sk';
    await n.add(eng('a', 'Claude (work)', LlmEngineKind.anthropic));
    await n.add(
      eng('b', 'Home Ollama', LlmEngineKind.custom, requiresKey: false),
    );
    await n.add(eng('c', 'OpenAI', LlmEngineKind.openai));
    await n.setDefault('a');
    await t.pumpAndSettle();
    return h;
  }

  testWidgets('rows show label, Default and the three key states', (t) async {
    await pump(t);
    expect(find.text('Claude (work)'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Key ✓'), findsOneWidget);
    expect(find.text('No key needed'), findsOneWidget);
    expect(find.text('Key needed on this device'), findsOneWidget);
    expect(find.byType(HelpButton), findsOneWidget);
    expect(find.text('Add provider'), findsOneWidget);
  });

  testWidgets('Use for receipts picker writes the receipts route', (t) async {
    final h = await pump(t);
    await t.tap(find.text('Use for receipts'));
    await t.pumpAndSettle();
    await t.tap(find.text('Home Ollama').last);
    await t.pumpAndSettle();
    expect(h.container.read(llmEngineSettingsProvider).routes, {
      'receipts': 'b',
    });
  });

  platformTest(
    'Settings row is absent off iOS/Android',
    TargetPlatform.windows,
    (t) async {
      await pumpAi(t, const Scaffold(body: AiProvidersSettingsSection()));
      expect(find.text('AI providers'), findsNothing);
    },
  );

  platformTest('Settings row is present on Android', TargetPlatform.android, (
    t,
  ) async {
    await pumpAi(t, const Scaffold(body: AiProvidersSettingsSection()));
    expect(find.text('AI providers'), findsOneWidget);
  });
}
