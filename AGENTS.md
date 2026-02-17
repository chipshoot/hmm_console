# AGENTS.md — Task Routing for hmm_console

## Subagents

### `voltagent-lang:flutter-expert`
Use for: Flutter architecture, widget composition, state management patterns, performance optimization, platform-specific implementations, animation design, testing strategies.
Trigger: Any Flutter/Dart implementation task that benefits from deep framework knowledge.

### `voltagent-lang:dart-specialist` (if available) / `voltagent-lang:typescript-pro`
Use for: Dart language questions, type system, async patterns. Fall back to typescript-pro for general async/type patterns if no Dart specialist.

## Skills (slash commands)

| Command | When to use |
|---------|-------------|
| `/build` | Build the app for a target platform |
| `/test` | Run all tests or a specific test file |
| `/analyze` | Run `flutter analyze` for lint/static analysis |
| `/codegen` | Run `build_runner` after modifying `@HiveType` models |
| `/add-feature` | Scaffold a new feature module with Clean Architecture structure |

## Task Routing Guide

| Task Type | Route To |
|-----------|----------|
| New feature module | `/add-feature` then `voltagent-lang:flutter-expert` for implementation |
| Widget/UI work | `voltagent-lang:flutter-expert` (consult `ui-design` skill) |
| Riverpod state management | `voltagent-lang:flutter-expert` (consult `flutter-dev` skill) |
| API integration (Dio) | `voltagent-lang:flutter-expert` — use `ApiClient` pattern from `lib/core/network/` |
| Hive local storage | `voltagent-lang:flutter-expert` — follow GasLog mapper pattern |
| Platform config (Android/iOS/etc) | `voltagent-lang:flutter-expert` (consult `platform-config` skill) |
| Firebase auth changes | Direct edit — follow existing auth feature patterns |
| GoRouter navigation | Direct edit — modify `lib/core/navigation/` |
| Testing | `voltagent-lang:flutter-expert` then `/test` to verify |
| Code generation | `/codegen` after model changes |
| Static analysis | `/analyze` |

## Project Conventions (quick reference)

- **DI:** Riverpod for new code, GetIt legacy only
- **State:** `AsyncNotifierProvider` + `AsyncValue.guard()`
- **Errors:** Sealed `AppException` hierarchy
- **Data models:** Entity ↔ Mapper ↔ Data model ↔ Repository
- **Navigation:** GoRouter with auth redirect
- **Testing:** mockito + http_mock_adapter, tests mirror lib/ structure
