import 'llm_engine.dart';
import 'llm_engine_registry.dart';

/// Explicit id, then the purpose's route, then the default; each only if that
/// engine still exists. Null when nothing resolves.
LlmEngine? selectEngine(
  LlmEngineSettings s, {
  String? engineId,
  String? purpose,
}) {
  LlmEngine? byId(String? id) {
    if (id == null) return null;
    for (final e in s.engines) {
      if (e.id == id) return e;
    }
    return null;
  }

  return byId(engineId) ??
      byId(purpose == null ? null : s.routes[purpose]) ??
      byId(s.defaultId);
}
