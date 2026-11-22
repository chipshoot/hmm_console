import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/calendar/states/remind_on_device_provider.dart';
import 'package:hmm_console/features/glucose/domain/glucose_range.dart';
import 'package:hmm_console/features/glucose/domain/glucose_units.dart';
import 'package:hmm_console/features/glucose/states/glucose_settings_providers.dart';
import 'package:hmm_console/features/settings/data/syncable_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer mount([List<Override> overrides = const []]) {
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('display unit default', () {
    Future<GlucoseUnit> forCountry(String country) async {
      SharedPreferences.setMockInitialValues({});
      final c = mount([
        glucoseDisplayUnitProvider.overrideWith(
          () => GlucoseDisplayUnitNotifier(regionCountry: country),
        ),
      ]);
      c.listen(glucoseDisplayUnitProvider, (_, _) {});
      await settle();
      return c.read(glucoseDisplayUnitProvider);
    }

    test('US is mg/dL', () async {
      expect(await forCountry('US'), GlucoseUnit.mgdl);
    });
    test('CA is mmol/L', () async {
      expect(await forCountry('CA'), GlucoseUnit.mmoll);
    });
  });

  test('display unit set persists and hydrates', () async {
    SharedPreferences.setMockInitialValues({});
    final c = mount([
      glucoseDisplayUnitProvider.overrideWith(
        () => GlucoseDisplayUnitNotifier(regionCountry: 'CA'),
      ),
    ]);
    c.listen(glucoseDisplayUnitProvider, (_, _) {});
    await c.read(glucoseDisplayUnitProvider.notifier).set(GlucoseUnit.mgdl);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(SyncableSettingsRepository.glucoseDisplayUnitKey),
      'mg/dL',
    );
    SharedPreferences.setMockInitialValues({
      SyncableSettingsRepository.glucoseDisplayUnitKey: 'mg/dL',
    });
    final c2 = mount([
      glucoseDisplayUnitProvider.overrideWith(
        () => GlucoseDisplayUnitNotifier(regionCountry: 'CA'),
      ),
    ]);
    c2.listen(glucoseDisplayUnitProvider, (_, _) {});
    await settle();
    expect(c2.read(glucoseDisplayUnitProvider), GlucoseUnit.mgdl);
  });

  group('range', () {
    test('null with nothing stored', () async {
      SharedPreferences.setMockInitialValues({});
      final c = mount();
      c.listen(glucoseRangeProvider, (_, _) {});
      await settle();
      expect(c.read(glucoseRangeProvider), isNull);
    });

    test('set writes all three keys, clear removes them', () async {
      SharedPreferences.setMockInitialValues({});
      final c = mount();
      c.listen(glucoseRangeProvider, (_, _) {});
      const r = GlucoseRange(low: 4, high: 7, unit: GlucoseUnit.mmoll);
      await c.read(glucoseRangeProvider.notifier).set(r);
      expect(c.read(glucoseRangeProvider), r);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('glucose.rangeLow'), 4.0);
      expect(prefs.getDouble('glucose.rangeHigh'), 7.0);
      expect(prefs.getString('glucose.rangeUnit'), 'mmol/L');
      await c.read(glucoseRangeProvider.notifier).clear();
      expect(c.read(glucoseRangeProvider), isNull);
      expect(prefs.containsKey('glucose.rangeLow'), isFalse);
      expect(prefs.containsKey('glucose.rangeHigh'), isFalse);
      // The empty unit is the clear marker that syncs.
      expect(prefs.getString('glucose.rangeUnit'), '');
    });

    test('a set before hydration is not overwritten by stale prefs', () async {
      SharedPreferences.setMockInitialValues({
        'glucose.rangeLow': 70.0,
        'glucose.rangeHigh': 140.0,
        'glucose.rangeUnit': 'mg/dL',
      });
      final c = mount();
      c.listen(glucoseRangeProvider, (_, _) {});
      const r = GlucoseRange(low: 4, high: 7, unit: GlucoseUnit.mmoll);
      await c.read(glucoseRangeProvider.notifier).set(r);
      await settle();
      expect(c.read(glucoseRangeProvider), r);
    });

    test('an empty stored unit reads as no range', () async {
      SharedPreferences.setMockInitialValues({'glucose.rangeUnit': ''});
      final c = mount();
      c.listen(glucoseRangeProvider, (_, _) {});
      await settle();
      expect(c.read(glucoseRangeProvider), isNull);
    });

    test('hydrates from prefs when all three are present', () async {
      SharedPreferences.setMockInitialValues({
        'glucose.rangeLow': 70.0,
        'glucose.rangeHigh': 140.0,
        'glucose.rangeUnit': 'mg/dL',
      });
      final c = mount();
      c.listen(glucoseRangeProvider, (_, _) {});
      await settle();
      expect(
        c.read(glucoseRangeProvider),
        const GlucoseRange(low: 70, high: 140, unit: GlucoseUnit.mgdl),
      );
    });

    test('null when a part is missing or the unit does not parse', () async {
      for (final prefs in <Map<String, Object>>[
        {'glucose.rangeLow': 4.0, 'glucose.rangeUnit': 'mmol/L'},
        {
          'glucose.rangeLow': 4.0,
          'glucose.rangeHigh': 7.0,
          'glucose.rangeUnit': 'bogus',
        },
      ]) {
        SharedPreferences.setMockInitialValues(prefs);
        final c = mount();
        c.listen(glucoseRangeProvider, (_, _) {});
        await settle();
        expect(c.read(glucoseRangeProvider), isNull);
      }
    });
  });

  group('import on this device', () {
    Future<bool> at(double side) async {
      SharedPreferences.setMockInitialValues({});
      final c = mount([
        deviceShortestSideProvider.overrideWith(
          () => DeviceShortestSideNotifier(side),
        ),
      ]);
      c.listen(glucoseImportOnDeviceProvider, (_, _) {});
      await c.read(glucoseImportOnDeviceProvider.notifier).loaded;
      return c.read(glucoseImportOnDeviceProvider);
    }

    test('defaults on at 390, off at 820', () async {
      expect(await at(390), isTrue);
      expect(await at(820), isFalse);
    });

    test('set persists under glucose.importOnDevice', () async {
      SharedPreferences.setMockInitialValues({});
      final c = mount([
        deviceShortestSideProvider.overrideWith(
          () => DeviceShortestSideNotifier(820),
        ),
      ]);
      c.listen(glucoseImportOnDeviceProvider, (_, _) {});
      await c.read(glucoseImportOnDeviceProvider.notifier).set(true);
      expect(c.read(glucoseImportOnDeviceProvider), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'glucose.importOnDevice',
        ),
        isTrue,
      );
    });
  });

  test('import prefs round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final p = GlucoseImportPrefs();
    expect(await p.importedOnce(), isFalse);
    expect(await p.lastImportEnd(), isNull);
    await p.markImportedOnce();
    final t = DateTime.utc(2026, 11, 22, 8, 30);
    await p.setLastImportEnd(t);
    expect(await p.importedOnce(), isTrue);
    expect(await p.lastImportEnd(), t);
  });
}
