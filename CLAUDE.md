# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**hmm_console** is a cross-platform Flutter app (Android, iOS, Web, Windows, macOS, Linux) serving as the client for the HomeMadeMessage (Hmm) backend API. It provides personal note management, vehicle expense tracking, and productivity features. Auth is via Firebase; local storage uses Hive; the app will integrate with a REST API at `api.homemademessage.com`.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Analyze/lint
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Generate Hive adapters (after modifying @HiveType models)
dart run build_runner build

# Watch mode for code generation
dart run build_runner watch

# Clean and regenerate
dart run build_runner clean && dart run build_runner build
```

## Architecture

Clean Architecture with feature-based modules. Three layers per feature:

```
Presentation (Screens, Widgets, ViewModels)
    ↕
Domain (Entities, Use Cases, Providers, Validators)
    ↕
Data (Repositories, Data Sources, Mappers, Models)
```

### Key architectural decisions

- **Dual DI system (migration in progress):** Auth features use **Riverpod** providers exclusively. Older features (messages, gas log) use **GetIt** via `ServiceLocator` (`lib/core/di/service_locator.dart`). New code should prefer Riverpod.
- **State management:** Riverpod `AsyncNotifierProvider` for async operations (auth), `ChangeNotifier` for animation-coupled UI (messages). Prefer Riverpod for new features.
- **Routing:** GoRouter with auth-based redirect. Routes defined in `lib/core/navigation/`. Unauthenticated users redirect to `/auth`.
- **Local storage:** Hive for offline-first features (gas log). Models annotated with `@HiveType` require code generation via `build_runner`.
- **Error handling:** Sealed `AppException` hierarchy in `lib/core/exceptions/app_exceptions.dart`. Firebase errors map to `AppFirebaseException`. Errors propagate through Riverpod's `AsyncValue`.

### Feature modules (`lib/features/`)

| Feature | Data Source | DI |
|---------|------------|-----|
| `auth/` | Firebase Auth (remote) | Riverpod |
| `gas_log/` | Hive (local, offline-first) | GetIt |
| `message_management/` | In-memory mock (placeholder) | GetIt |
| `dashboard/` | Composites above | Mixed |

### Shared code (`lib/core/`)

- `di/` — GetIt service locator setup
- `navigation/` — GoRouter config, auth redirect, route names
- `theme/` — Light/dark theme definitions (deep purple / green seed colors)
- `widgets/` — Reusable UI components (button, text field, gaps, scaffold)
- `exceptions/` — App exception hierarchy

### App initialization sequence (main.dart)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp()`
3. `ServiceLocator.setupDependencies()` (GetIt)
4. `runApp(ProviderScope(child: MainApp()))` (Riverpod)
5. `MaterialApp.router` with GoRouter watching auth state

### Auth flow

Login → `LoginState` (AsyncNotifier) → `LoginUseCase` → `AuthRepository` → `AuthRemoteDataSource` → Firebase Auth → auth state stream triggers GoRouter redirect to dashboard.

Supports: email/password, Google Sign-In, password reset.

### Data model pattern (Gas Log example)

Domain entity (`GasLog`) ↔ `GasLogMapper` ↔ Hive data model (`GasLogRecord` with `@HiveType`) ↔ `GasLogHiveRepository` ↔ Hive Box. Follow this pattern for new Hive-backed features.

## Firebase

Project ID: `home-made-message`. Firebase emulators configured in `firebase.json` (auth:9099, firestore:8082, storage:9199). Emulator usage is commented out in `main.dart`.

## Backend API (planned integration)

REST API at `https://api.homemademessage.com/api/v1/` with endpoints for notes, authors, tags, note catalogs, and gas logs. Auth uses Firebase JWT exchanged for Hmm access token as Bearer header. See `docs/SYSTEM_DESIGN.md` for full endpoint list and architecture diagram.

## Local Testing Environment
1. Backend start: run ../hmm/docker/test-env.ps1 or test-env.sh, based on current platform
2. To acces Hmm.ServiceAPI, Use access token:"eyJhbGciOiJSUzI1NiIsImtpZCI6IkNFRjJBRjY0OEU0RUREOTQ0NURDOUY2MTc0MzREQTRFIiwidHlwIjoiYXQrand0In0.eyJpc3MiOiJodHRwOi8vbG9jYWxob3N0OjUwMDEiLCJuYmYiOjE3NzExMjk2NTUsImlhdCI6MTc3MTEyOTY1N"

