import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/core/help/help_button.dart';
import 'package:hmm_console/features/glucose/domain/glucose_range.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/presentation/screens/glucose_range_screen.dart';
import 'package:hmm_console/features/glucose/states/glucose_settings_providers.dart';
import 'package:hmm_console/l10n/gen/app_localizations.dart';

class _Range extends GlucoseRangeNotifier {
  _Range(this._initial);
  final GlucoseRange? _initial;
  GlucoseRange? saved;
  bool cleared = false;

  @override
  GlucoseRange? build() => _initial;

  @override
  Future<void> set(GlucoseRange range) async {
    saved = range;
    state = range;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    state = null;
  }
}

class _Unit extends GlucoseDisplayUnitNotifier {
  @override
  GlucoseUnit build() => GlucoseUnit.mmoll;

  @override
  Future<void> set(GlucoseUnit unit) async => state = unit;
}

class _ImportOn extends GlucoseImportOnDeviceNotifier {
  bool? setTo;

  @override
  bool build() => true;

  @override
  Future<void> set(bool value) async {
    setTo = value;
    state = value;
  }
}

late _Range _range;
late _ImportOn _import;
late ProviderContainer _container;

Future<void> _mount(
  WidgetTester tester, {
  GlucoseRange? initial,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  _range = _Range(initial);
  _import = _ImportOn();
  _container = ProviderContainer(
    overrides: [
      glucoseRangeProvider.overrideWith(() => _range),
      glucoseDisplayUnitProvider.overrideWith(_Unit.new),
      glucoseImportOnDeviceProvider.overrideWith(() => _import),
    ],
  );
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GlucoseRangeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _saveEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.byKey(const Key('glucose-range-save')))
        .onPressed !=
    null;

void main() {
  testWidgets('saves low 4.0 and high 7.0 in mmol/L', (tester) async {
    await _mount(tester);
    expect(_saveEnabled(tester), isFalse);
    await tester.enterText(find.byKey(const Key('glucose-range-low')), '4.0');
    await tester.enterText(find.byKey(const Key('glucose-range-high')), '7.0');
    await tester.pump();
    await tester.tap(find.byKey(const Key('glucose-range-save')));
    await tester.pumpAndSettle();
    expect(
      _container.read(glucoseRangeProvider),
      const GlucoseRange(low: 4, high: 7, unit: GlucoseUnit.mmoll),
    );
  });

  testWidgets('low at or above high shows an error and does not save', (
    tester,
  ) async {
    await _mount(tester);
    await tester.enterText(find.byKey(const Key('glucose-range-low')), '7.0');
    await tester.enterText(find.byKey(const Key('glucose-range-high')), '7.0');
    await tester.pump();
    expect(find.text('Low must be below high.'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
    await tester.tap(
      find.byKey(const Key('glucose-range-save')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(_range.saved, isNull);
  });

  testWidgets('values outside the typed bounds are rejected', (tester) async {
    await _mount(tester);
    await tester.enterText(find.byKey(const Key('glucose-range-low')), '0.5');
    await tester.enterText(find.byKey(const Key('glucose-range-high')), '7.0');
    await tester.pump();
    expect(
      find.textContaining('Enter a value from 1.1 to 33.3'),
      findsOneWidget,
    );
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('shows the stored range and can clear it', (tester) async {
    await _mount(
      tester,
      initial: const GlucoseRange(low: 4, high: 7, unit: GlucoseUnit.mmoll),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('glucose-range-low')))
          .controller!
          .text,
      '4.0',
    );
    await tester.tap(find.byKey(const Key('glucose-range-clear')));
    await tester.pumpAndSettle();
    expect(_range.cleared, isTrue);
  });

  testWidgets('changing the display unit updates the provider', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('mg/dL'));
    await tester.pumpAndSettle();
    expect(_container.read(glucoseDisplayUnitProvider), GlucoseUnit.mgdl);
  });

  testWidgets('import switch is absent on Android', (tester) async {
    await _mount(tester);
    expect(find.byKey(const Key('glucose-import-on-device')), findsNothing);
  });

  testWidgets('import switch shows on iOS and toggling sets it', (
    tester,
  ) async {
    await _mount(tester, platform: TargetPlatform.iOS);
    expect(
      find.text('Import from Apple Health on this device'),
      findsOneWidget,
    );
    final sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('glucose-import-on-device')),
    );
    expect(sw.value, isTrue);
    await tester.tap(find.byKey(const Key("glucose-import-on-device")));
    await tester.pumpAndSettle();
    expect(_import.setTo, isFalse);
  });

  testWidgets('has a help button', (tester) async {
    await _mount(tester);
    expect(find.byType(HelpButton), findsOneWidget);
  });
}
