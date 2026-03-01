import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmm_console/features/settings/domain/gas_log_units.dart';
import 'package:hmm_console/features/settings/providers/gas_log_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GasLogSettingsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state is defaults (mile, gallon, CAD)', () {
      final settings = container.read(gasLogSettingsProvider);

      expect(settings.distanceUnit, DistanceUnit.mile);
      expect(settings.fuelUnit, FuelUnit.gallon);
      expect(settings.currency, CurrencyCode.cad);
    });

    test('update distanceUnit changes state', () async {
      await container
          .read(gasLogSettingsProvider.notifier)
          .update(distanceUnit: DistanceUnit.kilometer);

      final settings = container.read(gasLogSettingsProvider);
      expect(settings.distanceUnit, DistanceUnit.kilometer);
      expect(settings.fuelUnit, FuelUnit.gallon);
      expect(settings.currency, CurrencyCode.cad);
    });

    test('update fuelUnit changes state', () async {
      await container
          .read(gasLogSettingsProvider.notifier)
          .update(fuelUnit: FuelUnit.liter);

      final settings = container.read(gasLogSettingsProvider);
      expect(settings.distanceUnit, DistanceUnit.mile);
      expect(settings.fuelUnit, FuelUnit.liter);
      expect(settings.currency, CurrencyCode.cad);
    });

    test('update currency changes state', () async {
      await container
          .read(gasLogSettingsProvider.notifier)
          .update(currency: CurrencyCode.cny);

      final settings = container.read(gasLogSettingsProvider);
      expect(settings.distanceUnit, DistanceUnit.mile);
      expect(settings.fuelUnit, FuelUnit.gallon);
      expect(settings.currency, CurrencyCode.cny);
    });

    test('update multiple fields at once', () async {
      await container.read(gasLogSettingsProvider.notifier).update(
            distanceUnit: DistanceUnit.kilometer,
            fuelUnit: FuelUnit.liter,
            currency: CurrencyCode.usd,
          );

      final settings = container.read(gasLogSettingsProvider);
      expect(settings.distanceUnit, DistanceUnit.kilometer);
      expect(settings.fuelUnit, FuelUnit.liter);
      expect(settings.currency, CurrencyCode.usd);
    });

    test('update persists to SharedPreferences', () async {
      await container.read(gasLogSettingsProvider.notifier).update(
            distanceUnit: DistanceUnit.kilometer,
            fuelUnit: FuelUnit.liter,
            currency: CurrencyCode.cny,
          );

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('gas_log_settings');
      expect(stored, isNotNull);

      final decoded = jsonDecode(stored!) as Map<String, dynamic>;
      expect(decoded['distanceUnit'], 'Kilometer');
      expect(decoded['fuelUnit'], 'Liter');
      expect(decoded['currency'], 'CNY');
    });

    test('loads saved settings from SharedPreferences on build', () async {
      final savedJson = jsonEncode({
        'distanceUnit': 'Kilometer',
        'fuelUnit': 'Liter',
        'currency': 'USD',
      });
      SharedPreferences.setMockInitialValues({'gas_log_settings': savedJson});

      final freshContainer = ProviderContainer();
      addTearDown(freshContainer.dispose);

      // Initial synchronous build returns defaults
      final initial = freshContainer.read(gasLogSettingsProvider);
      expect(initial.distanceUnit, DistanceUnit.mile);

      // Wait for async load from SharedPreferences
      await Future<void>.delayed(Duration.zero);

      final loaded = freshContainer.read(gasLogSettingsProvider);
      expect(loaded.distanceUnit, DistanceUnit.kilometer);
      expect(loaded.fuelUnit, FuelUnit.liter);
      expect(loaded.currency, CurrencyCode.usd);
    });

    test('sequential updates accumulate correctly', () async {
      final notifier = container.read(gasLogSettingsProvider.notifier);

      await notifier.update(distanceUnit: DistanceUnit.kilometer);
      await notifier.update(currency: CurrencyCode.cny);

      final settings = container.read(gasLogSettingsProvider);
      expect(settings.distanceUnit, DistanceUnit.kilometer);
      expect(settings.fuelUnit, FuelUnit.gallon);
      expect(settings.currency, CurrencyCode.cny);
    });

    test('state persists after update without active listeners', () async {
      // Simulate: settings screen updates, then is popped
      await container.read(gasLogSettingsProvider.notifier).update(
            distanceUnit: DistanceUnit.kilometer,
          );

      // Read again (as another screen would) — should still be km
      final settings = container.read(gasLogSettingsProvider);
      expect(settings.distanceUnit, DistanceUnit.kilometer);
    });
  });
}
