# Add New Feature Module

Create a new feature module following the project's Clean Architecture pattern.

Feature name: $ARGUMENTS

Create the following directory structure under `lib/features/<feature_name>/`:

```
<feature_name>/
├── data/
│   ├── mappers/          # Entity ↔ Data model mappers
│   ├── model/            # Data models (Hive @HiveType if local, DTOs if remote)
│   ├── providers/        # Riverpod providers for data layer
│   └── repositories/     # Repository implementations + interfaces
├── domain/
│   ├── entities/         # Domain entities (plain Dart classes)
│   └── logics/           # Validators and business logic
├── presentation/
│   ├── screens/          # Full page screens
│   ├── viewmodels/       # ViewModels if using ChangeNotifier, otherwise states/
│   ├── widges/           # Reusable widgets for this feature
│   └── states/           # Riverpod AsyncNotifier states (preferred for new features)
└── usecases/             # Use case classes with single responsibility
```

Follow these conventions:
- Use **Riverpod** for DI and state management (not GetIt)
- Use `AsyncNotifierProvider` for async operations
- Use sealed `AppException` hierarchy for error handling
- If the feature needs local storage, follow the GasLog pattern: Entity ↔ Mapper ↔ HiveType model ↔ Repository ↔ Hive Box
- If the feature is remote-only, use Dio `ApiClient` from `lib/core/network/`
- Add a route in `lib/core/navigation/router.dart` and route name in `route_names.dart`
- Create barrel exports where appropriate
