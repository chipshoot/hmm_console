# HomeMadeMessage Console - System Design Document

## 1. Overview

**HomeMadeMessage Console** (`hmm_console`) is a cross-platform Flutter application that serves as the client for the HomeMadeMessage (Hmm) backend API. It provides personal note management, vehicle expense tracking, and other productivity features. The app authenticates via Firebase, consumes data through the Hmm REST API, and supports offline-first storage with Hive for select features.

**Target platforms:** Android, iOS, Web, Windows, macOS, Linux

## 2. Architecture

The application follows **Clean Architecture** with feature-based modular organization.

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│   Screens / Widgets / ViewModels / Riverpod States          │
├─────────────────────────────────────────────────────────────┤
│                     Domain Layer                            │
│   Entities / Use Cases / Providers / Validators             │
├─────────────────────────────────────────────────────────────┤
│                      Data Layer                             │
│   Repositories / Data Sources / Models / Mappers            │
├─────────────────────────────────────────────────────────────┤
│                    Infrastructure                           │
│   Firebase Auth / Hive DB / HTTP Client / Get_It / GoRouter │
└─────────────────────────────────────────────────────────────┘
```

### 2.1 Layer Responsibilities

| Layer | Responsibility | Key Types |
|-------|---------------|-----------|
| **Presentation** | UI rendering, user interaction, state binding | Screens, Widgets, ViewModels, AsyncNotifiers |
| **Domain** | Business rules, validation, data orchestration | Entities, Use Cases, Providers, Validators |
| **Data** | Persistence, external services, model mapping | Repositories, Data Sources, Mappers, Data Models |
| **Infrastructure** | Framework integration, DI, routing | Firebase, Hive, Get_It, GoRouter |

### 2.2 Project Structure

```
lib/
├── core/                           # Shared infrastructure
│   ├── di/                         # GetIt service locator setup
│   │   └── service_locator.dart
│   ├── exceptions/                 # Custom exception hierarchy
│   │   └── app_exceptions.dart
│   ├── navigation/                 # GoRouter configuration
│   │   ├── auth_change_provider.dart
│   │   ├── route_names.dart
│   │   ├── router.dart
│   │   └── router_config.dart
│   ├── services/                   # Core services
│   │   └── message_service.dart
│   ├── theme/                      # App theme definitions
│   │   └── theme.dart
│   └── widgets/                    # Reusable UI components
│       ├── button.dart
│       ├── gaps.dart
│       ├── screen_scaffold.dart
│       └── text_field.dart
├── domain/                         # Shared domain entities
│   └── entities/
│       ├── app_function.dart
│       └── nav_item.dart
├── features/                       # Feature modules
│   ├── auth/                       # Authentication
│   ├── dashboard/                  # Home dashboard
│   ├── gas_log/                    # Vehicle expense tracking
│   └── message_management/         # Message/note management
├── firebase_options.dart           # Generated Firebase config
└── main.dart                       # App entry point
```

## 3. Feature Modules

Each feature follows Clean Architecture with its own data/domain/presentation layers.

### 3.1 Authentication (`features/auth/`)

```
auth/
├── data/
│   ├── data/auth_data_source.dart         # Firebase Auth wrapper
│   ├── models/current_user.dart           # User data model
│   └── repository/auth_repository.dart    # Auth repository impl
├── domain/
│   └── logics/validators.dart             # Email/password validation
├── presentation/
│   └── screens/
│       ├── login_screen.dart
│       ├── register_screen.dart
│       └── forgot_password_screen.dart
├── states/
│   ├── login_state.dart                   # Riverpod AsyncNotifier
│   └── register_state.dart
└── usecases/
    ├── login_usecase.dart
    ├── register_usecase.dart
    ├── sign_out_usecase.dart
    └── auth_state_usecase.dart
