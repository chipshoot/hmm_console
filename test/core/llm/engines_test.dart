import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/llm/contract/contract.dart';
import 'package:hmm_console/core/llm/engines/engine_presets.dart';
import 'package:hmm_console/core/llm/engines/engine_selector.dart';
import 'package:hmm_console/core/llm/engines/llm_engine.dart';
import 'package:hmm_console/core/llm/engines/llm_engine_registry.dart';
import 'package:hmm_console/core/llm/llm_key_store.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:hmm_console/features/settings/providers/settings_bus_provider.dart';
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
      await c.read(llmKeyStoreProvider).setConsent('a', 'h');
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

    test('empty engine set sweeps nothing (reinstall before sync)', () async {
      SharedPreferences.setMockInitialValues({});
      await storage.write(key: 'llm.key.a', value: 'k');
      await storage.write(key: 'llm.consent.a', value: 'h');
      final c3 = ProviderContainer(
        overrides: [
          llmKeyStoreProvider.overrideWithValue(LlmKeyStore(storage)),
        ],
      );
      addTearDown(c3.dispose);
      c3.listen(llmEngineSettingsProvider, (_, _) {});
      await c3.read(llmEngineSettingsProvider.notifier).ready;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(storage.map.keys.toSet(), {'llm.key.a', 'llm.consent.a'});
    });

    test('a bus tick keeps the previous engines while reloading', () async {
      final n = c.read(llmEngineSettingsProvider.notifier);
      await n.add(_e('a'));
      c.listen(llmEngineSettingsProvider, (_, _) {});
      c.read(settingsBusProvider.notifier).bump();
      // Read in the rebuild window, before the reload completes.
      expect(c.read(llmEngineSettingsProvider).engines.map((e) => e.id), [
        'a',
      ]);
      await c.read(llmEngineSettingsProvider.notifier).ready;
      expect(c.read(llmEngineSettingsProvider).engines.map((e) => e.id), [
        'a',
      ]);
    });

    test('a malformed entry is dropped, valid kept, no key swept', () async {
      final good = _e('a').toJson();
      SharedPreferences.setMockInitialValues({
        'ai.engines': jsonEncode([
          good,
          {'label': 'no id'},
          5,
        ]),
      });
      await storage.write(key: 'llm.key.a', value: 'k');
      await storage.write(key: 'llm.key.zzz', value: 'k2');
      final c3 = ProviderContainer(
        overrides: [
          llmKeyStoreProvider.overrideWithValue(LlmKeyStore(storage)),
        ],
      );
      addTearDown(c3.dispose);
      c3.listen(llmEngineSettingsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c3.read(llmEngineSettingsProvider).engines.map((e) => e.id), [
        'a',
      ]);
      expect(storage.map.keys.toSet(), {'llm.key.a', 'llm.key.zzz'});
    });

    test('unparseable engines value sweeps nothing', () async {
      SharedPreferences.setMockInitialValues({'ai.engines': 'not json'});
      await storage.write(key: 'llm.key.a', value: 'k');
      final c3 = ProviderContainer(
        overrides: [
          llmKeyStoreProvider.overrideWithValue(LlmKeyStore(storage)),
        ],
      );
      addTearDown(c3.dispose);
      c3.listen(llmEngineSettingsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(storage.map.keys, ['llm.key.a']);
    });

    test(
      'removing the default syncs as empty and an empty default applies',
      () async {
        final n = c.read(llmEngineSettingsProvider.notifier);
        await n.add(_e('a'));
        await n.setDefault('a');
        await n.remove('a');
        final bundle = await SyncableSettingsRepository().read();
        expect(bundle.aiDefault, '');
        expect(c.read(llmEngineSettingsProvider).defaultId, isNull);

        // Another device with a stale default applies the bundle.
        SharedPreferences.setMockInitialValues({'ai.default': 'a'});
        await SyncableSettingsRepository().apply(bundle);
        final c2 = ProviderContainer(
          overrides: [
            llmKeyStoreProvider.overrideWithValue(LlmKeyStore(storage)),
          ],
        );
        addTearDown(c2.dispose);
        c2.listen(llmEngineSettingsProvider, (_, _) {});
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(c2.read(llmEngineSettingsProvider).defaultId, isNull);
      },
    );
  });
}
