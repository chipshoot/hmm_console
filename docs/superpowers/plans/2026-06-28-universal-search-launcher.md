# Universal Search Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A home-screen search box where a leading `/` triggers fuzzy "function search" that jumps to any feature/sub-screen (with smart vehicle-context resolution, synced favorites + aliases, device-local recents), while plain text is reserved for a future AI-assistant prompt (a stub in v1).

**Architecture:** A pure, Flutter-free **domain core** (destination registry, input-mode detector, fuzzy matcher, vehicle-resolution decision, prefs model) sits under thin Riverpod **providers** (synced prefs via the existing `SyncableSettings` bundle; device-local recents via `shared_preferences`) and **presentation** (a focused full-screen search route that branches on input mode, plus a Settings-reached manage screen). Navigation reuses GoRouter named routes; vehicle scoping reuses `selectedAutomobileIdProvider` + `automobilesStateProvider`. No backend change.

**Tech Stack:** Flutter, Riverpod 3 (`Notifier`/`AsyncNotifier`/`NotifierProvider`), GoRouter (named routes), `shared_preferences`, `flutter_platform_widgets`, `flutter_test`.

---

## File Structure

**New (all under `lib/features/launcher/`):**
- `domain/launcher_destination.dart` — `LauncherDestination` value type.
- `domain/launcher_registry.dart` — `const launcherDestinations` + `launcherDestinationsById` lookup.
- `domain/launcher_input_mode.dart` — `LauncherInputMode` enum + `modeOf` / `commandQuery`.
- `domain/launcher_matcher.dart` — pure `match(...)` ranking.
- `domain/launcher_prefs.dart` — `LauncherPrefs {favorites, aliases}` model.
- `domain/vehicle_resolution.dart` — pure `pickVehicle(...)` + `resolveTarget(...)` + `LaunchTarget`.
- `providers/launcher_prefs_provider.dart` — `LauncherPrefsNotifier` (synced).
- `providers/launcher_recents_provider.dart` — `LauncherRecentsNotifier` (device-local).
- `presentation/launcher_navigation.dart` — `launchDestination(context, ref, dest)` (executes a `LaunchTarget`).
- `presentation/launcher_search_screen.dart` — the search route.
- `presentation/launcher_manage_screen.dart` — favorites + aliases editor.

**Modified:**
- `lib/features/settings/domain/syncable_settings.dart` — add `launcher` field.
- `lib/features/settings/data/syncable_settings_repository.dart` — read/apply `launcher_prefs` key.
- `lib/core/navigation/route_names.dart` — add `launcherSearch`, `launcherManage`.
- `lib/core/navigation/router_config.dart` — wire the two routes.
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — search bar opens the launcher route.
- `lib/features/settings/presentation/screens/settings_screen.dart` — add "Manage launcher" link.

**Test files mirror the source paths under `test/features/launcher/...`.**

---

## Task 1: Destination registry + value type

**Files:**
- Create: `lib/features/launcher/domain/launcher_destination.dart`
- Create: `lib/features/launcher/domain/launcher_registry.dart`
- Test: `test/features/launcher/domain/launcher_registry_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/domain/launcher_registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/launcher/domain/launcher_registry.dart';

void main() {
  final names = RouterNames.values.map((r) => r.name).toSet();

  test('every destination routeName is a real RouterNames value', () {
    for (final d in launcherDestinations) {
      expect(names.contains(d.routeName), isTrue,
          reason: '${d.id} -> ${d.routeName} is not a RouterNames value');
    }
  });

  test('ids are unique', () {
    final ids = launcherDestinations.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('usesVehiclePathId implies needsVehicle', () {
    for (final d in launcherDestinations) {
      if (d.usesVehiclePathId) expect(d.needsVehicle, isTrue, reason: d.id);
    }
  });

  test('lookup map resolves a known id and returns null for unknown', () {
    expect(launcherDestinationsById['gasLog']?.title, 'Gas Log');
    expect(launcherDestinationsById['nope'], isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/domain/launcher_registry_test.dart > /tmp/t1.log 2>&1; echo "EXIT $?"`
Expected: FAIL — `launcher_registry.dart` doesn't exist (compile error / EXIT non-zero).

- [ ] **Step 3: Write the value type**

```dart
// lib/features/launcher/domain/launcher_destination.dart
import 'package:flutter/widgets.dart';

/// A place the launcher can jump to (a feature screen or sub-screen).
/// Destinations are app navigation targets, not data entities.
@immutable
class LauncherDestination {
  const LauncherDestination({
    required this.id,
    required this.title,
    required this.icon,
    required this.routeName,
    this.synonyms = const [],
    this.needsVehicle = false,
    this.usesVehiclePathId = false,
  });

  /// Stable id (e.g. 'gasLog'); used by favorites/recents/aliases.
  final String id;
  final String title;
  final List<String> synonyms;
  final IconData icon;

  /// A `RouterNames` value's `.name`.
  final String routeName;

  /// True if the destination is scoped to a vehicle (must resolve one
  /// before navigating).
  final bool needsVehicle;

  /// True if the route takes the vehicle id as an `:id` path parameter
  /// (service/scheduled/insurance/vehicle-notes). False for Gas Log,
  /// which scopes via `selectedAutomobileIdProvider` and has no path id.
  final bool usesVehiclePathId;
}
```

- [ ] **Step 4: Write the registry**