```

**Auth Flow:**
1. `LoginScreen` collects credentials and calls `LoginState.loginWithEmailPassword()`
2. `LoginState` (AsyncNotifier) sets loading state, delegates to `LoginUseCase`
3. `LoginUseCase` calls `AuthRepository` -> `AuthRemoteDataSource` -> Firebase Auth
4. Firebase returns `UserCredential`, mapped to `CurrentUserDataModel`
5. Auth state stream (`authStateChanges`) triggers GoRouter redirect to dashboard

**Supported auth methods:**
- Email/password (login + registration)
- Google Sign-In (OAuth 2.0)
- Password reset via email

### 3.2 Dashboard (`features/dashboard/`)

```
dashboard/
└── presentation/
    └── screens/
        └── dashboard_screen.dart
```

The dashboard is the main screen after login. It displays:
- Time-based greeting message
- Recent messages list (from `MessageViewModel`)
- Quick-access function grid: Gas Log, Pomodoro, Expenses, Notes, Weather, Calendar
- Bottom navigation bar with badge indicators
- Staggered slide-in animations (600ms, easeInOut curves)

Each function card maps to a route via the `AppFunction` entity:
```dart
class AppFunction {
  final String icon;
  final String title;
  final String description;
  final String route;
}
```

### 3.3 Gas Log (`features/gas_log/`)

```
gas_log/
├── data/
│   ├── mappers/gas_log_mapper.dart
│   ├── model/gas_log_record.dart          # Hive @HiveType(typeId: 0)
│   └── repositories/gas_log_hive_repository.dart
├── domain/
│   └── entities/gas_log.dart              # Domain model
└── interfaces/
    └── gas_log_repository.dart            # Repository contract
```

**Storage:** Hive NoSQL database (offline-first, local persistence)

**Data flow:**
```
UI (GasLog entity)
  ↕ GasLogMapper
Data (GasLogRecord @HiveType)
  ↕ GasLogHiveRepository
Hive Box ("gasLogs")
```

**Domain model (`GasLog`):**
- id, odometer, distance, gas, price, date, gasStation, comment

**Data model (`GasLogRecord`)** mirrors domain with Hive annotations for serialization.

### 3.4 Message Management (`features/message_management/`)

```
message_management/
├── data/
│   └── repositories/
│       ├── i_message_repository.dart      # Interface
│       └── local_message_repository.dart  # In-memory mock
├── domain/
│   ├── entities/message.dart
│   └── providers/message_provider.dart
└── presentation/
    ├── viewmodels/message_view_model.dart # ChangeNotifier
    └── widgets/
        ├── message_item_view.dart
        └── message_list_view.dart
```

**Current state:** Uses in-memory mock data via `LocalMessageRepository`. Planned to connect to the Hmm backend API for real note/message CRUD.

**Domain entity (`Message`):**
- id, sender, avatar, preview, time, isUnread, conversationId, content

## 4. State Management

The app uses a **hybrid approach** with Riverpod as the primary framework and ChangeNotifier for specific UI-intensive scenarios.

### 4.1 Riverpod (Primary)

| Provider Type | Use Case | Example |
|--------------|----------|---------|
| `Provider` | Singleton services, repositories | `authRepositoryProvider` |
| `AsyncNotifierProvider` | Async operations with loading/error | `loginStateProvider` |
| `StreamProvider` | Real-time streams | `routerAuthStateProvider` |

**Auth state example:**
```dart
// Streams Firebase auth state changes
final routerAuthStateProvider = StreamProvider(
  (ref) => ref.watch(authStateUseCaseProvider).isUserAuthenticated(),
);

// Login state with loading/error handling
final loginStateProvider = AsyncNotifierProvider<LoginState, bool>(
  () => LoginState()
);
```

### 4.2 ChangeNotifier (Secondary)

Used in `MessageViewModel` where animation coordination with data loading is needed:
```dart
class MessageViewModel extends ChangeNotifier {
  final IMessageProvider _messageProvider;
  final AnimationController animationController;
  List<Message> _messages = [];

