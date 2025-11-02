# Gas Log App with Hive Database

This Flutter app demonstrates a clean architecture pattern using:
- **Domain Model**: `GasLog` (used in UI and business logic)
- **Data Model**: `GasLogRecord` (saved to Hive database)
- **Mapper**: `GasLogMapper` (converts between domain and data models)
- **Repository**: `GasLogHiveRepository` (handles database operations)

## Setup Instructions

### 1. Install Dependencies

The required dependencies are already added to `pubspec.yaml`:

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.9
```

Run the following command to install them:

```bash
flutter pub get
```

### 2. Generate Hive Adapters

Run the code generation to create the Hive adapter for `GasLogRecord`:

```bash
dart run build_runner build
```

This will generate the `gas_log_record.g.dart` file with the `GasLogRecordAdapter`.

### 3. Initialize Hive in Your App

In your `main.dart`, initialize Hive before running the app:

```dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/gas_log/domain/entities/gas_log_record.dart';
import 'features/gas_log/data/repositories/gas_log_hive_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register adapters
  Hive.registerAdapter(GasLogRecordAdapter());
  
  // Initialize repository
  await GasLogHiveRepository.init();
  
  runApp(MyApp());
}
```

## Architecture Overview

### Data Flow

1. **UI Layer** → Works with `GasLog` domain models
2. **Repository Layer** → Uses `GasLogMapper` to convert between models
3. **Database Layer** → Stores `GasLogRecord` data models in Hive

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    UI       │    │ Repository  │    │   Mapper    │    │    Hive     │
│  (GasLog)   │◄──►│             │◄──►│             │◄──►│(GasLogRecord│
│             │    │             │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Key Benefits

1. **Separation of Concerns**: Domain logic is separate from data persistence
2. **Type Safety**: Hive generates type-safe adapters
3. **Clean Interface**: UI only works with domain models
4. **Flexibility**: Easy to change storage implementation
5. **Auto-Generated IDs**: Repository handles ID generation automatically

## Usage Example

```dart
// Create repository
final repository = GasLogHiveRepository();

// Create domain model (for UI)
final gasLog = GasLog(
  odometer: '45,230',
  distance: 320.5,
  gas: 42.3,
  price: 3.89,
  date: DateTime.now(),
  gasStation: 'Shell',
  comment: 'Regular unleaded',
);

// Save (automatically converts to GasLogRecord)
String id = await repository.saveGasLog(gasLog);

// Retrieve (automatically converts back to GasLog)
List<GasLog> allLogs = await repository.getGasLogs();
GasLog specificLog = await repository.getGasLog(id);

// Update
final updatedLog = specificLog.copyWith(comment: 'Updated comment');
await repository.saveGasLog(updatedLog);

// Delete
await repository.deleteGasLog(id);
```

## File Structure

```
lib/
├── features/gas_log/
│   ├── domain/entities/
│   │   ├── gas_log.dart              # Domain model (UI)
│   │   ├── gas_log_record.dart       # Data model (Hive)
│   │   └── gas_log_record.g.dart     # Generated adapter
│   └── data/
│       ├── mappers/
│       │   └── gas_log_mapper.dart   # Conversion logic
│       └── repositories/
│           ├── i_gas_log_repository.dart      # Interface
│           └── gas_log_hive_repository.dart   # Hive implementation
└── complete_gas_log_example.dart     # Complete usage example
```

## Commands Reference

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build

# Watch for changes and regenerate
dart run build_runner watch

# Clean and regenerate
dart run build_runner clean
dart run build_runner build

# Run the app
flutter run
```

## Cloud Sync

The Hive database file can be easily backed up to cloud storage:

1. **Database Location**: The Hive files are stored locally on the device
2. **Backup Strategy**: Copy the entire `.hive` file to cloud storage
3. **Restore Strategy**: Download and replace the local `.hive` file
4. **Supported Clouds**: Google Drive, Dropbox, iCloud, or custom server

The single-file nature of Hive makes cloud synchronization straightforward compared to complex database setups.
