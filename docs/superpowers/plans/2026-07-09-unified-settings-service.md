# Unified Device-Local Settings Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the 11 scattered device-local `SharedPreferences` settings behind one typed `AppSettings` model persisted as a single JSON blob, owned by a `SettingsController`, with existing providers delegating to it.

**Architecture:** `AppSettings` (immutable, JSON) ⇄ `SettingsController` (`AsyncNotifier<AppSettings>`, single persistence owner of key `app_settings`) ⇄ the existing per-setting providers, which keep their public surface but read via `settingsProvider` and write via the controller. Roaming (`SyncableSettings`) and secrets (secure storage) are untouched.

**Tech Stack:** Flutter/Dart, Riverpod (`AsyncNotifier`/`Notifier`), `shared_preferences`, `flutter_test`.

**Repo:** `hmm_console` (client only — verified no backend/IdP/multi-device impact).

## Global Constraints

- Device-local tier only. **Do not** touch `SyncableSettings` (roaming) or secure storage.
- One `SharedPreferences` key for the blob: `app_settings`. `AppSettings.schemaVersion` current value = `1`.
- The 11 fields (with legacy keys, defaults): `dataMode`←`data_mode` (default `DataMode.local`; legacy `'api'`→`cloudApi`), `cloudProvider`←`cloud_provider` (`CloudProvider.onedrive`), `geoCaptureEnabled`←`geo_capture_enabled` (`false`), `receiptExtractorMode`←`receipt_extractor_mode` (`ReceiptExtractorMode.onDevice`, via `fromWire`/`.wire`), `receiptCloudConsent`←`receipt_cloud_consent` (`false`), `launcherRecents`←`launcher_recents` (`const []`, JSON list), `notesFilterUsage`←`notes.filter_usage` (`const {}`, JSON `Map<String,int>`), `dashboardIntroCardSeen`←`dashboard_intro_card_seen` (`false`), `onboardingCompleted`←`onboarding_completed` (`false`), `localDbPath`←`local_db_path` (`null`), `cloudStorageVaultPath`←`cloud_storage_vault_path` (`null`).
- **Connection-critical fields:** `dataMode`, `cloudProvider`, `cloudStorageVaultPath`. On a corrupt blob they fall back to `migrateFromLegacy(prefs)` (legacy keys are retained this release), never to blind defaults.
- **Legacy keys are retained** this release (removal deferred). Migration writes the blob but does not delete old keys.
- **Excluded (roam — never in `AppSettings`):** locale (`app_locale`/`localeCode`), launcher favorites/aliases, gas-log settings, and **sync network policy** (`sync.network_policy` roams via `SyncableSettings.syncSettings.networkPolicy`).
- Reconciliation of provider surfaces must preserve each provider's existing name, type, and method signatures. No feature call sites change (except free-function writers `setDatabasePath`/`setCloudStorageVaultPath`, whose call sites move to the controller — Task 4).
- Commit footer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: `AppSettings` model

**Files:**
- Create: `lib/core/settings/app_settings.dart`
- Test: `test/core/settings/app_settings_test.dart`

