import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/llm/engines/engine_presets.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/engines/llm_engine_registry.dart';
import 'package:hmm_console/features/settings/presentation/screens/ai_provider_edit_screen.dart';

import 'ai_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> pickKind(WidgetTester t, String name) async {
    await t.tap(find.byKey(const Key('aiKindPicker')));
    await t.pumpAndSettle();
    await t.tap(find.text(name).last);
    await t.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(const Key('aiSave'))).onPressed != null;

  testWidgets('add an OpenAI preset: preset URL, typed model, trimmed key', (
    t,
  ) async {
    final h = await pumpAi(t, const AiProviderEditScreen());
    expect(find.byType(HelpButton), findsOneWidget);
    await pickKind(t, 'OpenAI');
    await t.enterText(field('Name'), 'My OpenAI');
    await t.enterText(field('Model'), 'gpt-x');
    await t.enterText(field('API key'), '  sk-123 \n');
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('aiSave')));
    await t.tap(find.byKey(const Key('aiSave')));
    await t.pumpAndSettle();
    final s = h.container.read(llmEngineSettingsProvider);
    final e = s.engines.single;
    expect(e.kind, LlmEngineKind.openai);
    expect(e.label, 'My OpenAI');
    expect(e.baseUrl, 'https://api.openai.com/v1');
    expect(e.defaultModel, 'gpt-x');
    expect(h.keys.keys[e.id], 'sk-123');
  });

  testWidgets('Save is disabled without a model', (t) async {
    await pumpAi(t, const AiProviderEditScreen());
    await pickKind(t, 'OpenAI');
    await t.enterText(field('Name'), 'X');
    await t.pumpAndSettle();
    expect(saveEnabled(t), isFalse);
    await t.enterText(field('Model'), 'm');
    await t.pumpAndSettle();
    expect(saveEnabled(t), isTrue);
  });

  testWidgets('custom engine requires a base URL', (t) async {
    await pumpAi(t, const AiProviderEditScreen());
    await pickKind(t, 'Custom (OpenAI-compatible)');
    await t.enterText(field('Name'), 'Home');
    await t.enterText(field('Model'), 'llama');
    await t.pumpAndSettle();
    expect(saveEnabled(t), isFalse);
    await t.enterText(field('Base URL'), 'http://192.168.1.5:11434/v1');
    await t.pumpAndSettle();
    expect(saveEnabled(t), isTrue);
  });

  final existing = presetEngine(
    LlmEngineKind.anthropic,
    id: 'a',
    label: 'Claude (work)',
    model: 'claude-x',
  );

  testWidgets('existing key is never shown; empty field keeps it', (t) async {
    final h = await pumpAi(
      t,
      const AiProviderEditScreen(engineId: 'a'),
      prefs: {'ai.engines': '[${_json(existing)}]'},
      savedKeys: const {'a': 'saved-secret'},
    );
    await t.pumpAndSettle();
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.textContaining('saved-secret'), findsNothing);
    await t.ensureVisible(find.byKey(const Key('aiSave')));
    await t.tap(find.byKey(const Key('aiSave')));
    await t.pumpAndSettle();
    expect(h.keys.keys['a'], 'saved-secret');
  });

  testWidgets('Remove key deletes the saved key', (t) async {
    final h = await pumpAi(
      t,
      const AiProviderEditScreen(engineId: 'a'),
      prefs: {'ai.engines': '[${_json(existing)}]'},
      savedKeys: const {'a': 'saved-secret'},
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Remove key'));
    await t.tap(find.text('Remove key'));
    await t.pumpAndSettle();
    expect(h.keys.keys, isEmpty);
  });

  testWidgets('Test connection reports success', (t) async {
    final h = await pumpAi(
      t,
      const AiProviderEditScreen(engineId: 'a'),
      prefs: {'ai.engines': '[${_json(existing)}]'},
      savedKeys: const {'a': 'saved-secret'},
    );
    h.http.body = {
      'content': [
        {'type': 'text', 'text': 'OK'},
      ],
      'stop_reason': 'end_turn',
      'model': 'claude-x',
      'usage': {'input_tokens': 1, 'output_tokens': 1},
    };
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Test connection'));
    await t.tap(find.text('Test connection'));
    await t.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('Test connection shows the mapped error for a bad key', (
    t,
  ) async {
    final h = await pumpAi(
      t,
      const AiProviderEditScreen(engineId: 'a'),
      prefs: {'ai.engines': '[${_json(existing)}]'},
      savedKeys: const {'a': 'saved-secret'},
    );
    h.http.status = 401;
    h.http.body = {
      'error': {'message': 'LEAKY-BODY'},
    };
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Test connection'));
    await t.tap(find.text('Test connection'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Claude (work): the key was rejected — check it in Settings → AI providers.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('LEAKY-BODY'), findsNothing);
  });

  testWidgets('Fetch models lists data[].id and fills the model', (t) async {
    final h = await pumpAi(
      t,
      const AiProviderEditScreen(engineId: 'a'),
      prefs: {'ai.engines': '[${_json(existing)}]'},
      savedKeys: const {'a': 'saved-secret'},
    );
    h.http.body = {
      'data': [
        {'id': 'claude-big'},
        {'id': 'claude-small'},
      ],
    };
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Fetch models'));
    await t.tap(find.text('Fetch models'));
    await t.pumpAndSettle();
    expect(
      h.http.requests.single.uri.toString(),
      'https://api.anthropic.com/v1/models',
    );
    expect(h.http.requests.single.headers['x-api-key'], 'saved-secret');
    await t.tap(find.text('claude-small').last);
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(field('Model')).controller!.text,
      'claude-small',
    );
  });

  testWidgets('Fetch models failure is a short note only', (t) async {
    final h = await pumpAi(
      t,
      const AiProviderEditScreen(engineId: 'a'),
      prefs: {'ai.engines': '[${_json(existing)}]'},
      savedKeys: const {'a': 'saved-secret'},
    );
    h.http.status = 500;
    h.http.body = {'error': 'LEAKY-BODY'};
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Fetch models'));
    await t.tap(find.text('Fetch models'));
    await t.pumpAndSettle();
    expect(find.textContaining("Couldn't load the model list"), findsOneWidget);
    expect(find.textContaining('LEAKY-BODY'), findsNothing);
  });

  testWidgets('Delete asks first, then removes the engine and its key', (
    t,
  ) async {
    final h = await pumpAi(
      t,
      const AiProviderEditScreen(engineId: 'a'),
      prefs: {'ai.engines': '[${_json(existing)}]'},
      savedKeys: const {'a': 'saved-secret'},
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('aiDelete')));
    await t.tap(find.byKey(const Key('aiDelete')));
    await t.pumpAndSettle();
    expect(find.textContaining('Delete Claude (work)?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(h.container.read(llmEngineSettingsProvider).engines, hasLength(1));
    await t.tap(find.byKey(const Key('aiDelete')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(h.container.read(llmEngineSettingsProvider).engines, isEmpty);
    expect(h.keys.keys, isEmpty);
  });
}

String _json(LlmEngine e) => jsonEncode(e.toJson());
