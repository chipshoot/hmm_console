# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**hmm_console** is a cross-platform Flutter app (Android, iOS, Web, Windows, macOS, Linux) serving as the client for the HomeMadeMessage (Hmm) backend API. It provides personal note management, vehicle records/expense tracking, and productivity features. Auth is via Firebase; local storage uses a **Drift (SQLite)** database; data can run fully local, sync to a personal cloud (OneDrive), or sync with the Hmm REST API at `api.homemademessage.com` — selectable at runtime via the `DataMode` system.

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

# Generate code (Drift database, Riverpod providers) after modifying tables/annotations
dart run build_runner build --delete-conflicting-outputs

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

- **DI / state management: Riverpod only.** The former GetIt/`ServiceLocator` setup has been fully removed (no `lib/core/di/`). Use Riverpod for all dependency injection and state: `AsyncNotifierProvider`/`Notifier` for async + mutable state, plain `Provider` for wiring. Some `riverpod_annotation` code generation is in use.
- **Local storage: Drift (SQLite).** `lib/core/data/local/database.dart` defines the schema (`Authors`, notes, tags, automobile, insurance, scheduled-service, service-record, gas-log, gas-station tables); generated code lives in `database.g.dart`. Local SQLite is the source of truth for offline-first features. (Hive has been fully removed; `README_HIVE_SETUP.md` is legacy.)
- **Data mode (local / cloudStorage / cloudApi):** `lib/core/data/data_mode.dart` defines a `DataMode` enum and `DataModeNotifier` (persisted via `shared_preferences`). `lib/core/data/repository_providers.dart` selects each repository implementation by mode — local Drift repos back both `local` and `cloudStorage` (the latter layers a sync engine on top of the same store), while `cloudApi` uses API-backed repositories. See the Data layer & sync section below.
- **Routing:** GoRouter with auth-based redirect. Routes defined in `lib/core/navigation/`. Unauthenticated users redirect to `/auth`.
- **Localization:** Flutter gen-l10n (`l10n.yaml`, ARB files in `lib/l10n/`, generated `AppLocalizations` in `lib/l10n/gen/`). Locale is driven by `lib/core/i18n/locale_provider.dart`. Currently `en` and `zh`.
- **Error handling:** Sealed `AppException` hierarchy in `lib/core/exceptions/app_exceptions.dart`. Firebase errors map to `AppFirebaseException`. Errors propagate through Riverpod's `AsyncValue`.

### Feature modules (`lib/features/`)

All features use Riverpod for DI/state. Data source depends on the active `DataMode` (local Drift vs Hmm API).

| Feature | Purpose | Data Source |
|---------|---------|-------------|
| `auth/` | Firebase login (email/password, Google, reset) | Firebase Auth (remote) |
| `onboarding/` | First-run onboarding flow | — |
| `notes/` | Personal note management | Drift / Hmm API (by mode) |
| `gas_log/` | Fuel logs, stations, discounts | Drift / Hmm API (by mode) |
| `automobile_records/` | Vehicles, insurance policies, scheduled services, service records (multi-line-item: typed labour/part/fee items + tax + computed totals) | Drift / Hmm API (by mode) |
| `geocoding/` | Address lookup (backed by the API geocoding endpoint) | Hmm API |
| `settings/` | App settings incl. data-mode selection | local prefs |
| `message_management/` | Messages (placeholder) | local repository (mock) |
| `launcher/` | Universal search launcher: home search box where a leading `/` triggers fuzzy "function search" over a destination registry (jump to any feature, with smart vehicle-context resolution); plain text is reserved for a future AI assistant (a stub in v1). Favorites + aliases are synced via `SyncableSettings`; recents are device-local. | local (registry + prefs) |
| `dashboard/` | Composites the above; its search bar opens the `launcher` | Mixed |

### Shared code (`lib/core/`)

- `data/` — the data layer (see Data layer & sync below): `local/` (Drift DB + repositories), `sync/` (cloud sync engine), `vault/` + `attachments/` (note attachment storage), `data_mode.dart`, `repository_providers.dart`, `result.dart`
- `network/` — Dio-based Hmm API client: `api_client.dart`, `api_config.dart`, IDP token handling (`idp_token_service.dart`, `idp_config.dart`, `jwt_utils.dart`, `token_storage.dart`), `pagination.dart`, and `interceptors/` (auth, error, logging)
- `auth/` — cross-feature auth helpers (e.g. `current_author_account_name_provider.dart`)
- `navigation/` — GoRouter config, auth redirect, route names
- `i18n/` — locale provider (pairs with `lib/l10n/` ARB files)
- `services/` — shared services (e.g. date/time providers)
- `theme/` — Light/dark theme definitions (deep purple / green seed colors)
- `util/` — shared utilities (e.g. `uuid.dart`)
- `widgets/` — Reusable UI components (button, text field, gaps, scaffold)
- `exceptions/` — App exception hierarchy

