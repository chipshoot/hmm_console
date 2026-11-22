import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/core/navigation/route_names.dart';
import 'package:hmm_console/features/activity/domain/offset_date_time.dart';
import 'package:hmm_console/features/glucose/contract/glucose_errors.dart';
import 'package:hmm_console/features/glucose/domain/glucose_range.dart';
import 'package:hmm_console/features/glucose/domain/glucose_reading.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/import/glucose_import_runner.dart';
import 'package:hmm_console/features/glucose/import/glucose_importer.dart';
import 'package:hmm_console/features/glucose/presentation/screens/glucose_list_screen.dart';
import 'package:hmm_console/features/glucose/states/glucose_list_state.dart';
import 'package:hmm_console/features/glucose/states/glucose_providers.dart';
import 'package:hmm_console/features/glucose/states/glucose_settings_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

import '../support/fake_glucose_repository.dart';

class _Range extends GlucoseRangeNotifier {
  _Range(this._r);
  final GlucoseRange? _r;
  @override
  GlucoseRange? build() => _r;
}

class _Unit extends GlucoseDisplayUnitNotifier {
  @override
  GlucoseUnit build() => GlucoseUnit.mmoll;
}

class _ImportOn extends GlucoseImportOnDeviceNotifier {
  _ImportOn(this._on);
  final bool _on;
  @override
  bool build() => _on;
}

class _FakeRunner extends GlucoseImportRunner {
  _FakeRunner(this.result)
    : super(
        importer: () => throw UnimplementedError(),
        prefs: GlucoseImportPrefs(),
        isIOS: () => true,
        isCloudApi: () => false,
        importOnDevice: () async => true,
        waitingForFirstSync: () => false,
      );

  final GlucoseImportResult? result;
  int calls = 0;

  @override
  Future<GlucoseImportResult?> importNow() async {
    calls++;
    return result;
  }
}

final _now = DateTime(2026, 11, 22, 10);

GlucoseReading _r(
  String id,
  OffsetDateTime at, {
  num value = 6.2,
  GlucoseUnit unit = GlucoseUnit.mmoll,
  GlucoseContext? context,
  GlucoseSource source = GlucoseSource.manual,
}) => GlucoseReading(
  id: id,
  takenAt: at,
  glucose: GlucoseValue(value, unit),
  context: context,
  source: source,
);

OffsetDateTime _local(int d, int h, [int m = 0]) =>
    OffsetDateTime.fromLocal(DateTime(2026, 11, d, h, m));

const _range = GlucoseRange(low: 4, high: 7, unit: GlucoseUnit.mmoll);