```dart
// lib/features/launcher/domain/launcher_registry.dart
import 'package:flutter/material.dart';

import '../../../core/navigation/route_names.dart';
import 'launcher_destination.dart';

/// Single source of truth for launcher destinations. Seeded from the
/// existing GoRouter named routes.
const List<LauncherDestination> launcherDestinations = [
  LauncherDestination(
    id: 'vehicles',
    title: 'Vehicles',
    synonyms: ['car', 'vehicle', 'auto', 'automobile', 'garage', 'manage cars'],
    icon: Icons.directions_car,
    routeName: 'automobileManagement', // RouterNames.automobileManagement.name
  ),
  LauncherDestination(
    id: 'gasLog',
    title: 'Gas Log',
    synonyms: ['gas', 'fuel', 'fill-up', 'petrol', 'mileage', 'fuel log'],
    icon: Icons.local_gas_station,
    routeName: 'gasLogList',
    needsVehicle: true,
    usesVehiclePathId: false, // scopes via selectedAutomobileIdProvider
  ),
  LauncherDestination(
    id: 'serviceRecords',
    title: 'Service Log',
    synonyms: ['service', 'maintenance', 'repair', 'car service', 'service record'],
    icon: Icons.build,
    routeName: 'serviceRecords',
    needsVehicle: true,
    usesVehiclePathId: true,
  ),
  LauncherDestination(
    id: 'scheduledServices',
    title: 'Scheduled Services',
    synonyms: ['scheduled', 'reminder', 'upcoming service', 'maintenance schedule'],
    icon: Icons.event,
    routeName: 'scheduledServices',
    needsVehicle: true,
    usesVehiclePathId: true,
  ),
  LauncherDestination(
    id: 'insurance',
    title: 'Insurance',
    synonyms: ['insurance', 'policy', 'coverage'],
    icon: Icons.shield,
    routeName: 'insurancePolicies',
    needsVehicle: true,
    usesVehiclePathId: true,
  ),
  LauncherDestination(
    id: 'vehicleNotes',
    title: 'Vehicle Notes',
    synonyms: ['vehicle notes', 'car notes'],
    icon: Icons.note_alt,
    routeName: 'vehicleNotes',
    needsVehicle: true,
    usesVehiclePathId: true,
  ),
  LauncherDestination(
    id: 'notes',
    title: 'Notes',
    synonyms: ['note', 'notes', 'journal', 'memo'],
    icon: Icons.description,
    routeName: 'notesList',
  ),
  LauncherDestination(
    id: 'gasStations',
    title: 'Gas Stations',
    synonyms: ['station', 'gas station', 'fuel station', 'discount'],
    icon: Icons.ev_station,
    routeName: 'gasStationManagement',
  ),
  LauncherDestination(
    id: 'settings',
    title: 'Settings',
    synonyms: ['settings', 'preferences', 'config', 'options'],
    icon: Icons.settings,
    routeName: 'settings',
  ),
];

/// id -> destination lookup for resolving favorites/recents/aliases.
final Map<String, LauncherDestination> launcherDestinationsById = {
  for (final d in launcherDestinations) d.id: d,
};
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/launcher/domain/launcher_registry_test.dart > /tmp/t1.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0. (All `routeName`s above match values in `RouterNames`.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/launcher/domain/launcher_destination.dart lib/features/launcher/domain/launcher_registry.dart test/features/launcher/domain/launcher_registry_test.dart
git commit -m "feat(launcher): destination value type + registry

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Input-mode detection

**Files:**
- Create: `lib/features/launcher/domain/launcher_input_mode.dart`
- Test: `test/features/launcher/domain/launcher_input_mode_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/domain/launcher_input_mode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_input_mode.dart';