### App initialization sequence (main.dart)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
3. `runApp(ProviderScope(...))` (Riverpod root scope)
4. `MaterialApp.router` with GoRouter watching auth state, plus `AppLocalizations` for localization

### Auth flow

Login → `LoginState` (AsyncNotifier) → `LoginUseCase` → `AuthRepository` → `AuthRemoteDataSource` → Firebase Auth → auth state stream triggers GoRouter redirect to dashboard.

Supports: email/password, Google Sign-In, password reset.

### Data model pattern

Each domain area defines an abstract repository interface (e.g. `IHmmNoteRepository`) with two implementations:
- A **local** impl in `lib/core/data/local/` (e.g. `local_hmm_note_repository.dart`) backed by the Drift database.
- An **API** impl (e.g. `gas_log/data/repositories/gas_log_api_repository.dart`) backed by the Dio `api_client`.

`repository_providers.dart` exposes one Provider per interface that returns the right impl for the active `DataMode`. Feature models/entities are mapped to/from the data source via mappers (e.g. `features/notes/data/mappers/hmm_note_mapper.dart`). Follow this interface-plus-two-impls pattern for new data-backed features.

## Firebase

Project ID: `home-made-message`. Firebase emulators configured in `firebase.json` (auth:9099, firestore:8082, storage:9199). Emulator usage is commented out in `main.dart`.

## Target Platforms
- iOS (primary) - iPhone and iPad
- Android (secondary) - Phone only

## Platform UI Rules

### iOS
- Use Cupertino widgets for: navigation, action sheets, date pickers, switches, alerts
- NavigationBar style: CupertinoNavigationBar with large title
- Bottom nav: CupertinoTabBar
- Fonts: SF Pro via system font (no explicit font family needed on iOS)
- Back gesture: swipe-from-left-edge must work (don't block hero transitions)
- Safe area: always respect SafeArea, especially bottom (home indicator)

### Android
- Use Material 3 widgets
- NavigationBar style: Material AppBar with MD3 styling
- Bottom nav: NavigationBar (MD3, not BottomNavigationBar)
- Fonts: system default (Roboto), no explicit override needed
- FAB: use for primary actions on Android, avoid on iOS

### Shared Rules
- Never use a widget that looks wrong on either platform
- Always use flutter_platform_widgets for: buttons, switches, dialogs, text fields
- Platform check pattern: use `Theme.of(context).platform` or `dart:io Platform`

## Key Packages
- `flutter_platform_widgets`: use for ALL buttons, dialogs, switches, text fields, 
  nav bars — never use raw CupertinoX or MaterialX widgets directly
  - `flutter_slidable`: swipe actions on list items

## Backend API integration

Implemented in `lib/core/network/` against the REST API at `https://api.homemademessage.com/v1/` (notes, authors, tags, note catalogs, automobiles + insurance/scheduled-services/service-records, gas logs/stations/discounts, geocoding, currency, profile settings, note vault). A Dio `api_client` with auth/error/logging interceptors handles requests; `idp_token_service` exchanges credentials for a Hmm access token (via the IDP) and `token_storage` persists it, attached as a Bearer header by `auth_interceptor`. See `docs/SYSTEM_DESIGN.md` for the full endpoint list and architecture diagram.

## Data layer & sync

`lib/core/data/` is the heart of the app's storage strategy:

- **`local/`** — Drift (SQLite) database (`database.dart` + generated `database.g.dart`) and one local repository per domain area. This is the offline-first source of truth.
- **`data_mode.dart`** — `DataMode` enum (`local`, `cloudStorage`, `cloudApi`) and `DataModeNotifier` (persisted via `shared_preferences`; legacy `api` value maps to `cloudApi`).
- **`repository_providers.dart`** — selects each repository impl by mode. `local` and `cloudStorage` both use the local Drift store; `cloudApi` uses API-backed repositories.
- **`sync/`** — the cloud-sync engine for `cloudStorage` mode: `CloudSyncProvider` (abstract) with `onedrive_sync_provider` (OneDrive via `onedrive_graph_client`/`onedrive_auth`) and `api_sync_provider`, coordinated by `sync_orchestrator` / `sync_controller`, with `sync_meta_repository` and `sync_models` tracking state. See `docs/sync_contract.md`, `docs/cloud_storage_setup.md`, and `docs/data-layer-unification-plan.md`.
- **`vault/` + `attachments/`** — note attachment storage mirroring the backend `Hmm.Core.Vault`: `vault_store` interface with `local_vault_store` / `api_vault_store`, `vault_gc` for garbage collection, and attachment ref codecs/providers.

## Local Testing Environment
1. Backend start: run ../hmm/docker/test-env.ps1 or test-env.sh, based on current platform
2. To acces Hmm.ServiceAPI, Use access token:""
3. If developing platform is MacOS, Start up flutter into IOS, if developing platform is Windows, Start up flutter into Android

