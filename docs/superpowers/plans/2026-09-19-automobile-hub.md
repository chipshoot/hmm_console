# Automobile Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One **Automobile** dashboard tile opens a hub screen showing the driver's licence on top and the active vehicles below; each vehicle row opens the existing vehicle screen and carries a fuel button that jumps to that vehicle's gas log.

**Architecture:** A thin `ConsumerWidget` that composes three existing providers (`driverLicenceStateProvider`, `automobilesStateProvider`, `dataModeProvider`) and one notifier (`selectedAutomobileIdProvider`) and navigates with `context.push` to routes that already exist. It replaces `AutomobileSelectorScreen` at `/automobiles`. No new state, no storage change. A pre-existing cold-deep-link bug in `AutomobileEditScreen` is fixed first because the hub makes cold arrivals normal.

**Tech Stack:** Flutter, Riverpod 3 (`ConsumerWidget`, `AsyncNotifier` stubs in tests), GoRouter 17 (bare routers in widget tests), gen-l10n ARB files (`lib/l10n/app_en.arb`, `app_zh.arb` → `lib/l10n/gen/`, which is committed).

**Spec:** `docs/superpowers/specs/2026-09-19-automobile-hub-design.md`

## Global Constraints

- Every user-visible string goes through `AppLocalizations` with keys in **both** `app_en.arb` and `app_zh.arb`, then `flutter gen-l10n` (the generated files under `lib/l10n/gen/` are committed — include them in the commit). Dashboard tile titles are the one exception: `_allFunctions` in `dashboard_screen.dart` is hard-coded English today; keep that pattern.
- Dashboard tiles keep the emoji icon scheme (`AppFunction.icon` is a `String`).
- No change to `lib/features/launcher/domain/launcher_registry.dart`.
- Widget tests use a bare `GoRouter` with placeholder routes, never the app router (it sits behind the auth redirect).
- `flutter analyze` must be clean and `flutter test` green before each commit. Run single files with `flutter test <path>`; the `timeout` shell command does not exist on this Mac — use `flutter test --timeout 60s`.
- Commit messages end with `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

---

## File map

| File | Responsibility |
|---|---|
| `lib/features/gas_log/presentation/screens/automobile_edit_screen.dart` | Modify: populate the form when the vehicle list lands after `initState` (Task 1) |
| `test/features/gas_log/automobile_edit_deep_link_test.dart` | New: regression test for Task 1 |
| `lib/features/automobile_records/presentation/widgets/gas_log_summary_tile.dart` | New: the *Gas log* tile on the vehicle screen (Task 2) |
| `lib/features/automobile_records/presentation/widgets/automobile_records_summary.dart` | Modify: mount the tile (Task 2) |
| `test/features/automobile_records/gas_log_summary_tile_test.dart` | New (Task 2) |
| `lib/features/gas_log/presentation/widgets/automobile_list_tile.dart` | Modify: optional `trailing` slot (Task 3) |
| `lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart` | New: the hub (Task 3) |
| `test/features/automobile_records/automobile_hub_screen_test.dart` | New (Task 3) |
| `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/gen/*` | Modify: new keys (Tasks 2, 3) |
| `lib/core/navigation/router_config.dart` | Modify: mount the hub at `/automobiles` (Task 4) |
| `lib/features/gas_log/presentation/screens/automobile_selector_screen.dart` | Delete (Task 4) |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Modify: one Automobile tile (Task 5) |
| `test/features/dashboard/dashboard_automobile_tile_test.dart` | New (Task 5) |

---

### Task 1: AutomobileEditScreen populates on a cold arrival

**Files:**
- Modify: `lib/features/gas_log/presentation/screens/automobile_edit_screen.dart:560-585`
- Test: `test/features/gas_log/automobile_edit_deep_link_test.dart`

**Interfaces:**
- Consumes: `automobilesStateProvider` (`AsyncNotifierProvider<AutomobilesState, List<Automobile>>`), `_populateFromOriginal()` (existing private method, sets `_original` and the text controllers).
- Produces: nothing new; the screen now works when pushed before the vehicle list has resolved.

- [ ] **Step 1: Write the failing test**

```dart
// The hub pushes /automobiles/manage/:id/edit directly, so the screen can now
// mount while the vehicle list is still loading. It used to read the list
// once in initState and show "vehicle not found" forever in that case.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_edit_screen.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _StubResolver implements IAttachmentResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalMode extends DataModeNotifier {
  @override
  DataMode build() => DataMode.local;
}

/// Resolves only after a delay, so the screen's initState sees a loading list.
class _SlowAutomobiles extends AutomobilesState {
  @override
  Future<List<Automobile>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return [
      Automobile(
        id: 1,
        year: 2020,
        maker: 'Honda',
        model: 'Civic',
        plate: 'REG-1',
        meterReading: 100,
        isActive: true,
        registrationNumber: 'REG-NUMBER-1',
      ),
    ];
  }
}

void main() {
  testWidgets('the form fills in once the vehicle list lands', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dataModeProvider.overrideWith(_LocalMode.new),
        automobilesStateProvider.overrideWith(_SlowAutomobiles.new),
        attachmentResolverProvider.overrideWith((_) async => _StubResolver()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AutomobileEditScreen(automobileId: 1),
      ),
    ));
    await tester.pump();

    // Still loading: the old code is already stuck here.
    expect(find.text('REG-NUMBER-1'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('REG-NUMBER-1'), findsOneWidget,
        reason: 'the list resolved after initState; the form must catch up');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test --timeout 60s test/features/gas_log/automobile_edit_deep_link_test.dart`
Expected: FAIL — `find.text('REG-NUMBER-1')` finds nothing after the delay (the screen shows "Vehicle not found").

- [ ] **Step 3: Listen for the list in `build`**

In `automobile_edit_screen.dart`, inside `build`, directly after the existing `ref.listen<AsyncValue<void>>(updateAutomobileStateProvider, ...)` block and before `if (_original == null) {`, add:

```dart
    // A cold arrival (deep link, relaunch onto this route) mounts the screen
    // while the vehicle list is still loading, so initState found nothing.
    // Populate as soon as the list lands; after that the listener is inert.
    ref.listen<AsyncValue<List<Automobile>>>(automobilesStateProvider,
        (_, next) {
      if (_original == null && next.hasValue) {
        setState(_populateFromOriginal);
      }
    });
```

`Automobile` is already imported in this file (it is the type of `_original`). If the analyzer complains the import is missing, add `import '../../domain/entities/automobile.dart';`.

- [ ] **Step 4: Run the test and the neighbouring one**

Run: `flutter test --timeout 60s test/features/gas_log/automobile_edit_deep_link_test.dart test/features/gas_log/automobile_registration_form_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/gas_log/presentation/screens/automobile_edit_screen.dart test/features/gas_log/automobile_edit_deep_link_test.dart
git commit -m "fix(vehicle): populate the edit screen when the list lands after mount

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Gas log tile on the vehicle screen

**Files:**
- Create: `lib/features/automobile_records/presentation/widgets/gas_log_summary_tile.dart`
- Modify: `lib/features/automobile_records/presentation/widgets/automobile_records_summary.dart:44-66`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (+ regenerate `lib/l10n/gen/`)
- Test: `test/features/automobile_records/gas_log_summary_tile_test.dart`

**Interfaces:**
- Consumes: `selectedAutomobileIdProvider` (`NotifierProvider<SelectedAutomobileNotifier, int?>`, `lib/features/gas_log/providers/selected_automobile_provider.dart`; `.notifier.select(int? id)`), route `/gas-logs`.
- Produces: `class GasLogSummaryTile extends ConsumerWidget { const GasLogSummaryTile({super.key, required this.automobileId}); final int automobileId; }` — a `Card` + `ListTile` titled `l10n.recordsGasLog`; tap selects the vehicle and pushes `/gas-logs`. New l10n key `recordsGasLog`.

The spec allows a "last fill" subtitle only if it needs no new provider. The gas-log list state is keyed on the *selected* vehicle, not an arbitrary id, so wiring a per-vehicle subtitle would need a new provider — ship title-only, as the spec says.

- [ ] **Step 1: Add the l10n key**

In `lib/l10n/app_en.arb`, directly after the `"recordsNotes"` entry (search for `"recordsNotes":`), add:

```json
  "recordsGasLog": "Gas log",
```

In `lib/l10n/app_zh.arb`, directly after its `"recordsNotes"` entry, add:

```json
  "recordsGasLog": "加油记录",
```

Run: `flutter gen-l10n`
Expected: no output (or only "untranslated messages" for pre-existing keys); `lib/l10n/gen/app_localizations.dart` now has `String get recordsGasLog;`.

- [ ] **Step 2: Write the failing test**

```dart
// The vehicle screen's records summary gains a Gas log entry so the vehicle
// screen is complete on its own. Tapping it must do what the old vehicle
// picker did: select the vehicle, then open the gas-log list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/features/automobile_records/presentation/widgets/gas_log_summary_tile.dart';
import 'package:hmm_console/features/gas_log/providers/selected_automobile_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('tap selects the vehicle and opens the gas log', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/v', routes: [
      GoRoute(
          path: '/v',
          builder: (_, _) =>
              const Scaffold(body: GasLogSummaryTile(automobileId: 7))),
      GoRoute(
          path: '/gas-logs',
          builder: (_, _) => const Scaffold(body: Text('gas log list'))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Gas log'), findsOneWidget);
    await tester.tap(find.text('Gas log'));
    await tester.pumpAndSettle();

    expect(container.read(selectedAutomobileIdProvider), 7,
        reason: 'the gas-log list shows the selected vehicle');
    expect(find.text('gas log list'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test --timeout 60s test/features/automobile_records/gas_log_summary_tile_test.dart`
Expected: FAIL to compile — `gas_log_summary_tile.dart` does not exist.

- [ ] **Step 4: Write the tile**

`lib/features/automobile_records/presentation/widgets/gas_log_summary_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../../../gas_log/providers/selected_automobile_provider.dart';

/// The vehicle screen's link to its gas log. The gas-log list reads the
/// SELECTED vehicle rather than taking an id, so the tile selects first and
/// navigates second — the same two steps the old vehicle picker performed.
class GasLogSummaryTile extends ConsumerWidget {
  const GasLogSummaryTile({super.key, required this.automobileId});

  final int automobileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_gas_station_outlined),
        title: Text(l10n.recordsGasLog),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(selectedAutomobileIdProvider.notifier).select(automobileId);
          context.push('/gas-logs');
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run the test**

Run: `flutter test --timeout 60s test/features/automobile_records/gas_log_summary_tile_test.dart`
Expected: PASS.

- [ ] **Step 6: Mount it in the records summary**

In `automobile_records_summary.dart`, add the import after the existing relative imports:

```dart
import 'gas_log_summary_tile.dart';
```

In `_AutomobileRecordsSummaryState.build`, make the gas log the first child — it is the most-used record — by changing the start of the `children:` list from

```dart
      children: [
        _InsuranceSummaryCard(automobileId: widget.automobileId),
```

to

```dart
      children: [
        GasLogSummaryTile(automobileId: widget.automobileId),
        const SizedBox(height: 8),
        _InsuranceSummaryCard(automobileId: widget.automobileId),
```

Also update the widget's doc comment first line from "Three at-a-glance cards" to "At-a-glance cards" (there are now five entries).

- [ ] **Step 7: Analyze and run the vehicle-screen tests**

Run: `flutter analyze lib/features/automobile_records lib/l10n && flutter test --timeout 60s test/features/gas_log test/features/automobile_records`
Expected: no issues; all PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/automobile_records/presentation/widgets/gas_log_summary_tile.dart lib/features/automobile_records/presentation/widgets/automobile_records_summary.dart lib/l10n test/features/automobile_records/gas_log_summary_tile_test.dart
git commit -m "feat(vehicle): link the gas log from the vehicle screen

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: The Automobile hub screen

**Files:**
- Modify: `lib/features/gas_log/presentation/widgets/automobile_list_tile.dart:8-18, 60-62`
- Create: `lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (+ regenerate)
- Test: `test/features/automobile_records/automobile_hub_screen_test.dart`

**Interfaces:**
- Consumes: `automobilesStateProvider`, `gasLogSettingsProvider` (`.distanceUnit.label`), `dataModeProvider` / `DataMode.cloudApi`, `driverLicenceStateProvider` (`AsyncNotifierProvider<DriverLicenceState, DriverLicence?>`; `DriverLicence` has `String? licenceClass`, `String? jurisdiction`, `DateTime? expiryDate`), `selectedAutomobileIdProvider`, `CommonScreenScaffold({title, child, withPadding, actions})`, `AutomobileListTile`.
- Produces: `class AutomobileHubScreen extends ConsumerWidget { const AutomobileHubScreen({super.key}); }`; `AutomobileListTile` gains `final Widget? trailing;` (replaces the chevron when given). Task 4 mounts the screen at `/automobiles`.

- [ ] **Step 1: Add the l10n keys**

In `lib/l10n/app_en.arb`, directly after the `"vehicleAdd"` entry, add:

```json
  "automobileHubTitle": "Automobile",
  "automobileHubVehicles": "Vehicles",
  "automobileHubLicenceTitle": "Driver's licence",
  "automobileHubLicenceAdd": "Add your driver's licence",
  "automobileHubLicenceAddHint": "Scan the card or type it in",
  "automobileHubLicenceExpires": "expires {date}",
  "@automobileHubLicenceExpires": {
    "placeholders": {"date": {"type": "String"}}
  },
  "automobileHubNoVehicles": "No vehicles yet",
  "automobileHubNoVehiclesHint": "Add a vehicle to keep its gas log, insurance and service records together.",
  "automobileHubGasLogFor": "Gas log for {name}",
  "@automobileHubGasLogFor": {
    "placeholders": {"name": {"type": "String"}}
  },
```

In `lib/l10n/app_zh.arb`, directly after its `"vehicleAdd"` entry, add:

```json
  "automobileHubTitle": "汽车",
  "automobileHubVehicles": "车辆",
  "automobileHubLicenceTitle": "驾驶执照",
  "automobileHubLicenceAdd": "添加您的驾驶执照",
  "automobileHubLicenceAddHint": "扫描证件或手动输入",
  "automobileHubLicenceExpires": "{date}到期",
  "automobileHubNoVehicles": "还没有车辆",
  "automobileHubNoVehiclesHint": "添加车辆，把加油记录、保险和保养记录放在一起。",
  "automobileHubGasLogFor": "{name}的加油记录",
```

Run: `flutter gen-l10n`
Expected: generated getters `automobileHubTitle` … and methods `automobileHubLicenceExpires(String date)`, `automobileHubGasLogFor(String name)`.

- [ ] **Step 2: Give `AutomobileListTile` a trailing slot**

In `automobile_list_tile.dart`, change the field/constructor block to:

```dart
class AutomobileListTile extends ConsumerWidget {
  final Automobile automobile;
  final String distanceLabel;
  final VoidCallback? onTap;

  /// Replaces the chevron. The hub puts a fuel button here; the chevron is
  /// implied by the row being tappable.
  final Widget? trailing;

  const AutomobileListTile({
    super.key,
    required this.automobile,
    this.distanceLabel = 'mi',
    this.onTap,
    this.trailing,
  });
```

and replace the chevron line

```dart
                  Icon(Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant),
```

with

```dart
                  trailing ??
                      Icon(Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant),
```

- [ ] **Step 3: Write the failing tests**

`test/features/automobile_records/automobile_hub_screen_test.dart`:

```dart
// The hub is navigation: every assertion here is "tap X, land on Y" against
// a bare router with placeholder destinations, plus the two visibility rules
// (licence card by mode and by saved state).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/attachments/attachment_providers.dart';
import 'package:hmm_console/core/data/attachments/resolver/attachment_resolver.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/repository_providers.dart';
import 'package:hmm_console/features/automobile_records/presentation/screens/automobile_hub_screen.dart';
import 'package:hmm_console/features/driver_licence/data/i_driver_licence_repository.dart';
import 'package:hmm_console/features/driver_licence/domain/driver_licence.dart';
import 'package:hmm_console/features/gas_log/domain/entities/automobile.dart';
import 'package:hmm_console/features/gas_log/providers/selected_automobile_provider.dart';
import 'package:hmm_console/features/gas_log/states/automobiles_state.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubResolver implements IAttachmentResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

class _FakeLicenceRepo implements IDriverLicenceRepository {
  _FakeLicenceRepo([this._stored]);
  DriverLicence? _stored;
  @override
  Future<DriverLicence?> getLicence() async => _stored;
  @override
  Future<int?> noteId() async => _stored == null ? null : 1;
  @override
  Future<DriverLicence> saveLicence(DriverLicence l) async => _stored = l;
}

class _StubAutomobiles extends AutomobilesState {
  _StubAutomobiles(this._items);
  final List<Automobile> _items;
  @override
  Future<List<Automobile>> build() async => _items;
}

class _FailingAutomobiles extends AutomobilesState {
  @override
  Future<List<Automobile>> build() async => throw StateError('boom');
}

Automobile _auto(int id, String model, {bool active = true}) => Automobile(
      id: id,
      year: 2020,
      maker: 'Honda',
      model: model,
      meterReading: 100,
      isActive: active,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  DataMode mode = DataMode.local,
  DriverLicence? licence,
  AutomobilesState Function()? automobiles,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    dataModeProvider.overrideWith(() => _StubMode(mode)),
    driverLicenceRepositoryModeProvider
        .overrideWithValue(_FakeLicenceRepo(licence)),
    automobilesStateProvider.overrideWith(
        automobiles ?? () => _StubAutomobiles([_auto(1, 'Civic')])),
    attachmentResolverProvider.overrideWith((_) async => _StubResolver()),
  ]);
  addTearDown(container.dispose);

  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  final router = GoRouter(initialLocation: '/automobiles', routes: [
    GoRoute(
        path: '/automobiles',
        builder: (_, _) => const AutomobileHubScreen(),
        routes: [
          GoRoute(
              path: 'manage',
              builder: (_, _) => stub('manage list'),
              routes: [
                GoRoute(path: 'new', builder: (_, _) => stub('new vehicle')),
                GoRoute(
                    path: ':id/edit',
                    builder: (_, s) =>
                        stub('edit ${s.pathParameters['id']}')),
              ]),
        ]),
    GoRoute(path: '/gas-logs', builder: (_, _) => stub('gas log list')),
    GoRoute(
        path: '/licence',
        builder: (_, _) => stub('licence editor'),
        routes: [
          GoRoute(path: 'show', builder: (_, _) => stub('licence show')),
        ]),
  ]);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('licence card', () {
    testWidgets('saved licence: shows class/jurisdiction/expiry, opens show',
        (tester) async {
      await _pump(tester,
          licence: DriverLicence(
              licenceClass: 'G',
              jurisdiction: 'Ontario',
              expiryDate: DateTime(2028, 3, 14)));

      expect(find.text("Driver's licence"), findsOneWidget);
      expect(find.textContaining('G · Ontario · expires'), findsOneWidget);

      await tester.tap(find.text("Driver's licence"));
      await tester.pumpAndSettle();
      expect(find.text('licence show'), findsOneWidget);
    });

    testWidgets('no licence: invites adding one, opens the editor',
        (tester) async {
      await _pump(tester);

      expect(find.text("Add your driver's licence"), findsOneWidget);
      await tester.tap(find.text("Add your driver's licence"));
      await tester.pumpAndSettle();
      expect(find.text('licence editor'), findsOneWidget);
    });

    testWidgets('cloudApi: no licence card at all', (tester) async {
      await _pump(tester, mode: DataMode.cloudApi);

      expect(find.text("Driver's licence"), findsNothing);
      expect(find.text("Add your driver's licence"), findsNothing);
      // The vehicles still show — the mode rule is about the licence only.
      expect(find.text('2020 Honda Civic'), findsOneWidget);
    });
  });

  group('vehicles', () {
    testWidgets('lists active vehicles only', (tester) async {
      await _pump(tester,
          automobiles: () => _StubAutomobiles([
                _auto(1, 'Civic'),
                _auto(2, 'Accord', active: false),
              ]));

      expect(find.text('2020 Honda Civic'), findsOneWidget);
      expect(find.text('2020 Honda Accord'), findsNothing);
    });

    testWidgets('row opens the vehicle screen', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('2020 Honda Civic'));
      await tester.pumpAndSettle();
      expect(find.text('edit 1'), findsOneWidget);
    });

    testWidgets('fuel button selects the vehicle and opens its gas log',
        (tester) async {
      final container = await _pump(tester);
      await tester.tap(find.byTooltip('Gas log for 2020 Honda Civic'));
      await tester.pumpAndSettle();

      expect(container.read(selectedAutomobileIdProvider), 1);
      expect(find.text('gas log list'), findsOneWidget);
    });

    testWidgets('Add vehicle opens the create screen', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Add vehicle'));
      await tester.pumpAndSettle();
      expect(find.text('new vehicle'), findsOneWidget);
    });

    testWidgets('Manage opens the vehicle list', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      expect(find.text('manage list'), findsOneWidget);
    });

    testWidgets('empty state offers Add vehicle', (tester) async {
      await _pump(tester, automobiles: () => _StubAutomobiles(const []));

      expect(find.text('No vehicles yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Add vehicle'));
      await tester.pumpAndSettle();
      expect(find.text('new vehicle'), findsOneWidget);
    });

    testWidgets('load failure shows Retry', (tester) async {
      await _pump(tester, automobiles: _FailingAutomobiles.new);

      expect(find.text('Failed to load vehicles'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
```

Notes for the implementer: `Automobile.displayName` yields `"2020 Honda Civic"` for `year: 2020, maker: 'Honda', model: 'Civic'` — confirm by reading the getter at `automobile.dart:198` and adjust the expected strings if it differs. `find.byTooltip` matches an `IconButton`'s `tooltip`, which is how the fuel button carries its semantics label. `'Failed to load vehicles'` / `'Retry'` / `'Manage'` / `'Add vehicle'` are the existing keys `vehicleLoadFailed` / `commonRetry` / `vehicleManage` / `vehicleAdd`.

- [ ] **Step 4: Run and watch them fail**

Run: `flutter test --timeout 60s test/features/automobile_records/automobile_hub_screen_test.dart`
Expected: FAIL to compile — `automobile_hub_screen.dart` does not exist.

- [ ] **Step 5: Write the hub**

`lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../../core/data/data_mode.dart';
import '../../../../core/widgets/screen_scaffold.dart';
import '../../../driver_licence/domain/driver_licence.dart';
import '../../../driver_licence/states/driver_licence_state.dart';
import '../../../gas_log/domain/entities/automobile.dart';
import '../../../gas_log/presentation/widgets/automobile_list_tile.dart';
import '../../../gas_log/providers/selected_automobile_provider.dart';
import '../../../gas_log/states/automobiles_state.dart';
import '../../../settings/providers/gas_log_settings_provider.dart';

/// The automobile domain on one screen: the licence (one, it describes the
/// person) above the vehicles (many, each owns its own records). A thin
/// navigation screen — every destination already exists.
///
/// Replaces the old vehicle picker at /automobiles. The picker's one job
/// (choose a vehicle, open its gas log) is the fuel button on each row.
class AutomobileHubScreen extends ConsumerWidget {
  const AutomobileHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // The licence has no cloudApi repository — its provider throws there.
    // Same rule the dashboard tile used to apply; it lives here now.
    final showLicence = ref.watch(dataModeProvider) != DataMode.cloudApi;
    final autos = ref.watch(automobilesStateProvider);

    return CommonScreenScaffold(
      title: l.automobileHubTitle,
      withPadding: false,
      actions: [
        TextButton.icon(
          onPressed: () => context.push('/automobiles/manage'),
          icon: const Icon(Icons.settings),
          label: Text(l.vehicleManage),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(automobilesStateProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (showLicence) const _LicenceCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                l.automobileHubVehicles.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
              ),
            ),
            ...autos.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ],
              error: (e, _) => [_LoadFailed(error: e)],
              data: (all) {
                final active = all.where((a) => a.isActive).toList();
                if (active.isEmpty) return const [_NoVehicles()];
                return [
                  for (final a in active) _VehicleRow(automobile: a),
                  _AddVehicleRow(),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenceCard extends ConsumerWidget {
  const _LicenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(driverLicenceStateProvider);
    // Title only while loading: no "add yours" invitation that flips a
    // moment later into the saved card. An error reads as "none saved";
    // the licence screen shows the error itself.
    if (async.isLoading) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(l.automobileHubLicenceTitle),
        ),
      );
    }
    final licence = async.value;
    final saved = licence != null;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(saved ? l.automobileHubLicenceTitle : l.automobileHubLicenceAdd),
        subtitle: Text(saved
            ? _summary(licence, l)
            : l.automobileHubLicenceAddHint),
        trailing: Icon(saved ? Icons.chevron_right : Icons.add),
        onTap: () => context.push(saved ? '/licence/show' : '/licence'),
      ),
    );
  }

  /// "G · Ontario · expires Mar 14, 2028", each part only when present.
  static String _summary(DriverLicence licence, AppLocalizations l) {
    final parts = <String>[];
    final c = licence.licenceClass;
    if (c != null && c.isNotEmpty) parts.add(c);
    final j = licence.jurisdiction;
    if (j != null && j.isNotEmpty) parts.add(j);
    final d = licence.expiryDate;
    if (d != null) {
      parts.add(l.automobileHubLicenceExpires(DateFormat.yMMMd().format(d)));
    }
    return parts.join(' · ');
  }
}

class _VehicleRow extends ConsumerWidget {
  const _VehicleRow({required this.automobile});
  final Automobile automobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final distLabel = ref.watch(gasLogSettingsProvider).distanceUnit.label;
    return AutomobileListTile(
      automobile: automobile,
      distanceLabel: distLabel,
      onTap: () => context.push('/automobiles/manage/${automobile.id}/edit'),
      trailing: IconButton.filledTonal(
        tooltip: l.automobileHubGasLogFor(automobile.displayName),
        icon: const Icon(Icons.local_gas_station_outlined),
        onPressed: () {
          // The gas-log list reads the SELECTED vehicle, so select first.
          ref
              .read(selectedAutomobileIdProvider.notifier)
              .select(automobile.id);
          context.push('/gas-logs');
        },
      ),
    );
  }
}

class _AddVehicleRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: TextButton.icon(
        onPressed: () => context.push('/automobiles/manage/new'),
        icon: const Icon(Icons.add),
        label: Text(l.vehicleAdd),
      ),
    );
  }
}

class _NoVehicles extends StatelessWidget {
  const _NoVehicles();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        children: [
          Icon(Icons.directions_car_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(l.automobileHubNoVehicles,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l.automobileHubNoVehiclesHint, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/automobiles/manage/new'),
            child: Text(l.vehicleAdd),
          ),
        ],
      ),
    );
  }
}

class _LoadFailed extends ConsumerWidget {
  const _LoadFailed({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(l.vehicleLoadFailed, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(error.toString(),
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () =>
                ref.read(automobilesStateProvider.notifier).refresh(),
            child: Text(l.commonRetry),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test --timeout 60s test/features/automobile_records/automobile_hub_screen_test.dart`
Expected: all 10 PASS. If the "saved licence" test fails on the subtitle, print `find.textContaining('expires')` output and fix the expected string — the rule is `class · jurisdiction · expires <yMMMd>`.

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/features/automobile_records lib/features/gas_log/presentation/widgets test/features/automobile_records`
Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add lib/features/automobile_records/presentation/screens/automobile_hub_screen.dart lib/features/gas_log/presentation/widgets/automobile_list_tile.dart lib/l10n test/features/automobile_records/automobile_hub_screen_test.dart
git commit -m "feat(automobile): hub screen with the licence above the vehicles

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Mount the hub at /automobiles and delete the picker

**Files:**
- Modify: `lib/core/navigation/router_config.dart:23, 111-115`
- Delete: `lib/features/gas_log/presentation/screens/automobile_selector_screen.dart`

**Interfaces:**
- Consumes: `AutomobileHubScreen` (Task 3).
- Produces: `/automobiles` (route name `automobileSelector`, unchanged) builds `AutomobileHubScreen`. Child routes under `/automobiles/manage` untouched.

No new test: the router mounting is covered by the hub tests (screen behaviour) and by Task 5's dashboard test (tile → `/automobiles` arrival). The picker had no tests of its own — Step 1 confirms.

- [ ] **Step 1: Confirm the picker's only caller is the router**

Run: `grep -rn "AutomobileSelectorScreen\|automobile_selector_screen" lib test`
Expected: exactly two lines, both in `lib/core/navigation/router_config.dart`.

- [ ] **Step 2: Swap the route**

In `router_config.dart`, replace the import

```dart
import 'package:hmm_console/features/gas_log/presentation/screens/automobile_selector_screen.dart';
```

with

```dart
import 'package:hmm_console/features/automobile_records/presentation/screens/automobile_hub_screen.dart';
```

and in the `/automobiles` route change

```dart
        builder: (context, state) => const AutomobileSelectorScreen(),
```

to

```dart
        builder: (context, state) => const AutomobileHubScreen(),
```

- [ ] **Step 3: Delete the picker**

```bash
git rm lib/features/gas_log/presentation/screens/automobile_selector_screen.dart
```

- [ ] **Step 4: Analyze and run the navigation tests**

Run: `flutter analyze && flutter test --timeout 60s test/core/navigation test/features/automobile_records`
Expected: No issues; all PASS. The picker's l10n keys (`vehicleSelectTitle`, `vehicleNoneFound`, `vehicleNoneFoundHint`, `vehicleManageVehicles`) become unused; leave them — ARB pruning is out of scope.

- [ ] **Step 5: Commit**

```bash
git add lib/core/navigation/router_config.dart
git commit -m "feat(automobile): the hub replaces the vehicle picker at /automobiles

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: One Automobile tile on the dashboard

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart:54-96, 472-496`
- Test: `test/features/dashboard/dashboard_automobile_tile_test.dart`

**Interfaces:**
- Consumes: `AppFunction({icon, title, description, route})` (`lib/domain/entities/app_function.dart`), route `/automobiles`.
- Produces: the dashboard offers one `Automobile` tile (route id `automobile`) in every data mode; `Gas Log` and `Licence` tiles are gone.

- [ ] **Step 1: Write the failing test**

Modelled on `test/features/dashboard/dashboard_cheatsheet_tile_test.dart` — the same four overrides keep the dashboard off the database and the IdP.

```dart
// The Gas Log and Licence tiles fold into one Automobile tile that opens the
// hub. The tile must show in every mode: the cloudApi rule that used to hide
// the Licence tile now lives inside the hub, on its licence card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/data/data_mode.dart';
import 'package:hmm_console/core/data/sync/sync_controller.dart';
import 'package:hmm_console/features/auth/data/models/current_user.dart';
import 'package:hmm_console/features/auth/providers/current_user_provider.dart';
import 'package:hmm_console/features/cheatsheet/domain/entities/cheatsheet_card.dart';
import 'package:hmm_console/features/cheatsheet/states/cheatsheets_state.dart';
import 'package:hmm_console/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hmm_console/features/dashboard/providers/intro_card_provider.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _SignedIn extends CurrentUserNotifier {
  @override
  CurrentUserDataModel? build() => CurrentUserDataModel(
        uid: 'u1',
        email: 'tester@example.com',
        displayName: 'Tester',
        photoUrl: null,
      );
}

class _IntroSeen extends IntroCardSeenNotifier {
  @override
  bool build() => true;
}

class _IdleSync extends SyncController {
  _IdleSync() : super(syncAction: () async => throw UnimplementedError());
}

class _EmptyCheatsheets extends CheatsheetsState {
  @override
  Future<List<CheatsheetCard>> build() async => const [];
}

class _StubMode extends DataModeNotifier {
  _StubMode(this._m);
  final DataMode _m;
  @override
  DataMode build() => _m;
}

Future<void> _pump(WidgetTester tester, DataMode mode) async {
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
    GoRoute(
        path: '/automobiles',
        builder: (_, _) => const Scaffold(body: Text('automobile hub'))),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(_SignedIn.new),
      introCardSeenProvider.overrideWith(_IntroSeen.new),
      cheatsheetsStateProvider.overrideWith(_EmptyCheatsheets.new),
      syncControllerProvider.overrideWithValue(_IdleSync()),
      dataModeProvider.overrideWith(() => _StubMode(mode)),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Automobile tile opens the hub', (tester) async {
    await _pump(tester, DataMode.local);

    expect(find.text('Gas Log'), findsNothing, reason: 'folded into Automobile');
    expect(find.text('Licence'), findsNothing, reason: 'folded into Automobile');

    final tile = find.text('Automobile');
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('automobile hub'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing,
        reason: 'not the "coming soon" fallback');
  });

  testWidgets('the tile shows in cloudApi too', (tester) async {
    await _pump(tester, DataMode.cloudApi);
    expect(find.text('Automobile'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `flutter test --timeout 60s test/features/dashboard/dashboard_automobile_tile_test.dart`
Expected: FAIL — `find.text('Automobile')` finds nothing; `Gas Log` and `Licence` are found.

- [ ] **Step 3: Merge the tiles**

In `dashboard_screen.dart`, in `_allFunctions`, replace the `Gas Log` entry (`icon: "⛽"`, `route: "gas-log"`) with

```dart
    AppFunction(
      icon: "🚗",
      title: "Automobile",
      description: "Licence, vehicles, gas log",
      route: "automobile",
    ),
```

and delete the `Licence` entry (`icon: "🪪"`, `route: "driverLicence"`) entirely.

Replace `_visibleFunctions` and its doc comment (the one about the licence having no API repository) with a plain pass-through — every tile shows in every mode now:

```dart
  static List<AppFunction> _visibleFunctions(WidgetRef ref) => _allFunctions;
```

(Keep the signature so its call site does not change.)

In `_navigateToFunction`, replace

```dart
      case 'gas-log':
        context.push('/automobiles');
```

with

```dart
      case 'automobile':
        context.push('/automobiles');
```

and delete

```dart
      case 'driverLicence':
        context.pushNamed(RouterNames.driverLicence.name);
```

- [ ] **Step 4: Run the dashboard tests and analyze**

Run: `flutter analyze lib/features/dashboard && flutter test --timeout 60s test/features/dashboard`
Expected: No issues; all PASS. The `data_mode.dart` import stays (`dataModeProvider` is still used at lines 173 and 321) and so does `route_names.dart` (the cheatsheets case uses `RouterNames`). If the analyzer reports `ref` unused in `_visibleFunctions`, add `// ignore: unused_element_parameter` above it rather than changing the call site.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard/presentation/screens/dashboard_screen.dart test/features/dashboard/dashboard_automobile_tile_test.dart
git commit -m "feat(dashboard): one Automobile tile replaces Gas Log and Licence

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Whole-suite verification and docs

**Files:**
- Modify: `CLAUDE.md` (feature table rows for `automobile_records/` and `dashboard/`)
- Possibly modify: golden images under `test/core/widgets/`

- [ ] **Step 1: Full analyze and test**

Run: `flutter analyze && flutter test`
Expected: No issues; all tests pass (1574 before this work, plus 14 new).

- [ ] **Step 2: Golden check**

`test/core/widgets/goldens_test.dart` references `DashboardScreen`. If Step 1 showed a golden failure there, inspect the diff under `test/core/widgets/failures/`; the only intended change is the tile grid (one Automobile tile where Gas Log and Licence were). Regenerate with `flutter test --update-goldens test/core/widgets/goldens_test.dart` and include the updated golden files in the commit. If anything else differs, stop and report — do not update goldens over an unintended change.

- [ ] **Step 3: Note it in CLAUDE.md**

In the feature table in `CLAUDE.md`, append to the `automobile_records/` row's purpose cell:

```
**Automobile hub** (`AutomobileHubScreen` at `/automobiles`): licence card above the active vehicles; a row opens the vehicle screen, its fuel button jumps to that vehicle's gas log; replaced the old vehicle picker.
```

And in the `dashboard/` row change "Composites the above" to "Composites the above (one Automobile tile → the hub; the Gas Log and Licence tiles are gone)".

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md test/core/widgets
git commit -m "docs: record the automobile hub

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Report**

Tell the user the branch state and the test count, and that the iPhone deploy (`scripts/deploy-prod-ios-device.sh`, installs in place and keeps data) is ready to run on request — do not run it unasked.