void main() {
  test('modeOf classifies input', () {
    expect(modeOf(''), LauncherInputMode.empty);
    expect(modeOf('   '), LauncherInputMode.empty);
    expect(modeOf('/'), LauncherInputMode.command);
    expect(modeOf('/gas'), LauncherInputMode.command);
    expect(modeOf('  /gas'), LauncherInputMode.command);
    expect(modeOf('gas'), LauncherInputMode.assistant);
  });

  test('commandQuery returns the text after the slash, trimmed', () {
    expect(commandQuery('/gas'), 'gas');
    expect(commandQuery('  /  gas log '), 'gas log');
    expect(commandQuery('/'), '');
    expect(commandQuery('gas'), ''); // not command mode
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/domain/launcher_input_mode_test.dart > /tmp/t2.log 2>&1; echo "EXIT $?"`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/launcher/domain/launcher_input_mode.dart

/// How the home search box interprets the current input.
enum LauncherInputMode {
  /// Nothing typed (or only whitespace) -> show the favorites/recents landing.
  empty,

  /// Leading '/' -> function search (the launcher).
  command,

  /// Plain text -> reserved for the future AI assistant (a stub in v1).
  assistant,
}

/// Classifies raw input. Leading whitespace is tolerated before '/'.
LauncherInputMode modeOf(String raw) {
  final t = raw.trimLeft();
  if (t.trim().isEmpty) return LauncherInputMode.empty;
  if (t.startsWith('/')) return LauncherInputMode.command;
  return LauncherInputMode.assistant;
}

/// The command-mode query: the text after the leading '/', trimmed.
/// Returns '' when not in command mode or when only '/' was typed.
String commandQuery(String raw) {
  final t = raw.trimLeft();
  if (!t.startsWith('/')) return '';
  return t.substring(1).trim();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/launcher/domain/launcher_input_mode_test.dart > /tmp/t2.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/launcher/domain/launcher_input_mode.dart test/features/launcher/domain/launcher_input_mode_test.dart
git commit -m "feat(launcher): input-mode detection ('/' = command, text = assistant)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Fuzzy matcher

**Files:**
- Create: `lib/features/launcher/domain/launcher_matcher.dart`
- Test: `test/features/launcher/domain/launcher_matcher_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/domain/launcher_matcher_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_destination.dart';
import 'package:hmm_console/features/launcher/domain/launcher_matcher.dart';

const _reg = [
  LauncherDestination(
      id: 'gasLog', title: 'Gas Log', synonyms: ['fuel'], icon: Icons.abc, routeName: 'gasLogList'),
  LauncherDestination(
      id: 'serviceRecords', title: 'Service Log', synonyms: ['maintenance'], icon: Icons.abc, routeName: 'serviceRecords'),
  LauncherDestination(
      id: 'settings', title: 'Settings', synonyms: [], icon: Icons.abc, routeName: 'settings'),
];

List<String> _ids(String q, {Map<String, String> aliases = const {}}) =>
    match(q, registry: _reg, aliases: aliases).map((d) => d.id).toList();

void main() {
  test('empty / slash-only query returns nothing', () {
    expect(_ids(''), isEmpty);
    expect(_ids('/'), isEmpty);
    expect(_ids('   '), isEmpty);
  });

  test('prefix matches, alpha-sorted within a rank', () {
    // 'se' is a prefix of both "Service Log" and "Settings" (rank 3);
    // tie broken alphabetically by title.
    expect(_ids('se'), ['serviceRecords', 'settings']);
  });

  test('synonym matches', () {
    expect(_ids('fuel'), ['gasLog']);
    expect(_ids('maintenance'), ['serviceRecords']);
  });

  test('leading slash is stripped before matching', () {
    expect(_ids('/fuel'), ['gasLog']);
  });

  test('subsequence fuzzy match on title', () {
    expect(_ids('slog').contains('serviceRecords'), isTrue); // S-(ervice )-L-o-g
  });

  test('exact alias ranks above everything', () {
    // alias 'st' -> settings; 'st' is also a subsequence of "Settings".
    expect(_ids('st', aliases: {'st': 'settings'}).first, 'settings');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/domain/launcher_matcher_test.dart > /tmp/t3.log 2>&1; echo "EXIT $?"`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/launcher/domain/launcher_matcher.dart
import 'launcher_destination.dart';

/// Ranks destinations against a command-mode query. Highest first:
///   4 exact alias, 3 title/synonym prefix, 2 substring, 1 subsequence.
/// Ties broken alphabetically by title. Empty query -> const [].
/// Pure (no Flutter beyond the value type) — unit-tested in isolation.
List<LauncherDestination> match(
  String query, {
  required List<LauncherDestination> registry,
  required Map<String, String> aliases,
}) {
  var q = query.trim().toLowerCase();
  if (q.startsWith('/')) q = q.substring(1).trim();
  if (q.isEmpty) return const [];

  final ranked = <_Ranked>[];
  for (final d in registry) {
    final r = _rank(q, d, aliases);
    if (r > 0) ranked.add(_Ranked(r, d));
  }
  ranked.sort((a, b) {
    if (a.rank != b.rank) return b.rank.compareTo(a.rank);
    return a.dest.title.toLowerCase().compareTo(b.dest.title.toLowerCase());
  });
  return ranked.map((e) => e.dest).toList();
}

int _rank(String q, LauncherDestination d, Map<String, String> aliases) {
  if (aliases[q] == d.id) return 4;
  final hays = [d.title.toLowerCase(), ...d.synonyms.map((s) => s.toLowerCase())];
  if (hays.any((h) => h.startsWith(q))) return 3;
  if (hays.any((h) => h.contains(q))) return 2;
  if (_isSubsequence(q, d.title.toLowerCase())) return 1;
  return 0;
}

bool _isSubsequence(String needle, String haystack) {
  var i = 0;
  for (var j = 0; j < haystack.length && i < needle.length; j++) {
    if (needle[i] == haystack[j]) i++;
  }
  return i == needle.length;
}

class _Ranked {
  const _Ranked(this.rank, this.dest);
  final int rank;
  final LauncherDestination dest;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/launcher/domain/launcher_matcher_test.dart > /tmp/t3.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/launcher/domain/launcher_matcher.dart test/features/launcher/domain/launcher_matcher_test.dart
git commit -m "feat(launcher): fuzzy matcher (alias>prefix>substring>subsequence)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: LauncherPrefs model

**Files:**
- Create: `lib/features/launcher/domain/launcher_prefs.dart`
- Test: `test/features/launcher/domain/launcher_prefs_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/domain/launcher_prefs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_prefs.dart';

void main() {
  test('round-trips through json', () {
    const p = LauncherPrefs(favorites: ['gasLog', 'notes'], aliases: {'cs': 'serviceRecords'});
    final back = LauncherPrefs.fromJson(p.toJson());
    expect(back.favorites, ['gasLog', 'notes']);
    expect(back.aliases, {'cs': 'serviceRecords'});
  });

  test('json string round-trip', () {
    const p = LauncherPrefs(favorites: ['x'], aliases: {'a': 'b'});
    expect(LauncherPrefs.fromJsonString(p.toJsonString()).aliases, {'a': 'b'});
  });

  test('absent / malformed fields default to empty', () {
    expect(LauncherPrefs.fromJson(const {}).favorites, isEmpty);
    expect(LauncherPrefs.fromJson(const {}).aliases, isEmpty);
    // wrong types are dropped, not thrown
    final p = LauncherPrefs.fromJson({'favorites': [1, 'ok'], 'aliases': {'k': 2}});
    expect(p.favorites, ['ok']);
    expect(p.aliases, isEmpty);
  });

  test('copyWith replaces fields', () {
    const p = LauncherPrefs(favorites: ['a'], aliases: {});
    expect(p.copyWith(favorites: ['b']).favorites, ['b']);
    expect(p.copyWith(aliases: {'x': 'y'}).aliases, {'x': 'y'});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/domain/launcher_prefs_test.dart > /tmp/t4.log 2>&1; echo "EXIT $?"`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/launcher/domain/launcher_prefs.dart
import 'dart:convert';

/// User-customizable launcher prefs: pinned [favorites] (destination
/// ids, ordered) and [aliases] (alias text -> destination id). Synced
/// across devices inside the SyncableSettings bundle.
class LauncherPrefs {
  const LauncherPrefs({this.favorites = const [], this.aliases = const {}});

  final List<String> favorites;
  final Map<String, String> aliases;

  static const empty = LauncherPrefs();

  LauncherPrefs copyWith({List<String>? favorites, Map<String, String>? aliases}) =>
      LauncherPrefs(
        favorites: favorites ?? this.favorites,
        aliases: aliases ?? this.aliases,
      );

  Map<String, dynamic> toJson() => {
        'favorites': favorites,
        'aliases': aliases,
      };

  /// Tolerant decode: wrong-typed entries are dropped (the bundle is
  /// synced opaquely across client versions, so never throw).
  factory LauncherPrefs.fromJson(Map<String, dynamic> json) {
    final favs = (json['favorites'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final aliases = <String, String>{};
    final rawAliases = json['aliases'];
    if (rawAliases is Map) {
      rawAliases.forEach((k, v) {
        if (k is String && v is String) aliases[k] = v;
      });
    }
    return LauncherPrefs(favorites: favs, aliases: aliases);
  }

  String toJsonString() => jsonEncode(toJson());

  factory LauncherPrefs.fromJsonString(String s) =>
      LauncherPrefs.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/launcher/domain/launcher_prefs_test.dart > /tmp/t4.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/launcher/domain/launcher_prefs.dart test/features/launcher/domain/launcher_prefs_test.dart
git commit -m "feat(launcher): LauncherPrefs model (favorites + aliases)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Wire LauncherPrefs into SyncableSettings + repository

**Files:**
- Modify: `lib/features/settings/domain/syncable_settings.dart`
- Modify: `lib/features/settings/data/syncable_settings_repository.dart`
- Test: `test/features/settings/syncable_settings_launcher_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/syncable_settings_launcher_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_prefs.dart';
import 'package:hmm_console/features/settings/domain/syncable_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('launcher prefs survive the bundle json round-trip', () {
    final s = SyncableSettings.defaults().copyWith(
      launcher: const LauncherPrefs(favorites: ['gasLog'], aliases: {'cs': 'serviceRecords'}),
    );
    final back = SyncableSettings.fromJson(s.toJson());
    expect(back.launcher.favorites, ['gasLog']);
    expect(back.launcher.aliases, {'cs': 'serviceRecords'});
  });

  test('absent launcher field decodes to empty prefs', () {
    final json = SyncableSettings.defaults().toJson()..remove('launcher');
    expect(SyncableSettings.fromJson(json).launcher.favorites, isEmpty);
  });

  test('repository read/apply persists launcher prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SyncableSettingsRepository();
    final s = SyncableSettings.defaults().copyWith(
      launcher: const LauncherPrefs(favorites: ['notes'], aliases: {}),
    );
    await repo.apply(s);
    final read = await repo.read();
    expect(read.launcher.favorites, ['notes']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/syncable_settings_launcher_test.dart > /tmp/t5.log 2>&1; echo "EXIT $?"`
Expected: FAIL — `SyncableSettings` has no `launcher` getter/param.

- [ ] **Step 3a: Add the field to `syncable_settings.dart`**

Add the import near the top (after the existing imports):

```dart
import '../../launcher/domain/launcher_prefs.dart';
```

Add the constructor parameter (defaulted so existing call sites still compile) — change the constructor to:

```dart
  const SyncableSettings({
    required this.gasLog,
    required this.syncSettings,
    required this.localeCode,
    required this.lastModified,
    this.launcher = LauncherPrefs.empty,
  });
```

Add the field (after `lastModified`):

```dart
  /// Launcher favorites + aliases. Synced with the rest of the bundle.
  final LauncherPrefs launcher;
```

In `toJson()`, add the `launcher` entry (before `'_v': 1`):

```dart
        'launcher': launcher.toJson(),
```

In `fromJson`, add to the returned `SyncableSettings(...)`:

```dart
      launcher: () {
        final l = json['launcher'] as Map<String, dynamic>?;
        return l != null ? LauncherPrefs.fromJson(l) : LauncherPrefs.empty;
      }(),
```

In `defaults()`, add:

```dart
        launcher: LauncherPrefs.empty,
```

In `copyWith`, add the parameter and pass-through:

```dart
  SyncableSettings copyWith({
    GasLogSettings? gasLog,
    SyncSettings? syncSettings,
    Object? localeCode = _sentinel,
    DateTime? lastModified,
    LauncherPrefs? launcher,
  }) {
    return SyncableSettings(
      gasLog: gasLog ?? this.gasLog,
      syncSettings: syncSettings ?? this.syncSettings,
      localeCode:
          identical(localeCode, _sentinel) ? this.localeCode : localeCode as String?,
      lastModified: lastModified ?? this.lastModified,
      launcher: launcher ?? this.launcher,
    );
  }
```

- [ ] **Step 3b: Add the prefs key to `syncable_settings_repository.dart`**

Add the import near the top:

```dart
import '../../launcher/domain/launcher_prefs.dart';
```

Add the key constant alongside the others:

```dart
  static const _launcherKey = 'launcher_prefs';
```

In `read()`, before the final `return SyncableSettings(...)`, decode the launcher prefs:

```dart
    final launcherRaw = prefs.getString(_launcherKey);
    LauncherPrefs launcher;
    if (launcherRaw != null) {
      try {
        launcher = LauncherPrefs.fromJsonString(launcherRaw);
      } catch (_) {
        launcher = LauncherPrefs.empty;
      }
    } else {
      launcher = LauncherPrefs.empty;
    }
```

Add `launcher: launcher,` to that `return SyncableSettings(...)`.

In `apply(...)`, persist it (after the locale block, before the lastModified write):

```dart
    await prefs.setString(_launcherKey, settings.launcher.toJsonString());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/syncable_settings_launcher_test.dart > /tmp/t5.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/domain/syncable_settings.dart lib/features/settings/data/syncable_settings_repository.dart test/features/settings/syncable_settings_launcher_test.dart
git commit -m "feat(launcher): carry launcher prefs in SyncableSettings bundle

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: LauncherPrefs provider (synced)

**Files:**
- Create: `lib/features/launcher/providers/launcher_prefs_provider.dart`
- Test: `test/features/launcher/providers/launcher_prefs_provider_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/providers/launcher_prefs_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/providers/launcher_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggleFavorite adds then removes, and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(launcherPrefsProvider.notifier);

    await n.toggleFavorite('gasLog');
    expect(c.read(launcherPrefsProvider).favorites, ['gasLog']);

    await n.toggleFavorite('gasLog');
    expect(c.read(launcherPrefsProvider).favorites, isEmpty);

    // persisted under the shared key
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('launcher_prefs'), isNotNull);
  });

  test('addAlias / removeAlias mutate the map', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(launcherPrefsProvider.notifier);

    await n.addAlias('cs', 'serviceRecords');
    expect(c.read(launcherPrefsProvider).aliases, {'cs': 'serviceRecords'});

    await n.removeAlias('cs');
    expect(c.read(launcherPrefsProvider).aliases, isEmpty);
  });

  test('loads existing prefs from disk on first read', () async {
    SharedPreferences.setMockInitialValues({
      'launcher_prefs': '{"favorites":["notes"],"aliases":{}}',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // allow the async _load to complete
    await Future<void>.delayed(Duration.zero);
    expect(c.read(launcherPrefsProvider).favorites, ['notes']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/providers/launcher_prefs_provider_test.dart > /tmp/t6.log 2>&1; echo "EXIT $?"`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the implementation** (mirrors `GasLogSettingsNotifier`)

```dart
// lib/features/launcher/providers/launcher_prefs_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/syncable_settings_repository.dart';
import '../../settings/providers/settings_bus_provider.dart';
import '../domain/launcher_prefs.dart';

const _prefsKey = 'launcher_prefs';

/// Holds [LauncherPrefs] (favorites + aliases). Reads/writes the same
/// SharedPreferences key the SyncableSettingsRepository owns, and bumps
/// the settings stamp on every mutation so the change syncs. Watches
/// the settings bus so a remote pull refreshes the in-memory state.
class LauncherPrefsNotifier extends Notifier<LauncherPrefs> {
  @override
  LauncherPrefs build() {
    ref.watch(settingsBusProvider);
    ref.keepAlive();
    _loadFromPrefs();
    return LauncherPrefs.empty;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      state = LauncherPrefs.fromJsonString(json);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.toJsonString());
    await ref.read(syncableSettingsRepositoryProvider).bumpLastModified();
  }

  Future<void> toggleFavorite(String id) async {
    final favs = [...state.favorites];
    favs.contains(id) ? favs.remove(id) : favs.add(id);
    state = state.copyWith(favorites: favs);
    await _persist();
  }

  Future<void> setFavorites(List<String> ids) async {
    state = state.copyWith(favorites: List.of(ids));
    await _persist();
  }

  Future<void> addAlias(String alias, String id) async {
    final aliases = {...state.aliases, alias: id};
    state = state.copyWith(aliases: aliases);
    await _persist();
  }

  Future<void> removeAlias(String alias) async {
    final aliases = {...state.aliases}..remove(alias);
    state = state.copyWith(aliases: aliases);
    await _persist();
  }
}

final launcherPrefsProvider =
    NotifierProvider<LauncherPrefsNotifier, LauncherPrefs>(
  () => LauncherPrefsNotifier(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/launcher/providers/launcher_prefs_provider_test.dart > /tmp/t6.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/launcher/providers/launcher_prefs_provider.dart test/features/launcher/providers/launcher_prefs_provider_test.dart
git commit -m "feat(launcher): synced LauncherPrefs provider

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Recents provider (device-local)

**Files:**
- Create: `lib/features/launcher/providers/launcher_recents_provider.dart`
- Test: `test/features/launcher/providers/launcher_recents_provider_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/providers/launcher_recents_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/providers/launcher_recents_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('record moves to front, dedups, caps at 8', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(launcherRecentsProvider.notifier);

    for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i']) {
      await n.record(id);
    }
    // 9 distinct -> capped to last 8, most-recent first
    expect(c.read(launcherRecentsProvider), ['i', 'h', 'g', 'f', 'e', 'd', 'c', 'b']);

    await n.record('c'); // existing -> moves to front, no dup
    final r = c.read(launcherRecentsProvider);
    expect(r.first, 'c');
    expect(r.where((x) => x == 'c').length, 1);
    expect(r.length, 8);
  });

  test('persists across containers', () async {
    SharedPreferences.setMockInitialValues({});
    final c1 = ProviderContainer();
    await c1.read(launcherRecentsProvider.notifier).record('x');
    c1.dispose();

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(launcherRecentsProvider), ['x']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/providers/launcher_recents_provider_test.dart > /tmp/t7.log 2>&1; echo "EXIT $?"`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/launcher/providers/launcher_recents_provider.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _recentsKey = 'launcher_recents';
const _cap = 8;

/// Most-recently-launched destination ids, newest first, capped at
/// [_cap]. Device-local (NOT synced) — recents are personal to the
/// device, like a phone's app-switcher.
class LauncherRecentsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final raw = prefs.getString(_recentsKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).whereType<String>().toList();
      state = list;
    }
  }

  Future<void> record(String id) async {
    final next = [id, ...state.where((x) => x != id)].take(_cap).toList();
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentsKey, jsonEncode(next));
  }
}

final launcherRecentsProvider =
    NotifierProvider<LauncherRecentsNotifier, List<String>>(
  () => LauncherRecentsNotifier(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/launcher/providers/launcher_recents_provider_test.dart > /tmp/t7.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/launcher/providers/launcher_recents_provider.dart test/features/launcher/providers/launcher_recents_provider_test.dart
git commit -m "feat(launcher): device-local recents provider (capped 8)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Vehicle resolution (pure)

**Files:**
- Create: `lib/features/launcher/domain/vehicle_resolution.dart`
- Test: `test/features/launcher/domain/vehicle_resolution_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/domain/vehicle_resolution_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/launcher/domain/launcher_destination.dart';
import 'package:hmm_console/features/launcher/domain/vehicle_resolution.dart';

Automobile _auto(int id) => Automobile(
      id: id, maker: 'M', model: 'X', year: 2020, color: 'red', plateNumber: 'P$id');

const _gas = LauncherDestination(
    id: 'gasLog', title: 'Gas Log', icon: Icons.abc, routeName: 'gasLogList',
    needsVehicle: true, usesVehiclePathId: false);
const _svc = LauncherDestination(
    id: 'serviceRecords', title: 'Service', icon: Icons.abc, routeName: 'serviceRecords',
    needsVehicle: true, usesVehiclePathId: true);
const _notes = LauncherDestination(
    id: 'notes', title: 'Notes', icon: Icons.abc, routeName: 'notesList');

void main() {
  group('pickVehicle', () {
    test('returns the selected id when set', () {
      expect(pickVehicle(selectedId: 7, automobiles: [_auto(1), _auto(2)]), 7);
    });
    test('falls back to the only vehicle', () {
      expect(pickVehicle(selectedId: null, automobiles: [_auto(3)]), 3);
    });
    test('returns null when none selected and multiple exist', () {
      expect(pickVehicle(selectedId: null, automobiles: [_auto(1), _auto(2)]), isNull);
    });
    test('returns null when no vehicles', () {
      expect(pickVehicle(selectedId: null, automobiles: const []), isNull);
    });
  });

  group('resolveTarget', () {
    test('non-vehicle destination -> its route, no params', () {
      final t = resolveTarget(_notes, null);
      expect(t.routeName, 'notesList');
      expect(t.pathParameters, isEmpty);
      expect(t.selectVehicleId, isNull);
    });
    test('vehicle destination, unresolved -> automobile selector', () {
      final t = resolveTarget(_svc, null);
      expect(t.routeName, 'automobileSelector');
      expect(t.selectVehicleId, isNull);
    });
    test('path-id vehicle destination -> id param + select', () {
      final t = resolveTarget(_svc, 5);
      expect(t.routeName, 'serviceRecords');
      expect(t.pathParameters, {'id': '5'});
      expect(t.selectVehicleId, 5);
    });
    test('provider-scoped vehicle destination (gas log) -> no path param, select', () {
      final t = resolveTarget(_gas, 9);
      expect(t.routeName, 'gasLogList');
      expect(t.pathParameters, isEmpty);
      expect(t.selectVehicleId, 9);
    });
  });
}
```

> Note: confirm the `Automobile(...)` constructor arg names against `lib/features/gas_log/domain/entities/automobile.dart` when writing the test; adjust the `_auto` helper to match the real required fields (only `id` matters here).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/domain/vehicle_resolution_test.dart > /tmp/t8.log 2>&1; echo "EXIT $?"`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/launcher/domain/vehicle_resolution.dart
import '../../../core/navigation/route_names.dart';
import '../../gas_log/domain/entities/automobile.dart';
import 'launcher_destination.dart';

/// Picks the vehicle to scope a launch to: the explicitly-selected
/// vehicle if any, else the only vehicle, else null (caller routes to
/// the picker). Pure — unit-tested in isolation.
int? pickVehicle({required int? selectedId, required List<Automobile> automobiles}) {
  if (selectedId != null) return selectedId;
  if (automobiles.length == 1) return automobiles.first.id;
  return null;
}

/// Where a launch should go, plus whether to set the selected-vehicle
/// provider first. Pure data so navigation can be decided + tested
/// without a BuildContext.
class LaunchTarget {
  const LaunchTarget(
    this.routeName, {
    this.pathParameters = const {},
    this.selectVehicleId,
  });

  final String routeName;
  final Map<String, String> pathParameters;

  /// If non-null, set `selectedAutomobileIdProvider` to this before
  /// navigating (keeps gas-log + nested screens scoped consistently).
  final int? selectVehicleId;
}

/// Turns a destination + resolved vehicle id into a [LaunchTarget].
LaunchTarget resolveTarget(LauncherDestination dest, int? resolvedVehicleId) {
  if (!dest.needsVehicle) return LaunchTarget(dest.routeName);
  if (resolvedVehicleId == null) {
    return LaunchTarget(RouterNames.automobileSelector.name);
  }
  if (dest.usesVehiclePathId) {
    return LaunchTarget(
      dest.routeName,
      pathParameters: {'id': '$resolvedVehicleId'},
      selectVehicleId: resolvedVehicleId,
    );
  }
  return LaunchTarget(dest.routeName, selectVehicleId: resolvedVehicleId);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/launcher/domain/vehicle_resolution_test.dart > /tmp/t8.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/launcher/domain/vehicle_resolution.dart test/features/launcher/domain/vehicle_resolution_test.dart
git commit -m "feat(launcher): pure vehicle resolution (pickVehicle + resolveTarget)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Navigation helper

**Files:**
- Create: `lib/features/launcher/presentation/launcher_navigation.dart`
- (No dedicated test — exercised by the search-screen widget tests in Task 10. The decision logic it relies on is already covered by Task 8.)

- [ ] **Step 1: Write the implementation**

```dart
// lib/features/launcher/presentation/launcher_navigation.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../gas_log/providers/selected_automobile_provider.dart';
import '../../gas_log/states/automobiles_state.dart';
import '../domain/launcher_destination.dart';
import '../domain/vehicle_resolution.dart';

/// Resolves vehicle context (if needed) and pushes the destination's
/// route. For vehicle destinations it sets `selectedAutomobileIdProvider`
/// so gas-log + nested screens stay scoped to the same vehicle; if no
/// vehicle can be resolved it pushes the automobile selector instead.
Future<void> launchDestination(
  BuildContext context,
  WidgetRef ref,
  LauncherDestination dest,
) async {
  int? vid;
  if (dest.needsVehicle) {
    final selected = ref.read(selectedAutomobileIdProvider);
    final autos = await ref.read(automobilesStateProvider.future);
    vid = pickVehicle(selectedId: selected, automobiles: autos);
  }
  final target = resolveTarget(dest, vid);
  if (target.selectVehicleId != null) {
    ref.read(selectedAutomobileIdProvider.notifier).select(target.selectVehicleId);
  }
  if (!context.mounted) return;
  context.pushNamed(target.routeName, pathParameters: target.pathParameters);
}
```

- [ ] **Step 2: Verify it compiles (analyzer)**

Run: `flutter analyze lib/features/launcher/presentation/launcher_navigation.dart > /tmp/t9.log 2>&1; echo "EXIT $?"`
Expected: No errors (EXIT 0). Warnings unrelated to this file are acceptable.

- [ ] **Step 3: Commit**

```bash
git add lib/features/launcher/presentation/launcher_navigation.dart
git commit -m "feat(launcher): launchDestination navigation helper

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: Launcher search screen

**Files:**
- Create: `lib/features/launcher/presentation/launcher_search_screen.dart`
- Test: `test/features/launcher/presentation/launcher_search_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/presentation/launcher_search_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/launcher/presentation/launcher_search_screen.dart';
import 'package:hmm_console/features/launcher/providers/launcher_prefs_provider.dart';
import 'package:hmm_console/features/launcher/domain/launcher_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Minimal router: launcher search at '/', a stub Notes target so a tap
// has somewhere to land.
GoRouter _router() => GoRouter(routes: [
      GoRoute(path: '/', name: 'home', builder: (_, __) => const LauncherSearchScreen()),
      GoRoute(
          path: '/notes',
          name: 'notesList',
          builder: (_, __) => const Scaffold(body: Text('NOTES SCREEN'))),
    ]);

Future<void> _pump(WidgetTester t, {LauncherPrefs prefs = LauncherPrefs.empty}) async {
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(ProviderScope(
    overrides: [
      launcherPrefsProvider.overrideWith(() => _StubPrefs(prefs)),
    ],
    child: MaterialApp.router(routerConfig: _router()),
  ));
  await t.pumpAndSettle();
}

class _StubPrefs extends LauncherPrefsNotifier {
  _StubPrefs(this._initial);
  final LauncherPrefs _initial;
  @override
  LauncherPrefs build() => _initial;
}

void main() {
  testWidgets('command mode "/no" shows Notes; tap navigates', (t) async {
    await _pump(t);
    await t.enterText(find.byType(TextField), '/no');
    await t.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget);
    await t.tap(find.text('Notes'));
    await t.pumpAndSettle();
    expect(find.text('NOTES SCREEN'), findsOneWidget);
  });

  testWidgets('assistant mode (plain text) shows the coming-soon stub, no results', (t) async {
    await _pump(t);
    await t.enterText(find.byType(TextField), 'gas');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('assistant-stub')), findsOneWidget);
    expect(find.text('Gas Log'), findsNothing);
  });

  testWidgets('lone "/" shows the favorites landing', (t) async {
    await _pump(t, prefs: const LauncherPrefs(favorites: ['notes']));
    await t.enterText(find.byType(TextField), '/');
    await t.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget); // favorite resolved
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/presentation/launcher_search_screen_test.dart > /tmp/t10.log 2>&1; echo "EXIT $?"`
Expected: FAIL — `LauncherSearchScreen` missing.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/launcher/presentation/launcher_search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/launcher_destination.dart';
import '../domain/launcher_input_mode.dart';
import '../domain/launcher_matcher.dart';
import '../domain/launcher_registry.dart';
import '../providers/launcher_prefs_provider.dart';
import '../providers/launcher_recents_provider.dart';
import 'launcher_navigation.dart';

/// Full-screen function-search route. A leading '/' enters command
/// mode (fuzzy-match destinations); plain text is the assistant stub;
/// empty input (or a lone '/') shows the favorites/recents landing.
class LauncherSearchScreen extends ConsumerStatefulWidget {
  const LauncherSearchScreen({super.key});

  @override
  ConsumerState<LauncherSearchScreen> createState() => _LauncherSearchScreenState();
}

class _LauncherSearchScreenState extends ConsumerState<LauncherSearchScreen> {
  final _controller = TextEditingController();
  String _raw = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go(LauncherDestination d) async {
    await ref.read(launcherRecentsProvider.notifier).record(d.id);
    if (!mounted) return;
    await launchDestination(context, ref, d);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(launcherPrefsProvider);
    final mode = modeOf(_raw);

    Widget body;
    switch (mode) {
      case LauncherInputMode.assistant:
        body = _assistantStub(context);
      case LauncherInputMode.empty:
        body = _landing(prefs.favorites);
      case LauncherInputMode.command:
        final q = commandQuery(_raw);
        if (q.isEmpty) {
          body = _landing(prefs.favorites);
        } else {
          final results = match(q, registry: launcherDestinations, aliases: prefs.aliases);
          body = results.isEmpty
              ? _empty('No matching features')
              : ListView(children: [for (final d in results) _tile(d)]);
        }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (v) => setState(() => _raw = v),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Type / for features · ask AI (soon)',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _tile(LauncherDestination d) => ListTile(
        leading: Icon(d.icon),
        title: Text(d.title),
        onTap: () => _go(d),
      );

  Widget _landing(List<String> favoriteIds) {
    final favorites = favoriteIds
        .map((id) => launcherDestinationsById[id])
        .whereType<LauncherDestination>()
        .toList();
    final recents = ref
        .watch(launcherRecentsProvider)
        .map((id) => launcherDestinationsById[id])
        .whereType<LauncherDestination>()
        .toList();

    if (favorites.isEmpty && recents.isEmpty) {
      return _empty('Type / to jump to a feature');
    }
    return ListView(children: [
      if (favorites.isNotEmpty) ...[
        _header('Favorites'),
        for (final d in favorites) _tile(d),
      ],
      if (recents.isNotEmpty) ...[
        _header('Recent'),
        for (final d in recents) _tile(d),
      ],
    ]);
  }

  Widget _assistantStub(BuildContext context) => Center(
        key: const Key('assistant-stub'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome,
                  size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text(
                'Ask the assistant — coming soon.\nType / to jump to a feature.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _empty(String text) => Center(
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/launcher/presentation/launcher_search_screen_test.dart > /tmp/t10.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/launcher/presentation/launcher_search_screen.dart test/features/launcher/presentation/launcher_search_screen_test.dart
git commit -m "feat(launcher): search screen (command / assistant / landing modes)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: Launcher manage screen (favorites + aliases)

**Files:**
- Create: `lib/features/launcher/presentation/launcher_manage_screen.dart`
- Test: `test/features/launcher/presentation/launcher_manage_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/presentation/launcher_manage_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/launcher/domain/launcher_prefs.dart';
import 'package:hmm_console/features/launcher/presentation/launcher_manage_screen.dart';
import 'package:hmm_console/features/launcher/providers/launcher_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubPrefs extends LauncherPrefsNotifier {
  @override
  LauncherPrefs build() => LauncherPrefs.empty;
}

Future<ProviderContainer> _pump(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final c = ProviderContainer(
      overrides: [launcherPrefsProvider.overrideWith(() => _StubPrefs())]);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(home: LauncherManageScreen()),
  ));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('pinning a destination adds it to favorites', (t) async {
    final c = await _pump(t);
    // The "Gas Log" row has a star toggle; tap it.
    await t.tap(find.byKey(const Key('fav-toggle-gasLog')));
    await t.pumpAndSettle();
    expect(c.read(launcherPrefsProvider).favorites.contains('gasLog'), isTrue);
  });

  testWidgets('adding an alias stores alias -> id', (t) async {
    final c = await _pump(t);
    await t.enterText(find.byKey(const Key('alias-text')), 'cs');
    // pick a destination from the dropdown
    await t.tap(find.byKey(const Key('alias-dest')));
    await t.pumpAndSettle();
    await t.tap(find.text('Service Log').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('alias-add')));
    await t.pumpAndSettle();
    expect(c.read(launcherPrefsProvider).aliases['cs'], 'serviceRecords');
  });

  testWidgets('reordering pinned favorites calls setFavorites', (t) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(overrides: [
      launcherPrefsProvider.overrideWith(() => _StubPrefsWith(
          const LauncherPrefs(favorites: ['gasLog', 'notes', 'settings']))),
    ]);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: LauncherManageScreen()),
    ));
    await t.pumpAndSettle();
    // Drive the reorder callback directly (drag gestures are flaky in tests).
    final reorderable =
        t.widget<ReorderableListView>(find.byKey(const Key('pinned-reorder')));
    reorderable.onReorder(0, 3); // move 'gasLog' to the end
    await t.pumpAndSettle();
    expect(c.read(launcherPrefsProvider).favorites, ['notes', 'settings', 'gasLog']);
  });
}

class _StubPrefsWith extends LauncherPrefsNotifier {
  _StubPrefsWith(this._initial);
  final LauncherPrefs _initial;
  @override
  LauncherPrefs build() => _initial;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/presentation/launcher_manage_screen_test.dart > /tmp/t11.log 2>&1; echo "EXIT $?"`
Expected: FAIL — `LauncherManageScreen` missing.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/launcher/presentation/launcher_manage_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/launcher_destination.dart';
import '../domain/launcher_registry.dart';
import '../providers/launcher_prefs_provider.dart';

/// Settings-reached screen to pin/unpin favorites and manage
/// alias -> destination rows.
class LauncherManageScreen extends ConsumerStatefulWidget {
  const LauncherManageScreen({super.key});

  @override
  ConsumerState<LauncherManageScreen> createState() => _LauncherManageScreenState();
}

class _LauncherManageScreenState extends ConsumerState<LauncherManageScreen> {
  final _aliasController = TextEditingController();
  String? _aliasDestId;
  String? _aliasError;

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  /// ReorderableListView reports a `newIndex` that is one past the
  /// removed slot when dragging downward; normalize before moving.
  Future<void> _reorderFavorites(List<String> favorites, int oldIndex, int newIndex) async {
    final next = [...favorites];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    await ref.read(launcherPrefsProvider.notifier).setFavorites(next);
  }

  Future<void> _addAlias() async {
    final alias = _aliasController.text.trim().toLowerCase();
    final destId = _aliasDestId;
    final existing = ref.read(launcherPrefsProvider).aliases;
    if (alias.isEmpty || destId == null) {
      setState(() => _aliasError = 'Enter an alias and pick a destination');
      return;
    }
    if (existing.containsKey(alias)) {
      setState(() => _aliasError = 'Alias "$alias" already exists');
      return;
    }
    await ref.read(launcherPrefsProvider.notifier).addAlias(alias, destId);
    if (!mounted) return;
    setState(() {
      _aliasController.clear();
      _aliasDestId = null;
      _aliasError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(launcherPrefsProvider);

    final pinned = prefs.favorites
        .map((id) => launcherDestinationsById[id])
        .whereType<LauncherDestination>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Launcher')),
      body: ListView(
        children: [
          if (pinned.length > 1) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Pinned (drag to reorder)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ReorderableListView(
              key: const Key('pinned-reorder'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (o, n) => _reorderFavorites(prefs.favorites, o, n),
              children: [
                for (final d in pinned)
                  ListTile(
                    key: ValueKey('pinned-${d.id}'),
                    leading: Icon(d.icon),
                    title: Text(d.title),
                    trailing: const Icon(Icons.drag_handle),
                  ),
              ],
            ),
            const Divider(),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Favorites', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final d in launcherDestinations)
            ListTile(
              leading: Icon(d.icon),
              title: Text(d.title),
              trailing: IconButton(
                key: Key('fav-toggle-${d.id}'),
                icon: Icon(prefs.favorites.contains(d.id) ? Icons.star : Icons.star_border),
                onPressed: () =>
                    ref.read(launcherPrefsProvider.notifier).toggleFavorite(d.id),
              ),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Aliases', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final entry in prefs.aliases.entries)
            ListTile(
              title: Text('"${entry.key}"  →  ${launcherDestinationsById[entry.value]?.title ?? entry.value}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(launcherPrefsProvider.notifier).removeAlias(entry.key),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('alias-text'),
                  controller: _aliasController,
                  decoration: const InputDecoration(
                    labelText: 'New alias (e.g. cs)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('alias-dest'),
                  initialValue: _aliasDestId,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final d in launcherDestinations)
                      DropdownMenuItem(value: d.id, child: Text(d.title)),
                  ],
                  onChanged: (v) => setState(() => _aliasDestId = v),
                ),
                if (_aliasError != null) ...[
                  const SizedBox(height: 8),
                  Text(_aliasError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const Key('alias-add'),
                    onPressed: _addAlias,
                    icon: const Icon(Icons.add),
                    label: const Text('Add alias'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

> Note: `DropdownButtonFormField.initialValue` requires a recent Flutter; if the project's Flutter rejects it, use `value:` instead. Confirm against the project's other `DropdownButtonFormField` usages before implementing.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/launcher/presentation/launcher_manage_screen_test.dart > /tmp/t11.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add lib/features/launcher/presentation/launcher_manage_screen.dart test/features/launcher/presentation/launcher_manage_screen_test.dart
git commit -m "feat(launcher): manage screen (pin favorites + alias rows)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 12: Wire routes + entry points

**Files:**
- Modify: `lib/core/navigation/route_names.dart`
- Modify: `lib/core/navigation/router_config.dart`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Test: `test/features/launcher/launcher_routes_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/launcher/launcher_routes_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/navigation/route_names.dart';

void main() {
  test('launcher route names exist', () {
    final names = RouterNames.values.map((r) => r.name).toSet();
    expect(names.contains('launcherSearch'), isTrue);
    expect(names.contains('launcherManage'), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/launcher/launcher_routes_test.dart > /tmp/t12.log 2>&1; echo "EXIT $?"`
Expected: FAIL — enum values absent.

- [ ] **Step 3a: Add the enum values** in `lib/core/navigation/route_names.dart` (before the closing `}` of the enum, after `subsystemNotes,`):

```dart
  launcherSearch,
  launcherManage,
```

- [ ] **Step 3b: Wire the routes** in `lib/core/navigation/router_config.dart`.

Add imports near the other feature imports:

```dart
import 'package:hmm_console/features/launcher/presentation/launcher_search_screen.dart';
import 'package:hmm_console/features/launcher/presentation/launcher_manage_screen.dart';
```

Add two top-level routes to the `routes: [ ... ]` list (e.g. right after the `/settings` route):

```dart
      GoRoute(
        path: '/launcher',
        name: RouterNames.launcherSearch.name,
        builder: (context, state) => const LauncherSearchScreen(),
      ),
      GoRoute(
        path: '/launcher/manage',
        name: RouterNames.launcherManage.name,
        builder: (context, state) => const LauncherManageScreen(),
      ),
```

- [ ] **Step 3c: Home-screen entry** — in `lib/features/dashboard/presentation/screens/dashboard_screen.dart`, make the search bar open the launcher route instead of filtering inline.

Replace the `TextField` returned by `_buildSearchBar` with a tap target (read-only field that pushes `/launcher`). Change the method body to:

```dart
  Widget _buildSearchBar(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => context.pushNamed(RouterNames.launcherSearch.name),
      child: AbsorbPointer(
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Type / for features · ask AI (soon)',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ),
    );
  }
```

Add the import for `RouterNames` at the top of the dashboard file:

```dart
import '../../../../core/navigation/route_names.dart';
```

The existing `_searchController`, `_searchQuery`, `_filteredFunctions`, and `_buildShortcuts` filtering remain for the tile grid below (the tiles still render `_allFunctions`); only the search **bar** now routes to the launcher. (The shortcuts grid keeps working because `_searchQuery` stays `''`.)

- [ ] **Step 3d: Settings link** — in `lib/features/settings/presentation/screens/settings_screen.dart`, add a `ListTile` that pushes the manage route. Add the import:

```dart
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/route_names.dart';
```

(If `go_router`/`RouterNames` are already imported, skip the duplicate.) Then add this tile in the settings list (e.g. near the top-level navigation tiles):

```dart
            ListTile(
              leading: const Icon(Icons.apps),
              title: const Text('Launcher'),
              subtitle: const Text('Pin favorites and set search aliases'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(RouterNames.launcherManage.name),
            ),
```

- [ ] **Step 4: Run the route test + analyzer**

Run: `flutter test test/features/launcher/launcher_routes_test.dart > /tmp/t12.log 2>&1; echo "EXIT $?"`
Expected: PASS, EXIT 0.

Run: `flutter analyze lib/core/navigation lib/features/dashboard lib/features/settings/presentation/screens/settings_screen.dart > /tmp/t12a.log 2>&1; echo "EXIT $?"`
Expected: No errors (EXIT 0).

- [ ] **Step 5: Commit**

```bash
git add lib/core/navigation/route_names.dart lib/core/navigation/router_config.dart lib/features/dashboard/presentation/screens/dashboard_screen.dart lib/features/settings/presentation/screens/settings_screen.dart test/features/launcher/launcher_routes_test.dart
git commit -m "feat(launcher): wire routes + home search bar + settings link

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 13: Full-suite verification

**Files:** none (verification only).

- [ ] **Step 1: Run the whole test suite**

Run: `flutter test > /tmp/all.log 2>&1; echo "EXIT $?"`
Expected: EXIT 0. If any pre-existing tests fail, confirm they failed before this work (git stash + run) before attributing to the launcher. New launcher tests must pass.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze > /tmp/analyze.log 2>&1; echo "EXIT $?"`
Expected: No new errors introduced by launcher files. (Pre-existing warnings unrelated to `lib/features/launcher/**` are out of scope.)

- [ ] **Step 3: Commit any analyzer fixups** (only if changes were needed)

```bash
git add -A
git commit -m "chore(launcher): analyzer + test-suite fixups

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 14 (follow-on, optional): Derive dashboard tiles from the registry

This is the spec's explicitly-deferred follow-on. Only do it if requested after the core launcher ships.

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

- [ ] **Step 1:** Replace the hand-written `_allFunctions` list with a derivation from `launcherDestinations` (map each destination to the tile model the grid renders, reusing `d.icon`/`d.title`), and route tile taps through `launchDestination(context, ref, d)` so tiles and search share one source of truth and one navigation path. Keep the placeholder-only tiles (Pomodoro, Expenses, Weather, Calendar) as a separate "coming soon" list if still desired. Add a widget test asserting a tile tap navigates via the same path as search. Commit.

---

## Notes for the implementer

- **Test gating:** always redirect test/analyze output to a file and echo the exit code (`> /tmp/x.log 2>&1; echo "EXIT $?"`). Do NOT pipe through `tail`/`head` — that masks the real exit code and has caused commit-on-red before.
- **Commit footer:** every commit ends with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Leave untouched:** the pre-existing uncommitted `CLAUDE.md` and `ios/Podfile.lock` changes — do not stage them.
- **Constructor arg confirmation:** two tests reference real entities — confirm `Automobile(...)` required fields (Task 8) and any `DropdownButtonFormField` API (`initialValue` vs `value`, Task 11) against the codebase before writing, and adjust to match.
- **No backend / no codegen:** this feature is client-only and adds no Drift tables or annotations, so `build_runner` is not needed.
```
