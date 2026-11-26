import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';
import 'package:hmm_console/core/llm/engines/engine_presets.dart';
import 'package:hmm_console/core/llm/engines/engine_selector.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/engines/llm_engine_registry.dart';
import 'package:hmm_console/core/llm/llm_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage();
  final map = <String, String>{};
  @override
  Future<String?> read({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => map[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    if (value == null) {
      map.remove(key);
    } else {
      map[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => map.remove(key);
  @override
  Future<Map<String, String>> readAll({
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => Map.of(map);
}

LlmEngine _e(String id, [LlmEngineKind k = LlmEngineKind.openai]) =>
    presetEngine(k, id: id, label: id, model: 'm');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('engine json round-trip', () {
    final e = _e('a', LlmEngineKind.gemini);
    final back = LlmEngine.fromJson(e.toJson());
    expect(back.id, 'a');
    expect(back.kind, LlmEngineKind.gemini);
    expect(back.baseUrl, e.baseUrl);
    expect(back.defaultModel, 'm');
    expect(back.requiresKey, e.requiresKey);
    expect(back.capabilities.pdf, e.capabilities.pdf);
    expect(back.capabilities.structuredOutput, StructuredOutput.native);
  });

  test('wireFormat by kind', () {
    expect(_e('a', LlmEngineKind.anthropic).wireFormat, WireFormat.anthropic);
    for (final k in [
      LlmEngineKind.openai,
      LlmEngineKind.deepseek,
      LlmEngineKind.gemini,
      LlmEngineKind.custom,
    ]) {
      expect(_e('a', k).wireFormat, WireFormat.openAiCompatible);
    }
  });

  test('presets match spec table', () {
    final o = _e('a');
    expect(o.baseUrl, 'https://api.openai.com/v1');
    expect(o.capabilities.pdf, isTrue);
    expect(o.capabilities.structuredOutput, StructuredOutput.native);
    final d = _e('a', LlmEngineKind.deepseek);
    expect(d.baseUrl, 'https://api.deepseek.com/v1');
    expect(d.capabilities.vision, isFalse);
    expect(d.capabilities.structuredOutput, StructuredOutput.jsonMode);
    final g = _e('a', LlmEngineKind.gemini);
    expect(
      g.baseUrl,
      'https://generativelanguage.googleapis.com/v1beta/openai',
    );
    expect(g.capabilities.pdf, isFalse);
    expect(g.capabilities.structuredOutput, StructuredOutput.native);
    final a = _e('a', LlmEngineKind.anthropic);
    expect(a.baseUrl, 'https://api.anthropic.com');
    expect(a.capabilities.pdf, isTrue);
    expect(a.capabilities.structuredOutput, StructuredOutput.native);
    final c = _e('a', LlmEngineKind.custom);
    expect(c.baseUrl, '');
    expect(c.requiresKey, isFalse);
    expect(c.capabilities.vision, isFalse);
    expect(c.capabilities.pdf, isFalse);
    expect(c.capabilities.structuredOutput, StructuredOutput.jsonMode);
    for (final k in LlmEngineKind.values) {
      expect(_e('a', k).capabilities.streaming, isTrue);
    }
  });

  group('selector', () {
    final s = LlmEngineSettings(
      engines: [_e('a'), _e('b'), _e('c')],
      defaultId: 'c',
      routes: const {'receipts': 'b'},
    );
    test('explicit beats route beats default', () {
      expect(selectEngine(s, engineId: 'a', purpose: 'receipts')!.id, 'a');
      expect(selectEngine(s, purpose: 'receipts')!.id, 'b');
      expect(selectEngine(s)!.id, 'c');
      expect(selectEngine(s, purpose: 'other')!.id, 'c');
    });
    test('route to missing engine falls back to default', () {
      final m = LlmEngineSettings(
        engines: [_e('c')],
        defaultId: 'c',
        routes: const {'receipts': 'gone'},
      );
      expect(selectEngine(m, purpose: 'receipts')!.id, 'c');
    });
    test('no engines -> null', () {
      expect(
        selectEngine(
          const LlmEngineSettings(engines: [], defaultId: 'x', routes: {}),
        ),
        isNull,
      );
    });
  });

  group('registry', () {
    late _FakeStorage storage;
    late ProviderContainer c;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = _FakeStorage();
      c = ProviderContainer(
        overrides: [
          llmKeyStoreProvider.overrideWithValue(LlmKeyStore(storage)),
        ],
      );
      addTearDown(c.dispose);
    });

    test('remove clears its route, default, key and consent', () async {
      final n = c.read(llmEngineSettingsProvider.notifier);
      await n.add(_e('a'));
      await n.add(_e('b'));
      await n.setDefault('a');
      await n.setRoute('receipts', 'a');
      await c.read(llmKeyStoreProvider).writeKey('a', 'k');
      await c.read(llmKeyStoreProvider).setConsent('a');
      await n.remove('a');
      final s = c.read(llmEngineSettingsProvider);
      expect(s.engines.map((e) => e.id), ['b']);
      expect(s.defaultId, isNull);
      expect(s.routes, isEmpty);
      expect(storage.map, isEmpty);
    });

    test('persists to prefs and reloads', () async {
      final n = c.read(llmEngineSettingsProvider.notifier);
      await n.add(_e('a'));
      await n.setDefault('a');
      await n.setRoute('receipts', 'a');
      await n.update(_e('a').copyWith(label: 'Renamed'));
      final c2 = ProviderContainer(
        overrides: [
          llmKeyStoreProvider.overrideWithValue(LlmKeyStore(storage)),
        ],
      );
      addTearDown(c2.dispose);
      c2.listen(llmEngineSettingsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final s = c2.read(llmEngineSettingsProvider);
      expect(s.engines.single.label, 'Renamed');
      expect(s.defaultId, 'a');
      expect(s.routes, {'receipts': 'a'});
    });
  });
}