  Future<void> loadMessages() async {
    _messages = await _messageProvider.getMessages();
    notifyListeners();
  }
}
```

## 5. Dependency Injection

### 5.1 GetIt Service Locator

Registers non-auth dependencies (repositories, providers):

```dart
class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;

  static void setupDependencies() {
    _getIt.registerSingleton<IMessageRepository>(LocalMessageRepository());
    _getIt.registerSingleton<IGasLogRepository>(GasLogHiveRepository());
    _getIt.registerSingleton<IMessageProvider>(
      MessageProvider(_getIt<IMessageRepository>()),
    );
  }

  static T get<T extends Object>() => _getIt<T>();
}
```

### 5.2 Riverpod Providers

Registers auth-related dependency chain:
```
authRemoteDataSource → authRepositoryProvider → loginUseCaseProvider → loginStateProvider
```

### 5.3 Migration Note

The codebase uses both GetIt and Riverpod, indicating an ongoing migration toward Riverpod-first architecture. Newer features (auth) use Riverpod exclusively, while older features (message, gas log) still use GetIt.

## 6. Navigation & Routing

### 6.1 GoRouter Setup

Declarative routing with auth-based redirection:

```dart
GoRouter(
  redirect: (context, state) {
    final isAuthenticated = /* watch auth stream */;
    final isAuthPath = state.fullPath?.startsWith('/auth') ?? false;
    if (!isAuthenticated && !isAuthPath) return '/auth';
    return null;
  },
  initialLocation: '/',
  routes: [ /* route definitions */ ],
)
```

### 6.2 Route Map

| Route | Screen | Auth Required |
|-------|--------|--------------|
| `/` | Dashboard | Yes |
| `/auth` | Login | No |
| `/auth/register` | Register | No |
| `/auth/forgot-password` | Forgot Password | No |

### 6.3 Navigation Helper

```dart
class AppRouter {
  static Future<T?> go<T>(context, RouterNames routerName, {...}) {
    return GoRouter.of(context).pushNamed<T>(routerName.name, ...);
  }
  static Provider<GoRouter> config = routerConfig;
}
```

## 7. Data Flow & Backend Integration

### 7.1 Current Data Sources

| Feature | Data Source | Status |
|---------|-----------|--------|
| Auth | Firebase Auth (remote) | Implemented |
| Gas Log | Hive (local) | Implemented |
| Messages | In-memory mock | Placeholder |
| Dashboard | Composites above | Partial |

### 7.2 Planned Backend Integration

The Hmm backend API provides REST endpoints at `https://api.homemademessage.com/api/v1/`:

| Endpoint | Flutter Feature |
|----------|----------------|
| `/notes` | Message management |
| `/authors` | User profiles |
| `/tags` | Note categorization |
| `/notecatalogs` | Note templates |
| `/automobiles/{id}/gaslogs` | Gas log sync |

**Authentication flow with backend:**
1. User authenticates with Firebase (client-side)
2. Firebase JWT token included as Bearer token in API requests
3. Hmm API validates token against IDP authority
4. API returns data as JSON DTOs

### 7.3 Offline Strategy

- **Gas Log:** Full offline support via Hive with future sync to backend
- **Messages/Notes:** Planned online-first with local caching
- **Auth:** Requires connectivity for initial login; Firebase caches auth state

## 8. Error Handling

### 8.1 Exception Hierarchy

```dart
sealed class AppException implements Exception {
  const AppException(this.code, this.message);
  final String message;
  final String code;
}

class AppFirebaseException extends AppException { ... }
class UnknownException extends AppException { ... }
```

### 8.2 Error Propagation

```
Firebase SDK → AppFirebaseException → Repository → Use Case → AsyncNotifier → UI (error state)
```

Riverpod's `AsyncValue` provides built-in loading/error/data states, surfaced in the UI via `when()`:
```dart
asyncValue.when(
  data: (value) => /* success UI */,
  loading: () => /* loading indicator */,
  error: (err, stack) => /* error message */,
)
```

## 9. Theming

### 9.1 Theme Configuration

| Property | Light | Dark |
|----------|-------|------|
| Seed color | `Colors.deepPurple` | `Colors.green` |
| Selected nav | Deep Purple | Green |
| Unselected nav | Grey | Grey |
| Mode | System-based (`ThemeMode.system`) | |