**Interfaces:**
- Produces: `class AppSettings` with the 11 fields + `int schemaVersion`; `const AppSettings.defaults`; `factory AppSettings.fromJson(Map<String,dynamic>)`; `Map<String,dynamic> toJson()`; `AppSettings copyWith({...})`. Enums come from existing files: `DataMode`, `CloudProvider` (`lib/core/data/data_mode.dart`), `ReceiptExtractorMode` (`lib/features/receipt_scan/domain/receipt_draft.dart`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/settings/app_settings.dart';
import 'package:hmm_console/features/receipt_scan/domain/receipt_draft.dart';

void main() {
  test('defaults match the legacy per-setting defaults', () {
    const s = AppSettings.defaults;
    expect(s.dataMode, DataMode.local);
    expect(s.cloudProvider, CloudProvider.onedrive);
    expect(s.geoCaptureEnabled, false);
    expect(s.receiptExtractorMode, ReceiptExtractorMode.onDevice);
    expect(s.receiptCloudConsent, false);
    expect(s.launcherRecents, const <String>[]);
    expect(s.notesFilterUsage, const <String, int>{});
    expect(s.dashboardIntroCardSeen, false);
    expect(s.onboardingCompleted, false);
    expect(s.localDbPath, isNull);
    expect(s.cloudStorageVaultPath, isNull);
    expect(s.schemaVersion, 1);
  });

  test('round-trips through JSON', () {
    const s = AppSettings(
      dataMode: DataMode.cloudApi,
      cloudProvider: CloudProvider.onedrive,
      geoCaptureEnabled: true,
      receiptExtractorMode: ReceiptExtractorMode.cloudAi,
      receiptCloudConsent: true,
      launcherRecents: ['a', 'b'],
      notesFilterUsage: {'notes': 3},
      dashboardIntroCardSeen: true,
      onboardingCompleted: true,
      localDbPath: '/tmp/x.db',
      cloudStorageVaultPath: '/Vault',
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.dataMode, DataMode.cloudApi);
    expect(back.receiptExtractorMode, ReceiptExtractorMode.cloudAi);
    expect(back.launcherRecents, ['a', 'b']);
    expect(back.notesFilterUsage, {'notes': 3});
    expect(back.localDbPath, '/tmp/x.db');
    expect(back.cloudStorageVaultPath, '/Vault');
  });

  test('fromJson fills missing keys with defaults and ignores unknowns', () {
    final s = AppSettings.fromJson({'dataMode': 'cloudStorage', 'zzz': 1});
    expect(s.dataMode, DataMode.cloudStorage);
    expect(s.onboardingCompleted, false); // missing -> default
  });

  test('copyWith changes only the named field', () {
    final s = AppSettings.defaults.copyWith(onboardingCompleted: true);
    expect(s.onboardingCompleted, true);
    expect(s.dataMode, DataMode.local);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/app_settings_test.dart`
Expected: FAIL — `app_settings.dart` does not exist.

- [ ] **Step 3: Implement the model**

Create `lib/core/settings/app_settings.dart`:

```dart
import '../data/data_mode.dart';
import '../../features/receipt_scan/domain/receipt_draft.dart';

/// One immutable, typed document holding every device-local setting. Persisted
/// as a single JSON blob (see SettingsController). Roaming settings and secrets
/// are NOT here.
class AppSettings {
  const AppSettings({
    this.dataMode = DataMode.local,
    this.cloudProvider = CloudProvider.onedrive,
    this.geoCaptureEnabled = false,
    this.receiptExtractorMode = ReceiptExtractorMode.onDevice,
    this.receiptCloudConsent = false,
    this.launcherRecents = const [],
    this.notesFilterUsage = const {},
    this.dashboardIntroCardSeen = false,
    this.onboardingCompleted = false,
    this.localDbPath,
    this.cloudStorageVaultPath,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;
  static const AppSettings defaults = AppSettings();

  final DataMode dataMode;
  final CloudProvider cloudProvider;
  final bool geoCaptureEnabled;
  final ReceiptExtractorMode receiptExtractorMode;
  final bool receiptCloudConsent;
  final List<String> launcherRecents;
  final Map<String, int> notesFilterUsage;
  final bool dashboardIntroCardSeen;
  final bool onboardingCompleted;
  final String? localDbPath;
  final String? cloudStorageVaultPath;
  final int schemaVersion;

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    DataMode dataMode() => switch (j['dataMode']) {
          'cloudStorage' => DataMode.cloudStorage,
          'cloudApi' || 'api' => DataMode.cloudApi,
          _ => DataMode.local,
        };
    final recents = (j['launcherRecents'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    final usage = (j['notesFilterUsage'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ) ??
        const <String, int>{};
    return AppSettings(
      dataMode: dataMode(),
      cloudProvider: CloudProvider.onedrive,
      geoCaptureEnabled: j['geoCaptureEnabled'] as bool? ?? false,
      receiptExtractorMode:
          ReceiptExtractorMode.fromWire(j['receiptExtractorMode'] as String?),
      receiptCloudConsent: j['receiptCloudConsent'] as bool? ?? false,
      launcherRecents: recents,
      notesFilterUsage: usage,
      dashboardIntroCardSeen: j['dashboardIntroCardSeen'] as bool? ?? false,
      onboardingCompleted: j['onboardingCompleted'] as bool? ?? false,
      localDbPath: j['localDbPath'] as String?,
      cloudStorageVaultPath: j['cloudStorageVaultPath'] as String?,
      schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'dataMode': dataMode.name,
        'cloudProvider': cloudProvider.name,
        'geoCaptureEnabled': geoCaptureEnabled,
        'receiptExtractorMode': receiptExtractorMode.wire,
        'receiptCloudConsent': receiptCloudConsent,
        'launcherRecents': launcherRecents,
        'notesFilterUsage': notesFilterUsage,
        'dashboardIntroCardSeen': dashboardIntroCardSeen,
        'onboardingCompleted': onboardingCompleted,
        if (localDbPath != null) 'localDbPath': localDbPath,
        if (cloudStorageVaultPath != null)
          'cloudStorageVaultPath': cloudStorageVaultPath,
        'schemaVersion': schemaVersion,
      };

  AppSettings copyWith({
    DataMode? dataMode,
    CloudProvider? cloudProvider,
    bool? geoCaptureEnabled,
    ReceiptExtractorMode? receiptExtractorMode,
    bool? receiptCloudConsent,
    List<String>? launcherRecents,
    Map<String, int>? notesFilterUsage,
    bool? dashboardIntroCardSeen,
    bool? onboardingCompleted,
    String? localDbPath,
    String? cloudStorageVaultPath,
  }) =>
      AppSettings(
        dataMode: dataMode ?? this.dataMode,
        cloudProvider: cloudProvider ?? this.cloudProvider,
        geoCaptureEnabled: geoCaptureEnabled ?? this.geoCaptureEnabled,
        receiptExtractorMode: receiptExtractorMode ?? this.receiptExtractorMode,
        receiptCloudConsent: receiptCloudConsent ?? this.receiptCloudConsent,
        launcherRecents: launcherRecents ?? this.launcherRecents,
        notesFilterUsage: notesFilterUsage ?? this.notesFilterUsage,
        dashboardIntroCardSeen:
            dashboardIntroCardSeen ?? this.dashboardIntroCardSeen,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        localDbPath: localDbPath ?? this.localDbPath,
        cloudStorageVaultPath:
            cloudStorageVaultPath ?? this.cloudStorageVaultPath,
        schemaVersion: schemaVersion,
      );
}
```

> Note: `copyWith` cannot null-out `localDbPath`/`cloudStorageVaultPath`. Clearing a vault path is done by writing a distinct value; the current app never nulls these after setting, so this matches existing behavior. If clearing is later needed, add sentinel setters — out of scope here.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/app_settings_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/core/settings/app_settings.dart test/core/settings/app_settings_test.dart
git commit -m "feat(settings): typed AppSettings model

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Legacy migration

**Files:**
- Create: `lib/core/settings/settings_migration.dart`
- Test: `test/core/settings/settings_migration_test.dart`

**Interfaces:**
- Consumes: `AppSettings` (Task 1).
- Produces: `AppSettings migrateFromLegacy(SharedPreferences prefs)` — reads the legacy keys into an `AppSettings`; missing keys → defaults; does NOT delete keys.

- [ ] **Step 1: Write the failing test (incl. connection-critical matrix)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/settings/settings_migration.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('empty prefs -> all defaults', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = migrateFromLegacy(prefs);
    expect(s.dataMode, DataMode.local);
    expect(s.onboardingCompleted, false);
  });

  test('reads scalar legacy keys', () async {
    SharedPreferences.setMockInitialValues({
      'geo_capture_enabled': true,
      'onboarding_completed': true,
      'local_db_path': '/tmp/x.db',
      'cloud_storage_vault_path': '/Vault',
      'launcher_recents': '["a","b"]',
      'notes.filter_usage': '{"notes":2}',
    });
    final prefs = await SharedPreferences.getInstance();
    final s = migrateFromLegacy(prefs);
    expect(s.geoCaptureEnabled, true);
    expect(s.onboardingCompleted, true);
    expect(s.localDbPath, '/tmp/x.db');
    expect(s.cloudStorageVaultPath, '/Vault');
    expect(s.launcherRecents, ['a', 'b']);
    expect(s.notesFilterUsage, {'notes': 2});
  });

  // Connection-critical matrix (refinement #3).
  for (final entry in {
    'local': DataMode.local,
    'cloudStorage': DataMode.cloudStorage,
    'cloudApi': DataMode.cloudApi,
    'api': DataMode.cloudApi, // legacy alias
  }.entries) {
    test('data_mode "${entry.key}" -> ${entry.value}', () async {
      SharedPreferences.setMockInitialValues({'data_mode': entry.key});
      final prefs = await SharedPreferences.getInstance();
      expect(migrateFromLegacy(prefs).dataMode, entry.value);
    });
  }

  test('does not delete legacy keys', () async {
    SharedPreferences.setMockInitialValues({'data_mode': 'cloudApi'});
    final prefs = await SharedPreferences.getInstance();
    migrateFromLegacy(prefs);
    expect(prefs.getString('data_mode'), 'cloudApi'); // retained
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/settings_migration_test.dart`
Expected: FAIL — `settings_migration.dart` does not exist.

- [ ] **Step 3: Implement the migration**

Create `lib/core/settings/settings_migration.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_mode.dart';
import '../../features/receipt_scan/domain/receipt_draft.dart';
import 'app_settings.dart';

/// Reads the pre-unification device-local keys into an [AppSettings].
/// Missing keys fall back to defaults. Legacy keys are NOT removed (retained
/// this release as a reversible safety net and as the corrupt-blob fallback
/// source for connection-critical fields).
AppSettings migrateFromLegacy(SharedPreferences prefs) {
  final dataMode = switch (prefs.getString('data_mode')) {
    'cloudStorage' => DataMode.cloudStorage,
    'cloudApi' || 'api' => DataMode.cloudApi,
    _ => DataMode.local,
  };

  List<String> recents() {
    final raw = prefs.getString('launcher_recents');
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, int> usage() {
    final raw = prefs.getString('notes.filter_usage');
    if (raw == null || raw.isEmpty) return const {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return const {};
    }
  }

  return AppSettings(
    dataMode: dataMode,
    cloudProvider: CloudProvider.onedrive,
    geoCaptureEnabled: prefs.getBool('geo_capture_enabled') ?? false,
    receiptExtractorMode:
        ReceiptExtractorMode.fromWire(prefs.getString('receipt_extractor_mode')),
    receiptCloudConsent: prefs.getBool('receipt_cloud_consent') ?? false,
    launcherRecents: recents(),
    notesFilterUsage: usage(),
    dashboardIntroCardSeen: prefs.getBool('dashboard_intro_card_seen') ?? false,
    onboardingCompleted: prefs.getBool('onboarding_completed') ?? false,
    localDbPath: prefs.getString('local_db_path'),
    cloudStorageVaultPath: prefs.getString('cloud_storage_vault_path'),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/settings_migration_test.dart`
Expected: PASS (all, including the 4 data_mode matrix cases).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/core/settings/settings_migration.dart test/core/settings/settings_migration_test.dart
git commit -m "feat(settings): one-time legacy-key migration (keys retained)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `SettingsController`

**Files:**
- Create: `lib/core/settings/settings_controller.dart`
- Test: `test/core/settings/settings_controller_test.dart`

**Interfaces:**
- Consumes: `AppSettings` (Task 1), `migrateFromLegacy` (Task 2).
- Produces: `class SettingsController extends AsyncNotifier<AppSettings>` with typed setters (`setDataMode`, `setCloudProvider`, `setGeoCaptureEnabled`, `setReceiptExtractorMode`, `setReceiptCloudConsent`, `setLauncherRecents`, `setNotesFilterUsage`, `setDashboardIntroCardSeen`, `setOnboardingCompleted`, `setLocalDbPath`, `setCloudStorageVaultPath`); `final settingsProvider = AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);`. Blob key: `app_settings`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('empty prefs -> defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = await c.read(settingsProvider.future);
    expect(s.dataMode, DataMode.local);
  });

  test('migrates legacy keys on first load and writes the blob', () async {
    SharedPreferences.setMockInitialValues({'data_mode': 'cloudApi'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = await c.read(settingsProvider.future);
    expect(s.dataMode, DataMode.cloudApi);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_settings'), isNotNull); // blob written
  });

  test('setDataMode persists and re-emits', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    await c.read(settingsProvider.notifier).setDataMode(DataMode.cloudStorage);
    expect(c.read(settingsProvider).value!.dataMode, DataMode.cloudStorage);
  });

  test('corrupt blob falls back to legacy for connection-critical fields',
      () async {
    SharedPreferences.setMockInitialValues({
      'app_settings': 'not-json{{',
      'data_mode': 'cloudApi', // legacy retained
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = await c.read(settingsProvider.future);
    expect(s.dataMode, DataMode.cloudApi); // legacy, not default local
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/settings_controller_test.dart`
Expected: FAIL — `settings_controller.dart` does not exist.

- [ ] **Step 3: Implement the controller**

Create `lib/core/settings/settings_controller.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_mode.dart';
import '../../features/receipt_scan/domain/receipt_draft.dart';
import 'app_settings.dart';
import 'settings_migration.dart';

const _blobKey = 'app_settings';

/// Single owner of the device-local settings blob. On first load it decodes
/// the blob, or migrates the legacy keys, or (on a corrupt blob) falls back to
/// the retained legacy keys so connection-critical settings are never lost.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_blobKey);
    if (raw == null) {
      final migrated = migrateFromLegacy(prefs);
      await _persist(prefs, migrated);
      return migrated;
    }
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('SettingsController: corrupt app_settings blob ($e); '
          'falling back to legacy keys.');
      // Legacy keys are retained this release: recover connection-critical
      // (and everything else) rather than dropping to blind defaults.
      return migrateFromLegacy(prefs);
    }
  }

  Future<void> _persist(SharedPreferences prefs, AppSettings s) async {
    try {
      await prefs.setString(_blobKey, jsonEncode(s.toJson()));
    } catch (e) {
      debugPrint('SettingsController: persist failed ($e); keeping in-memory.');
    }
  }

  Future<void> _update(AppSettings next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await _persist(prefs, next);
  }

  AppSettings get _current => state.value ?? AppSettings.defaults;

  Future<void> setDataMode(DataMode v) =>
      _update(_current.copyWith(dataMode: v));
  Future<void> setCloudProvider(CloudProvider v) =>
      _update(_current.copyWith(cloudProvider: v));
  Future<void> setGeoCaptureEnabled(bool v) =>
      _update(_current.copyWith(geoCaptureEnabled: v));
  Future<void> setReceiptExtractorMode(ReceiptExtractorMode v) =>
      _update(_current.copyWith(receiptExtractorMode: v));
  Future<void> setReceiptCloudConsent(bool v) =>
      _update(_current.copyWith(receiptCloudConsent: v));
  Future<void> setLauncherRecents(List<String> v) =>
      _update(_current.copyWith(launcherRecents: v));
  Future<void> setNotesFilterUsage(Map<String, int> v) =>
      _update(_current.copyWith(notesFilterUsage: v));
  Future<void> setDashboardIntroCardSeen(bool v) =>
      _update(_current.copyWith(dashboardIntroCardSeen: v));
  Future<void> setOnboardingCompleted(bool v) =>
      _update(_current.copyWith(onboardingCompleted: v));
  Future<void> setLocalDbPath(String v) =>
      _update(_current.copyWith(localDbPath: v));
  Future<void> setCloudStorageVaultPath(String v) =>
      _update(_current.copyWith(cloudStorageVaultPath: v));
}

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/settings_controller_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/core/settings/settings_controller.dart test/core/settings/settings_controller_test.dart
git commit -m "feat(settings): SettingsController owning the app_settings blob

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Re-point connection-critical owners

**Files:**
- Modify: `lib/core/data/data_mode.dart` (`DataModeNotifier`, `CloudProviderNotifier`, `databasePathProvider`, `updateDatabasePath`)
- Modify: `lib/core/data/attachments/attachment_providers.dart` (vault-path read + `setCloudStorageVaultPath`)
- Modify (call sites of the free writers): `lib/features/settings/presentation/screens/settings_screen.dart`
- Test: `test/core/settings/settings_delegation_test.dart`

**Interfaces:**
- Consumes: `settingsProvider` + `SettingsController` setters (Task 3).
- Produces: unchanged public surfaces `dataModeProvider`, `cloudProviderProvider`, `databasePathProvider`, `cloudStorageVaultPathProvider`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dataModeProvider reflects and writes through the controller', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future); // ensure loaded

    await c.read(dataModeProvider.notifier).setMode(DataMode.cloudApi);
    expect(c.read(dataModeProvider), DataMode.cloudApi);
    expect(c.read(settingsProvider).value!.dataMode, DataMode.cloudApi);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_settings'), contains('cloudApi'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/settings_delegation_test.dart`
Expected: FAIL — `DataModeNotifier` still reads its own key; the blob is not written by `setMode`.

- [ ] **Step 3: Re-point `data_mode.dart`**

In `lib/core/data/data_mode.dart`: add `import '../settings/settings_controller.dart';` (keep the `DataMode`/`CloudProvider` enums unchanged). Replace `DataModeNotifier`, `CloudProviderNotifier`, and `databasePathProvider`/`updateDatabasePath` with delegating versions:

```dart
class DataModeNotifier extends Notifier<DataMode> {
  @override
  DataMode build() =>
      ref.watch(settingsProvider).valueOrNull?.dataMode ?? DataMode.local;

  Future<void> setMode(DataMode mode) =>
      ref.read(settingsProvider.notifier).setDataMode(mode);
}

class CloudProviderNotifier extends Notifier<CloudProvider> {
  @override
  CloudProvider build() =>
      ref.watch(settingsProvider).valueOrNull?.cloudProvider ??
      CloudProvider.onedrive;

  Future<void> setProvider(CloudProvider provider) =>
      ref.read(settingsProvider.notifier).setCloudProvider(provider);
}
```

Replace `databasePathProvider` / `updateDatabasePath` with:

```dart
final databasePathProvider = FutureProvider<String>((ref) async {
  final custom = ref.watch(settingsProvider).valueOrNull?.localDbPath;
  if (custom != null && custom.isNotEmpty) return custom;
  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'hmm.db');
});
```

Delete `updateDatabasePath` and the now-unused `SharedPreferences` import if no longer referenced in the file. (Callers of `updateDatabasePath`, if any, switch to `ref.read(settingsProvider.notifier).setLocalDbPath(path)`; grep `updateDatabasePath`/`setDatabasePath` and update them.)

- [ ] **Step 4: Re-point the vault-path owner**

In `lib/core/data/attachments/attachment_providers.dart`: the `cloudStorageVaultPathProvider` reads `settingsProvider`; the free `setCloudStorageVaultPath` becomes a controller call. Replace the `_vaultPathKey` read (lines ~37-49) so the provider returns `ref.watch(settingsProvider).valueOrNull?.cloudStorageVaultPath`, and convert `setCloudStorageVaultPath(String?)` call sites in `settings_screen.dart` to `ref.read(settingsProvider.notifier).setCloudStorageVaultPath(path)` (choose-folder) — the "clear" path (`setCloudStorageVaultPath(null)`) is handled by writing an empty string, matching the provider's `isNotEmpty` guard. Show the exact new provider body:

```dart
// cloud_storage_vault_path now lives in AppSettings; read it from there.
final cloudStorageVaultPathProvider = Provider<String?>((ref) {
  final v = ref.watch(settingsProvider).valueOrNull?.cloudStorageVaultPath;
  return (v != null && v.isNotEmpty) ? v : null;
});
```

(Match the existing provider name/type in that file; if it is currently a `FutureProvider`, keep that shape and `await ref.watch(settingsProvider.future)`.)

- [ ] **Step 5: Run test + analyze**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/settings_delegation_test.dart && flutter analyze lib/core/data/data_mode.dart lib/core/data/attachments/attachment_providers.dart`
Expected: PASS; `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd ~/projects/hmm_console
git add lib/core/data/data_mode.dart lib/core/data/attachments/attachment_providers.dart lib/features/settings/presentation/screens/settings_screen.dart test/core/settings/settings_delegation_test.dart
git commit -m "refactor(settings): delegate connection-critical settings to controller

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Re-point the remaining device-local owners

**Files:**
- Modify: `lib/features/settings/providers/geo_capture_provider.dart`
- Modify: `lib/features/receipt_scan/providers/receipt_extractor_providers.dart`
- Modify: `lib/features/receipt_scan/presentation/receipt_extraction_settings_section.dart` (consent read/write)
- Modify: `lib/features/launcher/providers/launcher_recents_provider.dart`
- Modify: `lib/features/notes/states/filter_usage.dart`
- Modify: `lib/features/dashboard/providers/intro_card_provider.dart`
- Modify: `lib/features/onboarding/providers/onboarding_provider.dart`
- Test: extend `test/core/settings/settings_delegation_test.dart`

**Interfaces:**
- Consumes: `settingsProvider` + setters (Task 3). Public surfaces unchanged.

- [ ] **Step 1: Write the failing test**

Add to `test/core/settings/settings_delegation_test.dart`:

```dart
  test('onboarding + geo-capture delegate to the controller', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);

    await c.read(onboardingCompletedProvider.notifier).markCompleted();
    expect(c.read(settingsProvider).value!.onboardingCompleted, true);

    await c.read(geoCaptureEnabledProvider.notifier).setEnabled(true);
    expect(c.read(settingsProvider).value!.geoCaptureEnabled, true);
  });
```

(Imports: `onboarding_provider.dart`, `geo_capture_provider.dart`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/settings_delegation_test.dart`
Expected: FAIL — those notifiers still write their own keys, not the blob.

- [ ] **Step 3: Re-point each owner**

Each keeps its provider name/type; internals delegate. New bodies:

`geo_capture_provider.dart` (`AsyncNotifier<bool>` — await the loaded settings):
```dart
class GeoCaptureNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      (await ref.watch(settingsProvider.future)).geoCaptureEnabled;

  Future<void> setEnabled(bool value) =>
      ref.read(settingsProvider.notifier).setGeoCaptureEnabled(value);
}
```

`receipt_extractor_providers.dart` (`ReceiptExtractorModeNotifier`):
```dart
class ReceiptExtractorModeNotifier extends Notifier<ReceiptExtractorMode> {
  @override
  ReceiptExtractorMode build() =>
      ref.watch(settingsProvider).valueOrNull?.receiptExtractorMode ??
      ReceiptExtractorMode.onDevice;

  Future<void> setMode(ReceiptExtractorMode mode) =>
      ref.read(settingsProvider.notifier).setReceiptExtractorMode(mode);
}
```

`intro_card_provider.dart` (`IntroCardSeenNotifier`):
```dart
class IntroCardSeenNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsProvider).valueOrNull?.dashboardIntroCardSeen ?? false;

  Future<void> markSeen() =>
      ref.read(settingsProvider.notifier).setDashboardIntroCardSeen(true);
}
```

`onboarding_provider.dart` (`OnboardingCompletedNotifier`; keep `reset()` for tests → sets false via controller):
```dart
class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsProvider).valueOrNull?.onboardingCompleted ?? false;

  Future<void> markCompleted() =>
      ref.read(settingsProvider.notifier).setOnboardingCompleted(true);

  Future<void> reset() =>
      ref.read(settingsProvider.notifier).setOnboardingCompleted(false);
}
```

`launcher_recents_provider.dart` (`LauncherRecentsNotifier`; keep the cap + dedup logic, persist via controller):
```dart
const _cap = 8;

class LauncherRecentsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() =>
      ref.watch(settingsProvider).valueOrNull?.launcherRecents ?? const [];

  Future<void> record(String id) {
    final next = [id, ...state.where((x) => x != id)].take(_cap).toList();
    return ref.read(settingsProvider.notifier).setLauncherRecents(next);
  }
}
```

`filter_usage.dart` (`FilterUsageNotifier`, `AsyncNotifier`; keep increment logic):
```dart
class FilterUsageNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async =>
      (await ref.watch(settingsProvider.future)).notesFilterUsage;

  Future<void> record(String domainKey) {
    final current = Map<String, int>.from(state.value ?? const {});
    current[domainKey] = (current[domainKey] ?? 0) + 1;
    return ref.read(settingsProvider.notifier).setNotesFilterUsage(current);
  }
}
```

`receipt_extraction_settings_section.dart` (consent): replace the inline `prefs.getBool(_consentKey)` read and `prefs.setBool(_consentKey, true)` write with `ref.watch(settingsProvider).valueOrNull?.receiptCloudConsent ?? false` and `ref.read(settingsProvider.notifier).setReceiptCloudConsent(true)`. Remove the now-unused `_consentKey`/`SharedPreferences` usage in that file.

For each file: add `import '.../core/settings/settings_controller.dart';`, delete the now-unused `_key`/`_prefsKey`/`SharedPreferences` imports, and drop the old `_load`/`_loadFromPrefs` methods.

- [ ] **Step 4: Run test + analyze + full suite**

Run: `cd ~/projects/hmm_console && flutter test test/core/settings/settings_delegation_test.dart && flutter analyze lib/features && flutter test`
Expected: delegation test PASS; `No issues found!`; `All tests passed!`

- [ ] **Step 5: Commit**

```bash
cd ~/projects/hmm_console
git add lib/features/settings/providers/geo_capture_provider.dart lib/features/receipt_scan/providers/receipt_extractor_providers.dart lib/features/receipt_scan/presentation/receipt_extraction_settings_section.dart lib/features/launcher/providers/launcher_recents_provider.dart lib/features/notes/states/filter_usage.dart lib/features/dashboard/providers/intro_card_provider.dart lib/features/onboarding/providers/onboarding_provider.dart test/core/settings/settings_delegation_test.dart
git commit -m "refactor(settings): delegate remaining device-local settings to controller

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Whole-branch review, merge, verify

- [ ] **Step 1:** Dispatch a final code-reviewer over the branch diff (`git diff main...HEAD`), with the Global Constraints as the rubric — focus: connection-critical corrupt-blob fallback correctness, no roaming/secret settings pulled in, every delegating provider preserves its surface + behavior (recents cap/dedup, filter increment), migration retains legacy keys.
- [ ] **Step 2:** Fix any Critical/Important findings (one fix pass).
- [ ] **Step 3:** `flutter test` (full suite green) and `flutter analyze` (clean) on the merged result; merge to `main` via `superpowers:finishing-a-development-branch`.
- [ ] **Step 4:** Manual device check: fresh-install migration path — set a couple of legacy prefs, launch, confirm `data_mode`/onboarding/geo-capture survive; toggle Data mode in Settings and confirm it round-trips. (No backend/device-pairing involved.)

---

## Self-Review

**Spec coverage:** `AppSettings` model → Task 1; migration (retain keys, connection-critical matrix) → Task 2; `SettingsController` (blob load/decode/migrate/corrupt-fallback/persist/setters) → Task 3; connection-critical delegation (dataMode/cloudProvider/localDbPath/vaultPath) → Task 4; remaining delegation → Task 5; review/merge/verify → Task 6. Boundary exclusions (locale, launcher favorites, gas-log, **sync network policy**) are never added — verified against the field list. ✓

**Placeholder scan:** every code step contains complete code; the two "match the existing shape" notes (vault-path provider type, `updateDatabasePath` callers) are explicit conditional instructions, not vague requirements — the implementer greps and applies. ✓

**Type consistency:** `settingsProvider` is `AsyncNotifierProvider` throughout; sync consumers use `.valueOrNull?.field ?? default`, async consumers `await ref.watch(settingsProvider.future)`; setter names (`setDataMode`… `setCloudStorageVaultPath`) match Task 3's definitions and Tasks 4–5's calls; `AppSettings` field names match across model/migration/controller/providers. ✓