Future<void> _mount(
  WidgetTester tester, {
  FakeGlucoseRepository? repo,
  bool cloudApi = false,
  GlucoseRange? range = _range,
  TargetPlatform platform = TargetPlatform.android,
  bool importOn = true,
  _FakeRunner? runner,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const GlucoseListScreen()),
      GoRoute(
        path: '/glucose/range',
        name: RouterNames.glucoseRange.name,
        builder: (_, _) => const Scaffold(body: Text('range screen')),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      if (cloudApi)
        glucoseRepositoryProvider.overrideWith(
          (ref) => throw GlucoseCloudApiUnavailable(),
        )
      else
        glucoseRepositoryProvider.overrideWithValue(
          repo ?? FakeGlucoseRepository(),
        ),
      glucoseClockProvider.overrideWithValue(() => _now),
      glucoseRangeProvider.overrideWith(() => _Range(range)),
      glucoseDisplayUnitProvider.overrideWith(_Unit.new),
      glucoseImportOnDeviceProvider.overrideWith(() => _ImportOn(importOn)),
      glucoseImportRunnerProvider.overrideWithValue(
        runner ?? _FakeRunner(null),
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(platform: platform),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _headerAbove(WidgetTester tester, String rowText) {
  final rowY = tester.getTopLeft(find.text(rowText)).dy;
  String? best;
  var bestY = double.negativeInfinity;
  for (final e in find.byKey(const Key('glucose-day-header')).evaluate()) {
    final y = tester.getTopLeft(find.byWidget(e.widget)).dy;
    if (y < rowY && y > bestY) {
      bestY = y;
      best = (e.widget as Text).data;
    }
  }
  return best!;
}

void main() {
  testWidgets('rows show value, tag, band, time and a source marker', (
    t,
  ) async {
    await _mount(
      t,
      repo: FakeGlucoseRepository([
        _r('a', _local(22, 7, 41), context: GlucoseContext.fasting),
        _r(
          'b',
          _local(22, 13, 5),
          value: 176,
          unit: GlucoseUnit.mgdl,
          source: GlucoseSource.appleHealth,
        ),
      ]),
    );
    expect(find.text('6.2 mmol/L'), findsOneWidget);
    // 176 mg/dL = 9.8 mmol/L, shown in the display unit.
    expect(find.text('9.8 mmol/L'), findsOneWidget);
    expect(find.text('Fasting'), findsOneWidget);
    expect(find.text('In range'), findsOneWidget);
    expect(find.text('Above'), findsOneWidget);
    expect(find.text('7:41 AM'), findsOneWidget);
    expect(find.text('Target 4.0–7.0 mmol/L'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('groups under Today and Yesterday by the reading\'s own date', (
    t,
  ) async {
    // 23:30 on 21 Nov at -05:00 is 22 Nov in UTC but was recorded on 21 Nov.
    final travel = OffsetDateTime.tryParse('2026-11-21T23:30:00-05:00')!;
    await _mount(
      t,
      repo: FakeGlucoseRepository([
        _r('a', _local(22, 8), value: 5.1),
        _r('b', travel, value: 5.4),
      ]),
    );
    expect(_headerAbove(t, '5.1 mmol/L'), 'Today');
    expect(_headerAbove(t, '5.4 mmol/L'), 'Yesterday');
  });

  testWidgets('no range shows no band and a prompt that opens the range', (
    t,
  ) async {
    await _mount(
      t,
      range: null,
      repo: FakeGlucoseRepository([_r('a', _local(22, 8))]),
    );
    expect(find.text('In range'), findsNothing);
    await t.tap(find.text('Set your target range'));
    await t.pumpAndSettle();
    expect(find.text('range screen'), findsOneWidget);
  });

  testWidgets('empty state offers Log a reading, no import off iOS', (t) async {
    await _mount(t);
    expect(find.widgetWithText(FilledButton, 'Log a reading'), findsOneWidget);
    expect(find.text('Import from Apple Health'), findsNothing);
  });

  testWidgets('iOS empty state imports from Apple Health', (t) async {
    final runner = _FakeRunner(const GlucoseImportResult(added: 3, seen: 3));
    await _mount(t, platform: TargetPlatform.iOS, runner: runner);
    expect(find.text('Log a reading'), findsOneWidget);
    await t.tap(find.text('Import from Apple Health'));
    await t.pumpAndSettle();
    expect(runner.calls, 1);
    expect(find.text('Imported 3 readings'), findsOneWidget);
  });

  testWidgets('iOS with import off hides every import control', (t) async {
    await _mount(t, platform: TargetPlatform.iOS, importOn: false);
    expect(find.text('Import from Apple Health'), findsNothing);
    expect(find.byTooltip('Import now'), findsNothing);
  });

  testWidgets('Import now in the top bar runs the import', (t) async {
    final runner = _FakeRunner(const GlucoseImportResult(added: 1, seen: 1));
    await _mount(
      t,
      platform: TargetPlatform.iOS,
      runner: runner,
      repo: FakeGlucoseRepository([_r('a', _local(22, 8))]),
    );
    await t.tap(find.byTooltip('Import now'));
    await t.pumpAndSettle();
    expect(runner.calls, 1);
    expect(find.text('Imported 1 reading'), findsOneWidget);
  });

  testWidgets('a manual run that finds nothing explains where to look', (
    t,
  ) async {
    await _mount(
      t,
      platform: TargetPlatform.iOS,
      runner: _FakeRunner(const GlucoseImportResult()),
    );
    expect(find.textContaining('No readings found'), findsNothing);
    await t.tap(find.text('Import from Apple Health'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'No readings found. If you use a meter app, check Health → Sharing → Apps → Hmm.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a gate that blocks the import says it waits for sync', (
    t,
  ) async {
    final runner = _FakeRunner(null);
    await _mount(t, platform: TargetPlatform.iOS, runner: runner);
    await t.tap(find.text('Import from Apple Health'));
    await t.pumpAndSettle();
    expect(runner.calls, 1);
    expect(
      find.text('Waiting for the first sync. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.textContaining('No readings found'), findsNothing);
  });

  testWidgets('a busy sync shows its own short message', (t) async {
    await _mount(
      t,
      platform: TargetPlatform.iOS,
      runner: _FakeRunner(
        const GlucoseImportResult(error: GlucoseImportBusy()),
      ),
    );
    await t.tap(find.text('Import from Apple Health'));
    await t.pumpAndSettle();
    expect(
      find.text('Sync in progress. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text('Log a reading'), findsOneWidget);
  });

  testWidgets('any other import error shows a generic message', (t) async {
    await _mount(
      t,
      platform: TargetPlatform.iOS,
      runner: _FakeRunner(GlucoseImportResult(error: StateError('boom'))),
    );
    await t.tap(find.text('Import from Apple Health'));
    await t.pumpAndSettle();
    expect(find.text("Couldn't import readings."), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('swipe deletes with Undo, which restores the reading', (t) async {
    final repo = FakeGlucoseRepository([_r('a', _local(22, 8))]);
    await _mount(t, repo: repo);
    await t.drag(find.text('6.2 mmol/L'), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect(find.text('Reading deleted'), findsOneWidget);
    expect(find.text('6.2 mmol/L'), findsNothing);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(find.text('6.2 mmol/L'), findsOneWidget);
    expect(await repo.getReading('a'), isNotNull);
  });

  testWidgets('Cloud API mode shows the not-available message', (t) async {
    await _mount(t, cloudApi: true);
    expect(
      find.textContaining("isn't available in Cloud API mode"),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('the top bar has a help button', (t) async {
    await _mount(t);
    expect(find.byType(HelpButton), findsOneWidget);
  });
}