### 9.2 Custom Visual Elements

- Dashboard header: Linear gradient (`#667eea` to `#764ba2`)
- Function cards: Purple gradient backgrounds with rounded corners
- Staggered slide-in animations on dashboard load
- Consistent spacing via `GapWidgets` utility class

## 10. Technology Stack

| Category | Technology | Version |
|----------|-----------|---------|
| Framework | Flutter | SDK |
| State Management | flutter_riverpod | 3.0.3 |
| DI Container | get_it | 8.0.3 |
| Routing | go_router | 17.0.0 |
| Auth | firebase_auth | 6.1.2 |
| OAuth | google_sign_in | 7.2.0 |
| Local DB | hive / hive_flutter | 2.2.3 / 1.1.0 |
| i18n | intl | 0.20.2 |
| Code Gen | build_runner / hive_generator | 2.4.9 / 2.0.1 |

## 11. App Initialization Sequence

```
main()
  ├── WidgetsFlutterBinding.ensureInitialized()
  ├── Firebase.initializeApp()
  ├── ServiceLocator.setupDependencies()     # GetIt registrations
  └── runApp(ProviderScope(child: MainApp()))  # Riverpod scope
        └── MaterialApp.router(
              theme: lightThemeData,
              darkTheme: darkThemeData,
              themeMode: ThemeMode.system,
              routerConfig: GoRouter (watches auth state)
            )
```

## 12. Integration with Hmm Backend

### 12.1 System Architecture

```
┌──────────────┐    HTTPS     ┌──────────────────┐
│  Flutter App  │◄───────────►│  Cloudflare Edge  │
│  (hmm_console)│             └────────┬─────────┘
└──────────────┘                       │ Encrypted tunnel
                                       │
                              ┌────────▼─────────┐
                              │  cloudflared       │
                              │  (macOS service)   │
                              └────────┬─────────┘
                                       │
                    ┌──────────────────▼──────────────────┐
                    │     Docker on MacBook                │
                    │  ┌─────────────────────────────┐    │
                    │  │ hmm-api :5010 (SQLite)      │    │
                    │  │ hmm-idp :5001 (IdentityServer)│  │
                    │  │ hmm-seq :8081 (Logging)     │    │
                    │  └─────────────────────────────┘    │
                    └─────────────────────────────────────┘
```

### 12.2 Auth Token Flow

```
Flutter App
  │
  ├── 1. Firebase Auth (login) → Firebase JWT
  │
  ├── 2. Exchange/validate with Hmm IDP
  │      POST https://auth.homemademessage.com
  │      → Hmm access token (JWT)
  │
  └── 3. API calls with Bearer token
         GET https://api.homemademessage.com/api/v1/notes
         Authorization: Bearer <hmm-jwt>
```

### 12.3 API Endpoints Used

| HTTP Method | Endpoint | Purpose |
|------------|----------|---------|
| GET | `/api/v1/notes` | List notes (paginated) |
| POST | `/api/v1/notes` | Create note |
| PUT | `/api/v1/notes/{id}` | Update note |
| DELETE | `/api/v1/notes/{id}` | Soft-delete note |
| GET | `/api/v1/authors` | Get authors |
| GET | `/api/v1/tags` | List tags |
| GET | `/api/v1/notecatalogs` | List note templates |
| GET | `/api/v1/automobiles/{id}/gaslogs` | Get gas logs |
| POST | `/api/v1/automobiles/{id}/gaslogs` | Add gas log |

## 13. Future Considerations

1. **Complete Riverpod migration** - Replace GetIt with Riverpod providers for all features
2. **HTTP client layer** - Add Dio or http package with interceptors for API calls
3. **Offline sync** - Implement conflict resolution for Hive-to-API synchronization
4. **Push notifications** - Firebase Cloud Messaging for real-time updates
5. **Localization** - Leverage existing `intl` dependency for multi-language support
6. **Testing** - Add unit tests for use cases, widget tests for screens, integration tests for flows
