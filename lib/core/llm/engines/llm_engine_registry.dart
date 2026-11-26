import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/settings/data/syncable_settings_repository.dart';
import '../../../features/settings/providers/settings_bus_provider.dart';
import '../llm_key_store.dart';
import 'llm_engine.dart';

@immutable
class LlmEngineSettings {
  const LlmEngineSettings({
    required this.engines,
    required this.defaultId,
    required this.routes,
  });

  static const empty = LlmEngineSettings(
    engines: [],
    defaultId: null,
    routes: {},
  );

  final List<LlmEngine> engines;
  final String? defaultId;
  final Map<String, String> routes;
}

/// Engine list, default and purpose routes. Synced through the settings
/// bundle (`ai.*`); API keys are not part of it. Same shape as
/// `ShowLunarNotifier`: synchronous empty default, hydrated from prefs,
/// re-read when a pulled bundle bumps the settings bus.
class LlmEngineSettingsNotifier extends Notifier<LlmEngineSettings> {
  int _writes = 0;
  bool _swept = false;

  @override
  LlmEngineSettings build() {
    ref.watch(settingsBusProvider);
    _writes = 0;
    _load();
    return LlmEngineSettings.empty;
  }

  Future<void> _load() async {
    final writesAtStart = _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || _writes != writesAtStart) return;
      final (parsed, clean) = _parse(prefs);
      state = parsed;
      // Never sweep from a partial read: it would delete keys of engines we
      // merely failed to parse, and those keys are not recoverable.
      if (!_swept && clean) {
        _swept = true;
        await ref.read(llmKeyStoreProvider).sweepOrphans({
          for (final e in state.engines) e.id,
        });
      }
    } catch (e) {
      // Type only: engine config and keys must not reach logs.
      debugPrint('LlmEngines: settings unreadable (${e.runtimeType})');
    }
  }

  /// Bad entries are dropped one by one; [clean] is false when anything
  /// could not be read, so the caller must not treat the list as complete.
  (LlmEngineSettings, bool) _parse(SharedPreferences prefs) {
    var clean = true;
    final engines = <LlmEngine>[];
    var routes = <String, String>{};
    final raw = prefs.getString(SyncableSettingsRepository.aiEnginesKey);
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          try {
            engines.add(
              LlmEngine.fromJson(Map<String, Object?>.from(j as Map)),
            );
          } catch (_) {
            clean = false;
          }
        }
      } catch (_) {
        clean = false;
      }
    }
    final r = prefs.getString(SyncableSettingsRepository.aiRoutesKey);
    if (r != null) {
      try {
        routes = Map<String, String>.from(jsonDecode(r) as Map);
      } catch (_) {
        routes = {};
      }
    }
    // '' means "no default" (kept as a value so the clear syncs).
    final def = prefs.getString(SyncableSettingsRepository.aiDefaultKey);
    return (
      LlmEngineSettings(
        engines: engines,
        defaultId: (def == null || def.isEmpty) ? null : def,
        routes: routes,
      ),
      clean,
    );
  }

  Future<void> add(LlmEngine engine) => _commit(
    LlmEngineSettings(
      engines: [...state.engines, engine],
      defaultId: state.defaultId,
      routes: state.routes,
    ),
  );

  Future<void> update(LlmEngine engine) => _commit(
    LlmEngineSettings(
      engines: [for (final e in state.engines) e.id == engine.id ? engine : e],
      defaultId: state.defaultId,
      routes: state.routes,
    ),
  );

  /// Removes the engine, its routes and default, and this device's key and
  /// consent for it.
  Future<void> remove(String id) async {
    await _commit(
      LlmEngineSettings(
        engines: [
          for (final e in state.engines)
            if (e.id != id) e,
        ],
        defaultId: state.defaultId == id ? null : state.defaultId,
        routes: {
          for (final r in state.routes.entries)
            if (r.value != id) r.key: r.value,
        },
      ),
    );
    final keys = ref.read(llmKeyStoreProvider);
    await keys.deleteKey(id);
    await keys.deleteConsent(id);
  }

  Future<void> setDefault(String id) => _commit(
    LlmEngineSettings(
      engines: state.engines,
      defaultId: id,
      routes: state.routes,
    ),
  );

  Future<void> setRoute(String purpose, String? id) {
    final routes = Map<String, String>.of(state.routes);
    if (id == null) {
      routes.remove(purpose);
    } else {
      routes[purpose] = id;
    }
    return _commit(
      LlmEngineSettings(
        engines: state.engines,
        defaultId: state.defaultId,
        routes: routes,
      ),
    );
  }

  Future<void> _commit(LlmEngineSettings next) async {
    _writes++;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SyncableSettingsRepository.aiEnginesKey,
      jsonEncode([for (final e in next.engines) e.toJson()]),
    );
    await prefs.setString(
      SyncableSettingsRepository.aiDefaultKey,
      next.defaultId ?? '',
    );
    await prefs.setString(
      SyncableSettingsRepository.aiRoutesKey,
      jsonEncode(next.routes),
    );
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }
}

final llmEngineSettingsProvider =
    NotifierProvider<LlmEngineSettingsNotifier, LlmEngineSettings>(
      LlmEngineSettingsNotifier.new,
    );
